#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Nicolas Baudoin
# Locally modified: short clips are extracted in ONE ffmpeg pass into a
# continuous 12fps frame strip (motion looks like real playback instead of
# a slideshow); long videos fall back to sparse seek sampling. Cached ticks
# skip ffprobe entirely so the per-frame hot path stays cheap.
set -euo pipefail
IFS=$'\n'

FILE_PATH=""
OFFSET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)   shift; FILE_PATH="${1:-}";;
    --offset) shift; OFFSET="${1:-0}";;
    --topw|--toph|--width|--height) shift ;;  # ignore if passed
  esac
  shift || true
done

[[ -z "${FILE_PATH}" || ! -f "${FILE_PATH}" ]] && { echo "No such file: ${FILE_PATH}"; exit 0; }

have() { command -v "$1" >/dev/null 2>&1; }
emit_image() { echo "__preview__image__path__ $1"; }

hash_str() {
  printf "%s" "$1" | (md5sum 2>/dev/null || shasum 2>/dev/null || sha1sum 2>/dev/null) | awk '{print $1}'
}

# --- SETTINGS ---
PREVIEW_FPS=12        # sampling rate for short clips (half-rate proxy of 24fps)
MAXFRAMES=360         # hard cap on extracted frames per video
LONG_VIDEO_SECS=60    # beyond this, fall back to sparse seek sampling
SPARSE_N=10           # frame count for the sparse fallback
OUT_W=3200            # thumbnails fit within this box, aspect preserved
OUT_H=3200

cache_key() {
  local st
  if st="$(stat -Lc '%n|%Y|%s' -- "$FILE_PATH" 2>/dev/null)"; then
    :
  else
    st="$(stat -f '%N|%m|%z' -- "$FILE_PATH")"
  fi
  # Include settings so cache updates when you tweak them
  local settings="fps=${PREVIEW_FPS}|maxf=${MAXFRAMES}|long=${LONG_VIDEO_SECS}|n=${SPARSE_N}|w=${OUT_W}|h=${OUT_H}|fit|strip=1|meta=zh2"
  hash_str "${st}|${settings}"
}

TMPDIR="${TMPDIR:-/tmp}"
CACHEDIR="${TMPDIR%/}/yazi-video-timeline"
mkdir -p "$CACHEDIR"

KEY="$(cache_key)"
COUNT_FILE="${CACHEDIR}/${KEY}.count"
INFO="${CACHEDIR}/${KEY}.info"
LOCK="${CACHEDIR}/${KEY}.lock"

# Compact 3-line summary instead of raw mediainfo: the preview pane is
# ~45 columns wide, mediainfo's 41-char label padding truncates everything.
emit_meta() {
  if [[ ! -s "$INFO" ]]; then
    if have ffprobe; then
      local v a f
      v="$(ffprobe -v error -select_streams v:0 \
            -show_entries stream=codec_name,width,height,avg_frame_rate \
            -of csv=p=0 -- "$FILE_PATH" 2>/dev/null | head -1)"
      a="$(ffprobe -v error -select_streams a:0 \
            -show_entries stream=codec_name,channels,sample_rate \
            -of csv=p=0 -- "$FILE_PATH" 2>/dev/null | head -1)"
      f="$(ffprobe -v error \
            -show_entries format=duration,size,bit_rate \
            -of csv=p=0 -- "$FILE_PATH" 2>/dev/null | head -1)"
      awk -v v="$v" -v a="$a" -v f="$f" '
      function gcd(a, b,   t) { while (b > 0) { t = a % b; a = b; b = t } return a }
      function ratio(w, h,   g, rw, rh, i, n, C, cw, ch) {
        if (w <= 0 || h <= 0) return ""
        g = gcd(w, h); rw = w / g; rh = h / g
        if (rw <= 21 && rh <= 21) return rw ":" rh
        # odd resolution: match against common ratios with 1.5% tolerance
        n = split("16:9 9:16 4:3 3:4 3:2 2:3 5:4 4:5 1:1 21:9 9:21", C, " ")
        for (i = 1; i <= n; i++) {
          split(C[i], P, ":"); cw = P[1]; ch = P[2]
          if ((w / h) / (cw / ch) > 0.985 && (w / h) / (cw / ch) < 1.015)
            return "≈" C[i]
        }
        return sprintf("%.2f:1", w / h)
      }
      BEGIN{
        split(v, V, ","); split(a, A, ","); split(f, F, ",")
        if (V[2] != "") printf "分辨率  %sx%s (%s)\n", V[2], V[3], ratio(V[2], V[3])
        if (F[1] != "") printf "时长    %.1f 秒\n", F[1]
        if (V[4] ~ /^[0-9]+\/[0-9]+$/) {
          split(V[4], R, "/")
          if (R[2] > 0) printf "帧率    %.4g fps\n", R[1] / R[2]
        }
        if (V[1] != "") printf "视频    %s  %.0f kb/s\n", V[1], F[3]/1000
        if (F[2] != "") printf "大小    %.1f MiB\n", F[2]/1048576
        if (A[1] != "") printf "音频    %s  %s声道  %s Hz\n", A[1], A[2], A[3]
        else            printf "音频    无\n"
      }' >"$INFO" 2>/dev/null || true
    else
      echo "Install ffmpeg (ffprobe) for metadata." >"$INFO"
    fi
  fi
  cat "$INFO" 2>/dev/null || true
}

# ---------- fast path: frame strip already extracted ----------
if [[ -s "$COUNT_FILE" ]]; then
  NFRAMES="$(cat "$COUNT_FILE")"
  if [[ "$NFRAMES" =~ ^[0-9]+$ ]] && (( NFRAMES > 0 )); then
    IMG="${CACHEDIR}/${KEY}.$(( OFFSET % NFRAMES )).jpg"
    [[ -s "$IMG" ]] && emit_image "$IMG"
    emit_meta
    exit 0
  fi
fi

# ---------- slow path: first hover on this video ----------
DUR="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 -- "$FILE_PATH" 2>/dev/null | head -1)"
[[ "$DUR" =~ ^[0-9.]+$ ]] || DUR=""

# Seek-based single-frame extraction (used for frame 0 and the sparse fallback).
# Temp + mv keeps concurrent runs from leaving half-written jpgs behind.
gen_frame() {
  local ts="$1" out="$2" tmp="$2.$$.jpg"
  LC_NUMERIC=C ffmpeg -hide_banner -loglevel error -y \
    -ss "$ts" -i "$FILE_PATH" \
    -vf "scale=${OUT_W}:${OUT_H}:force_original_aspect_ratio=decrease" \
    -frames:v 1 -q:v 5 \
    "$tmp" >/dev/null 2>&1 && mv -f "$tmp" "$out" || rm -f "$tmp"
}

# Show something immediately while the strip extracts in the background
FRAME0="${CACHEDIR}/${KEY}.0.jpg"
[[ -s "$FRAME0" ]] || gen_frame 0 "$FRAME0"
[[ -s "$FRAME0" ]] && emit_image "$FRAME0"

# Background extraction, guarded by a lock (stale locks >2 min are ignored
# in case a previous run was killed mid-way).
if [[ ! -e "$LOCK" ]] || [[ -n "$(find "$LOCK" -mmin +2 2>/dev/null)" ]]; then
  touch "$LOCK"
  (
    if [[ -n "$DUR" ]] && awk -v d="$DUR" -v l="$LONG_VIDEO_SECS" 'BEGIN{exit !(d>0 && d<=l)}'; then
      # Short clip: ONE decode pass, frames 1/fps apart -> continuous motion.
      # fps shrinks if the clip would exceed MAXFRAMES.
      fps="$(awk -v d="$DUR" -v f="$PREVIEW_FPS" -v m="$MAXFRAMES" \
        'BEGIN{ r=f; if (d*f>m) r=m/d; printf "%.4f", r }')"
      STRIP="$(mktemp -d "${CACHEDIR}/${KEY}.strip.XXXXXX")"
      if LC_NUMERIC=C ffmpeg -hide_banner -loglevel error -y \
           -i "$FILE_PATH" \
           -vf "fps=${fps},scale=${OUT_W}:${OUT_H}:force_original_aspect_ratio=decrease" \
           -q:v 5 "${STRIP}/f-%05d.jpg" >/dev/null 2>&1; then
        n=0
        for f in "${STRIP}"/f-*.jpg; do
          [[ -e "$f" ]] || break
          mv -f "$f" "${CACHEDIR}/${KEY}.${n}.jpg"
          n=$(( n + 1 ))
        done
        if (( n > 0 )); then
          printf "%d" "$n" >"${COUNT_FILE}.tmp" && mv -f "${COUNT_FILE}.tmp" "$COUNT_FILE"
        fi
      fi
      rm -rf "$STRIP"
    else
      # Long / unknown duration: sparse seek sampling spread across the video
      for o in $(seq 0 $(( SPARSE_N - 1 ))); do
        img="${CACHEDIR}/${KEY}.${o}.jpg"
        if [[ ! -s "$img" ]]; then
          if [[ -n "$DUR" ]]; then
            ts="$(awk -v d="$DUR" -v o="$o" -v n="$SPARSE_N" 'BEGIN{printf "%.2f", d*(o+0.5)/n}')"
          else
            ts=$(( 8 + o * 40 ))
          fi
          gen_frame "$ts" "$img"
        fi
      done
      printf "%d" "$SPARSE_N" >"${COUNT_FILE}.tmp" && mv -f "${COUNT_FILE}.tmp" "$COUNT_FILE"
    fi
    rm -f "$LOCK"
  ) >/dev/null 2>&1 &
fi

emit_meta
