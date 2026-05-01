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

# ── Entry point ────────────────────────────────────────────────────────────────
_main() {
  case "${1:-}" in
    push)  cmd_push  "$2" "$3" ;;
    back)  cmd_back  "$2"      ;;
    scrub) cmd_scrub "$2" "$3" ;;
    menu)  cmd_menu  "$2"      ;;
    jump)  cmd_jump  "$2" "$3" ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then _main "$@"; fi
