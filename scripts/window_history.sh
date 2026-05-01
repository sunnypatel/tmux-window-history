#!/usr/bin/env bash

# ── Pure string functions (no tmux dependency) ─────────────────────────────────

# Push window_id to front of stack, dedup, trim to max_size.
# Args: stack window_id max_size
# Stdout: new stack string
stack_push() {
  local stack="$1" window_id="$2" max_size="$3"
  local new="$window_id" count=1
  for id in $stack; do
    [ "$id" = "$window_id" ] && continue
    [ "$count" -ge "$max_size" ] && break
    new="$new $id"
    count=$((count + 1))
  done
  echo "$new"
}

# Remove window_id from stack.
# Args: stack window_id
# Stdout: new stack string
stack_scrub() {
  local stack="$1" window_id="$2" out=""
  for id in $stack; do
    [ "$id" = "$window_id" ] && continue
    out="${out:+$out }$id"
  done
  echo "$out"
}

# Get window_id at index position.
# Args: stack index
# Stdout: window_id or empty string
stack_get() {
  local stack="$1" target="$2" i=0
  for id in $stack; do
    [ "$i" -eq "$target" ] && echo "$id" && return
    i=$((i + 1))
  done
}

# Count entries in stack.
# Args: stack
# Stdout: integer count
stack_count() {
  local stack="$1" count=0
  for id in $stack; do count=$((count + 1)); done
  echo "$count"
}

# Calculate next back-navigation index with looping.
# Args: current_index stack_size
# Stdout: next index
next_index() {
  local idx="$1" size="$2"
  [ "$size" -eq 0 ] && echo 0 && return
  local next=$((idx + 1))
  [ "$next" -ge "$size" ] && next=0
  echo "$next"
}

# ── tmux I/O helpers ───────────────────────────────────────────────────────────

# Session ID is always fetched from tmux context to avoid shell $N variable conflicts.
_session_id() { tmux display-message -p '#{session_id}'; }

_opt_get()  { tmux show-option -t  "$1" -qv "$2" 2>/dev/null || echo ""; }
_opt_set()  { tmux set-option  -t  "$1"     "$2" "$3"; }
_gopt_get() { tmux show-option -gqv "$1" 2>/dev/null || echo ""; }

get_stack()      { _opt_get "$1" "@window-history-stack"; }
set_stack()      { _opt_set "$1" "@window-history-stack" "$2"; }
get_index()      { local v; v=$(_opt_get "$1" "@window-history-index"); echo "${v:-0}"; }
set_index()      { _opt_set "$1" "@window-history-index" "$2"; }
get_navigating() { local v; v=$(_opt_get "$1" "@window-history-navigating"); echo "${v:-0}"; }
set_navigating() { _opt_set "$1" "@window-history-navigating" "$2"; }
get_max_size()   { local v; v=$(_gopt_get "@window-history-size"); echo "${v:-10}"; }

# ── Commands ───────────────────────────────────────────────────────────────────

# Called by after-select-window hook.
# Args: window_id
cmd_push() {
  local session_id; session_id=$(_session_id)
  local window_id="$1"
  # If navigating via history, suppress push and clear the flag
  if [ "$(get_navigating "$session_id")" = "1" ]; then
    set_navigating "$session_id" "0"
    return
  fi
  local max_size; max_size=$(get_max_size)
  local stack;    stack=$(get_stack "$session_id")
  set_stack "$session_id" "$(stack_push "$stack" "$window_id" "$max_size")"
  set_index "$session_id" "0"
}

# Called by after-kill-window hook.
# Args: window_id
cmd_scrub() {
  local session_id; session_id=$(_session_id)
  local window_id="$1"
  local stack; stack=$(get_stack "$session_id")
  local idx;   idx=$(get_index "$session_id")
  # Determine position of the killed window to adjust index
  local pos=0 found=0
  for id in $stack; do
    [ "$id" = "$window_id" ] && found=1 && break
    pos=$((pos + 1))
  done
  set_stack "$session_id" "$(stack_scrub "$stack" "$window_id")"
  # If the removed entry was at or before the current index, decrement index
  if [ "$found" = "1" ] && [ "$pos" -le "$idx" ] && [ "$idx" -gt 0 ]; then
    set_index "$session_id" "$((idx - 1))"
  fi
}

# Called by prefix + BSpace key binding.
cmd_back() {
  local session_id; session_id=$(_session_id)
  local stack; stack=$(get_stack "$session_id")
  local size;  size=$(stack_count "$stack")
  [ "$size" -le 1 ] && return
  local idx; idx=$(get_index "$session_id")
  local attempts=0
  while [ "$attempts" -lt "$size" ]; do
    local next; next=$(next_index "$idx" "$size")
    local target; target=$(stack_get "$stack" "$next")
    [ -z "$target" ] && return
    set_navigating "$session_id" "1"
    if tmux select-window -t "$target" 2>/dev/null; then
      set_index "$session_id" "$next"
      return
    fi
    # Window gone — scrub from stack and try next
    set_navigating "$session_id" "0"
    stack=$(stack_scrub "$stack" "$target")
    set_stack "$session_id" "$stack"
    size=$(stack_count "$stack")
    idx="$next"
    [ "$size" -le 1 ] && return
    [ "$idx" -ge "$size" ] && idx=0
    attempts=$((attempts + 1))
  done
}

# Called by prefix + W key binding. Shows display-menu of history stack.
cmd_menu() {
  local session_id; session_id=$(_session_id)
  local stack; stack=$(get_stack "$session_id")
  [ -z "$stack" ] && tmux display-message "No window history yet" && return
  local count; count=$(stack_count "$stack")
  local script; script="${BASH_SOURCE[0]}"
  local args=(-T "Window History ($count entries)")
  local i=0
  for window_id in $stack; do
    local name
    name=$(tmux display-message -t "$window_id" -p "#I: #W" 2>/dev/null) || { i=$((i + 1)); continue; }
    local prefix=""
    if [ "$i" -lt 9 ]; then
      prefix="$((i + 1))  "
    elif [ "$i" -eq 9 ]; then
      prefix="0  "
    fi
    args+=("$prefix$name" "" "run-shell '\"$script\" jump \"$window_id\"'")
    i=$((i + 1))
  done
  tmux display-menu "${args[@]}"
}

# Called from display-menu item selection.
# Args: window_id
cmd_jump() {
  local session_id; session_id=$(_session_id)
  local window_id="$1"
  set_navigating "$session_id" "1"
  tmux select-window -t "$window_id" 2>/dev/null || set_navigating "$session_id" "0"
}

# ── Entry point ────────────────────────────────────────────────────────────────
_main() {
  case "${1:-}" in
    push)  cmd_push  "$2" ;;
    back)  cmd_back       ;;
    scrub) cmd_scrub "$2" ;;
    menu)  cmd_menu       ;;
    jump)  cmd_jump  "$2" ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then _main "$@"; fi
