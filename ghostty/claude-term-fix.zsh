# --- Claude Code rendering fix for Ghostty 1.3.x ---
# Ghostty 1.3.1 has a known cumulative rendering-corruption bug when an
# app uses DEC 2026 (Synchronized Output) together with DECSTBM scrolling
# regions — exactly the pattern Claude Code's Ink TUI uses for its status
# bar. The corruption (ghosted/duplicated/overlapping text) builds up
# over time and only clears on restart.
#
# Per anthropics/claude-code#55613, Claude Code emits DEC 2026 sequences
# only when TERM is xterm-ghostty or xterm-kitty; switching to
# xterm-256color makes it skip the sync-output path entirely, bypassing
# the Ghostty bug. As a bonus this also avoids the multi-line paste
# mangling reported in anthropics/claude-code#54700.
#
# Scope: only rewrites TERM for the `claude` process itself. Other tools
# (lazygit, bat, yazi, etc.) keep the richer xterm-ghostty terminfo.
# Refs: ghostty-org/ghostty#11001, #12685.
# Escape hatch: run `command claude` to bypass this wrapper.
claude() {
  if [[ "$TERM" == xterm-ghostty ]]; then
    TERM=xterm-256color command claude "$@"
  else
    command claude "$@"
  fi
}
alias clauded="claude --dangerously-skip-permissions"
