#!/usr/bin/env bash
# yazi opener: open selected videos in IINA, then tile the windows
# side by side centered on screen (see iina-tile.js).
[[ $# -eq 0 ]] && exit 0
open -a IINA "$@"
exec osascript -l JavaScript "$HOME/.config/yazi/iina-tile.js" "$@" >/dev/null 2>&1
