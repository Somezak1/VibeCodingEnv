#!/usr/bin/env osascript -l JavaScript
// Tile IINA windows for the given files side by side, centered as a group
// on the main screen. 1 file -> centered; 2 files -> seam at screen center;
// N files -> one row, shrunk proportionally if the row would overflow.
// Usage: osascript -l JavaScript iina-tile.js /path/a.mp4 /path/b.mp4 ...
ObjC.import('AppKit')

function run(argv) {
  if (argv.length === 0) return
  const names = argv.map(p => p.split('/').pop())

  const se = Application('System Events')
  se.includeStandardAdditions = true

  // IINA window titles look like "file.mp4  —  /path/to/dir"; match on the
  // part before the separator. Falls back to all titled windows on no match.
  const baseOf = t => t.split('  —  ')[0]

  // Wait until IINA has shown a window for every requested file
  const deadline = Date.now() + 10000
  let wins = []
  while (Date.now() < deadline) {
    try {
      const all = se.processes.byName('IINA').windows()
      wins = all
        .map(w => ({ w: w, base: baseOf(w.title()) }))
        .filter(x => names.includes(x.base))
    } catch (e) {
      wins = []
    }
    if (wins.length >= names.length) break
    delay(0.3)
  }
  if (wins.length === 0) {
    try {
      wins = se.processes.byName('IINA').windows()
        .map(w => ({ w: w, base: baseOf(w.title()) }))
        .filter(x => x.base && x.base !== 'IINA')
    } catch (e) { return }
  }
  if (wins.length === 0) return

  // Keep the user's selection order
  wins.sort((a, b) => names.indexOf(a.base) - names.indexOf(b.base))

  // Let IINA finish its own open-time resize (videoSize20) before measuring,
  // then tile twice: the second pass is idempotent and corrects any window
  // IINA re-sized underneath the first pass.
  delay(0.8)
  tile(wins)
  delay(0.6)
  tile(wins)
}

function tile(wins) {
  const screen = $.NSScreen.mainScreen
  const vf = screen.visibleFrame            // Cocoa coords: origin bottom-left
  const fullH = screen.frame.size.height
  const sx = vf.origin.x
  const sw = vf.size.width
  const sh = vf.size.height
  const syTop = fullH - (vf.origin.y + vf.size.height)  // menu bar inset

  const n = wins.length
  const slotW = sw / n

  // Shrink each window proportionally so every one fits its slot and height
  const sizes = wins.map(x => {
    const cur = x.w.size()
    const s = Math.min(1, slotW / cur[0], sh / cur[1])
    return [Math.floor(cur[0] * s), Math.floor(cur[1] * s)]
  })

  const totalW = sizes.reduce((acc, s) => acc + s[0], 0)
  let x = sx + (sw - totalW) / 2
  wins.forEach((win, i) => {
    const tw = sizes[i][0], th = sizes[i][1]
    const y = syTop + (sh - th) / 2
    win.w.size = [tw, th]
    win.w.position = [Math.round(x), Math.round(y)]
    x += tw
  })
}
