#!/usr/bin/env bash
# tmux-window-history — per-session window history stack
# https://github.com/sunnypatel/tmux-window-history

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$CURRENT_DIR/scripts/window_history.sh"

# Read user config (fall back to defaults)
back_key=$(tmux show-option -gqv "@window-history-back-key")
back_key="${back_key:-BSpace}"

menu_key=$(tmux show-option -gqv "@window-history-menu-key")
menu_key="${menu_key:-W}"

# Hooks
tmux set-hook -g after-select-window \
  "run-shell '$SCRIPT push #{session_id} #{window_id}'"

tmux set-hook -g after-kill-window \
  "run-shell '$SCRIPT scrub #{session_id} #{window_id}'"

# Key bindings
tmux bind -r "$back_key" run-shell "$SCRIPT back #{session_id}"
tmux bind    "$menu_key" run-shell "$SCRIPT menu #{session_id}"
