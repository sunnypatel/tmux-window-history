#!/usr/bin/env bash

# ── Pure string functions (no tmux dependency) ─────────────────────────────────

# Push window_id to front of stack, trim to max_size. Allows duplicates.
# Args: stack window_id max_size
# Stdout: new stack string
stack_push() {
  local stack="$1" window_id="$2" max_size="$3"
  local new="$window_id" count=1
  for id in $stack; do
    [ "$count" -ge "$max_size" ] && break
    new="$new $id"
    count=$((count + 1))
  done
  echo "$new"
}

# Return stack with duplicates removed (first occurrence wins).
# Args: stack
# Stdout: deduplicated stack string
stack_unique() {
  local stack="$1" out="" seen=""
  for id in $stack; do
    case " $seen " in *" $id "*) continue ;; esac
    seen="$seen $id"
    out="${out:+$out }$id"
  done
  echo "$out"
}

# Remove all occurrences of window_id from stack.
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

# Count entries in stack.
# Args: stack
# Stdout: integer count
stack_count() {
  local stack="$1" count=0
  for id in $stack; do count=$((count + 1)); done
  echo "$count"
}

# ── tmux I/O helpers ───────────────────────────────────────────────────────────

# Session ID is always fetched from tmux context to avoid shell $N variable conflicts.
_session_id() { tmux display-message -p '#{session_id}'; }

_opt_get()  { tmux show-option -t  "$1" -qv "$2" 2>/dev/null || echo ""; }
_opt_set()  { tmux set-option  -t  "$1"     "$2" "$3"; }
_gopt_get() { tmux show-option -gqv "$1" 2>/dev/null || echo ""; }

get_stack()      { _opt_get "$1" "@window-history-stack"; }
set_stack()      { _opt_set "$1" "@window-history-stack" "$2"; }
get_prev()       { _opt_get "$1" "@window-history-prev"; }
set_prev()       { _opt_set "$1" "@window-history-prev" "$2"; }
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
  # Front of stack is the window we're leaving — record it as prev
  local leaving="${stack%% *}"
  [ -n "$leaving" ] && set_prev "$session_id" "$leaving"
  set_stack "$session_id" "$(stack_push "$stack" "$window_id" "$max_size")"
}

# Called by after-kill-window hook.
# Args: window_id
cmd_scrub() {
  local session_id; session_id=$(_session_id)
  local window_id="$1"
  local stack; stack=$(get_stack "$session_id")
  set_stack "$session_id" "$(stack_scrub "$stack" "$window_id")"
  # If the killed window was the back target, clear it
  local prev; prev=$(get_prev "$session_id")
  [ "$prev" = "$window_id" ] && set_prev "$session_id" ""
}

# Called by prefix + B key binding.
# Swaps current window with @prev — each press updates the pointer so back
# always means "wherever I just came from."
cmd_back() {
  local session_id; session_id=$(_session_id)
  local prev; prev=$(get_prev "$session_id")
  [ -z "$prev" ] && return
  local current; current=$(tmux display-message -p '#{window_id}')
  # Swap: make current the new prev before navigating away
  set_prev "$session_id" "$current"
  set_navigating "$session_id" "1"
  tmux select-window -t "$prev" 2>/dev/null || {
    set_navigating "$session_id" "0"
    set_prev "$session_id" ""
  }
}

# Called by prefix + W key binding. Shows display-menu of history stack.
cmd_menu() {
  local session_id; session_id=$(_session_id)
  local stack; stack=$(get_stack "$session_id")
  [ -z "$stack" ] && tmux display-message "No window history yet" && return
  local display_stack; display_stack=$(stack_unique "$stack")
  local count; count=$(stack_count "$display_stack")
  local script; script="${BASH_SOURCE[0]}"
  local args=(-T "Window History ($count entries)")
  local i=0
  for window_id in $display_stack; do
    local name
    name=$(tmux display-message -t "$window_id" -p "#I: #W" 2>/dev/null) || { i=$((i + 1)); continue; }
    local prefix="" key=""
    if [ "$i" -lt 9 ]; then
      prefix="($((i + 1)))  "
      key=$((i + 1))
    elif [ "$i" -eq 9 ]; then
      prefix="(0)  "
      key="0"
    fi
    args+=("$prefix$name" "$key" "run-shell '\"$script\" jump \"$window_id\"'")
    i=$((i + 1))
  done
  tmux display-menu "${args[@]}"
}

# Called from display-menu item selection.
# Args: window_id
cmd_jump() {
  local session_id; session_id=$(_session_id)
  local window_id="$1"
  local current; current=$(tmux display-message -p '#{window_id}')
  local old_prev; old_prev=$(get_prev "$session_id")
  set_prev "$session_id" "$current"
  set_navigating "$session_id" "1"
  tmux select-window -t "$window_id" 2>/dev/null || {
    set_navigating "$session_id" "0"
    set_prev "$session_id" "$old_prev"
  }
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
