# tmux-window-history Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a lean, dependency-free tmux plugin that maintains a per-session window history stack with configurable depth, repeatable back-navigation, and a built-in visual menu.

**Architecture:** A thin TPM entry point (`tmux-window-history.tmux`) reads user config and wires up two hooks (`after-select-window`, `after-kill-window`) and two key bindings to a single shell script (`scripts/window_history.sh`). The script is split into pure string-manipulation functions (fully testable with bats) and thin tmux I/O wrappers. Per-session state lives in tmux session options.

**Tech Stack:** bash, tmux built-ins only (no external dependencies at runtime). bats-core (git submodule) for testing.

---

## File Map

| File | Role |
|---|---|
| `tmux-window-history.tmux` | TPM entry point — reads config, registers hooks and key bindings |
| `scripts/window_history.sh` | All logic: pure stack functions + tmux wrappers + command dispatch |
| `tests/window_history.bats` | bats unit tests for all pure functions |
| `tests/bats-core/` | bats-core git submodule (dev dependency only) |
| `README.md` | Installation, configuration, usage |

---

## Task 1: Scaffold project structure

**Files:**
- Create: `tmux-window-history.tmux`
- Create: `scripts/window_history.sh`
- Create: `tests/window_history.bats`
- Submodule: `tests/bats-core/`

- [ ] **Step 1: Add bats-core as a git submodule**

```bash
cd ~/projects/tmux-window-history
git submodule add https://github.com/bats-core/bats-core.git tests/bats-core
```

Expected: `tests/bats-core/` appears with bats source, `.gitmodules` created.

- [ ] **Step 2: Create the entry point stub**

Create `tmux-window-history.tmux`:

```bash
#!/usr/bin/env bash
# tmux-window-history — per-session window history stack
# https://github.com/sunnypatel/tmux-window-history

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$CURRENT_DIR/scripts/window_history.sh"
```

- [ ] **Step 3: Create the script stub**

Create `scripts/window_history.sh`:

```bash
#!/usr/bin/env bash
# Guard: only run case dispatch when executed directly (not sourced for tests)
_main() {
  case "${1:-}" in
    push)  cmd_push  "$2" "$3" ;;
    back)  cmd_back  "$2"      ;;
    scrub) cmd_scrub "$2" "$3" ;;
    menu)  cmd_menu  "$2"      ;;
    jump)  cmd_jump  "$2" "$3" ;;
  esac
}

[ "${BASH_SOURCE[0]}" = "$0" ] && _main "$@"
```

- [ ] **Step 4: Create the bats test stub**

Create `tests/window_history.bats`:

```bash
#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../scripts/window_history.sh"
}

@test "placeholder — always passes" {
  true
}
```

- [ ] **Step 5: Run the placeholder test to confirm bats works**

```bash
cd ~/projects/tmux-window-history
./tests/bats-core/bin/bats tests/window_history.bats
```

Expected output:
```
 ✓ placeholder — always passes
1 test, 0 failures
```

- [ ] **Step 6: Make scripts executable**

```bash
chmod +x tmux-window-history.tmux scripts/window_history.sh
```

- [ ] **Step 7: Commit**

```bash
cd ~/projects/tmux-window-history
git add .
git commit -m "chore: scaffold project structure with bats test harness"
```

---

## Task 2: Pure stack functions (TDD)

**Files:**
- Modify: `scripts/window_history.sh`
- Modify: `tests/window_history.bats`

These functions manipulate space-separated strings of tmux window IDs (e.g. `"@3 @1 @5"`). They have no tmux dependency and are fully unit-testable.

- [ ] **Step 1: Write all pure function tests**

Replace the contents of `tests/window_history.bats` with:

```bash
#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../scripts/window_history.sh"
}

# ── stack_push ─────────────────────────────────────────────────────────────────

@test "stack_push: empty stack gets single entry" {
  result=$(stack_push "" "@1" 10)
  [ "$result" = "@1" ]
}

@test "stack_push: prepends to existing stack" {
  result=$(stack_push "@1 @2 @3" "@4" 10)
  [ "$result" = "@4 @1 @2 @3" ]
}

@test "stack_push: deduplicates — moves existing ID to front" {
  result=$(stack_push "@1 @2 @3" "@2" 10)
  [ "$result" = "@2 @1 @3" ]
}

@test "stack_push: trims to max_size" {
  result=$(stack_push "@1 @2 @3" "@4" 3)
  [ "$result" = "@4 @1 @2" ]
}

@test "stack_push: max_size=1 keeps only newest entry" {
  result=$(stack_push "@1 @2" "@3" 1)
  [ "$result" = "@3" ]
}

@test "stack_push: dedup then trim — moved entry counts toward max" {
  result=$(stack_push "@1 @2 @3 @4" "@3" 3)
  [ "$result" = "@3 @1 @2" ]
}

# ── stack_scrub ────────────────────────────────────────────────────────────────

@test "stack_scrub: removes target from middle" {
  result=$(stack_scrub "@1 @2 @3" "@2")
  [ "$result" = "@1 @3" ]
}

@test "stack_scrub: removes target from front" {
  result=$(stack_scrub "@1 @2 @3" "@1")
  [ "$result" = "@2 @3" ]
}

@test "stack_scrub: removes target from end" {
  result=$(stack_scrub "@1 @2 @3" "@3")
  [ "$result" = "@1 @2" ]
}

@test "stack_scrub: no-op when ID not present" {
  result=$(stack_scrub "@1 @2 @3" "@99")
  [ "$result" = "@1 @2 @3" ]
}

@test "stack_scrub: empty stack returns empty string" {
  result=$(stack_scrub "" "@1")
  [ "$result" = "" ]
}

@test "stack_scrub: single-entry stack returns empty string" {
  result=$(stack_scrub "@1" "@1")
  [ "$result" = "" ]
}

# ── stack_get ──────────────────────────────────────────────────────────────────

@test "stack_get: retrieves element at index 0" {
  result=$(stack_get "@1 @2 @3" 0)
  [ "$result" = "@1" ]
}

@test "stack_get: retrieves element at index 1" {
  result=$(stack_get "@1 @2 @3" 1)
  [ "$result" = "@2" ]
}

@test "stack_get: retrieves last element" {
  result=$(stack_get "@1 @2 @3" 2)
  [ "$result" = "@3" ]
}

@test "stack_get: out-of-bounds index returns empty string" {
  result=$(stack_get "@1 @2" 5)
  [ "$result" = "" ]
}

# ── stack_count ────────────────────────────────────────────────────────────────

@test "stack_count: counts three entries" {
  result=$(stack_count "@1 @2 @3")
  [ "$result" = "3" ]
}

@test "stack_count: empty stack returns 0" {
  result=$(stack_count "")
  [ "$result" = "0" ]
}

@test "stack_count: single entry returns 1" {
  result=$(stack_count "@1")
  [ "$result" = "1" ]
}

# ── next_index ─────────────────────────────────────────────────────────────────

@test "next_index: increments from 0 to 1" {
  result=$(next_index 0 5)
  [ "$result" = "1" ]
}

@test "next_index: loops back to 0 at last entry" {
  result=$(next_index 4 5)
  [ "$result" = "0" ]
}

@test "next_index: size 1 always returns 0" {
  result=$(next_index 0 1)
  [ "$result" = "0" ]
}

@test "next_index: size 0 always returns 0" {
  result=$(next_index 0 0)
  [ "$result" = "0" ]
}
```

- [ ] **Step 2: Run tests — verify all fail**

```bash
cd ~/projects/tmux-window-history
./tests/bats-core/bin/bats tests/window_history.bats
```

Expected: multiple failures with "stack_push: command not found" or similar.

- [ ] **Step 3: Implement pure functions in window_history.sh**

Add these functions above the `_main` function in `scripts/window_history.sh`:

```bash
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

[ "${BASH_SOURCE[0]}" = "$0" ] && _main "$@"
```

- [ ] **Step 4: Run tests — verify all pass**

```bash
cd ~/projects/tmux-window-history
./tests/bats-core/bin/bats tests/window_history.bats
```

Expected:
```
 ✓ stack_push: empty stack gets single entry
 ✓ stack_push: prepends to existing stack
 ... (all 26 tests pass)
26 tests, 0 failures
```

- [ ] **Step 5: Commit**

```bash
cd ~/projects/tmux-window-history
git add scripts/window_history.sh tests/window_history.bats
git commit -m "feat: implement pure stack functions with full bats test coverage"
```

---

## Task 3: tmux I/O helpers and push/scrub commands

**Files:**
- Modify: `scripts/window_history.sh`

These functions wrap tmux option reads/writes and implement the two hook-driven commands.

- [ ] **Step 1: Add tmux I/O helpers to window_history.sh**

Add these functions after the pure functions, before `_main`:

```bash
# ── tmux I/O helpers ───────────────────────────────────────────────────────────

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
```

- [ ] **Step 2: Implement cmd_push and cmd_scrub**

Add these functions after the I/O helpers, before `_main`:

```bash
# ── Commands ───────────────────────────────────────────────────────────────────

# Called by after-select-window hook.
# Args: session_id window_id
cmd_push() {
  local session_id="$1" window_id="$2"
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
# Args: session_id window_id
cmd_scrub() {
  local session_id="$1" window_id="$2"
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
```

- [ ] **Step 3: Verify tests still pass**

```bash
cd ~/projects/tmux-window-history
./tests/bats-core/bin/bats tests/window_history.bats
```

Expected: 26 tests, 0 failures.

- [ ] **Step 4: Commit**

```bash
cd ~/projects/tmux-window-history
git add scripts/window_history.sh
git commit -m "feat: add tmux I/O helpers and push/scrub commands"
```

---

## Task 4: back command

**Files:**
- Modify: `scripts/window_history.sh`

- [ ] **Step 1: Implement cmd_back**

Add this function after `cmd_scrub`, before `_main`:

```bash
# Called by prefix + BSpace key binding.
# Args: session_id
cmd_back() {
  local session_id="$1"
  local stack; stack=$(get_stack "$session_id")
  local size;  size=$(stack_count "$stack")
  # Need at least 2 entries to navigate anywhere different
  [ "$size" -le 1 ] && return
  local idx; idx=$(get_index "$session_id")
  local next; next=$(next_index "$idx" "$size")
  local target; target=$(stack_get "$stack" "$next")
  [ -z "$target" ] && return
  # Set flag before select-window so the after-select-window hook suppresses push
  set_navigating "$session_id" "1"
  if ! tmux select-window -t "$target" 2>/dev/null; then
    # Window no longer exists — scrub it and retry
    set_navigating "$session_id" "0"
    set_stack "$session_id" "$(stack_scrub "$stack" "$target")"
    cmd_back "$session_id"
  else
    set_index "$session_id" "$next"
  fi
}
```

- [ ] **Step 2: Verify tests still pass**

```bash
cd ~/projects/tmux-window-history
./tests/bats-core/bin/bats tests/window_history.bats
```

Expected: 26 tests, 0 failures.

- [ ] **Step 3: Manual smoke test in a live tmux session**

Open a tmux session with at least 3 windows. Source the plugin temporarily:

```bash
bash ~/projects/tmux-window-history/tmux-window-history.tmux
```

Switch between windows a few times, then test:
```
prefix + BSpace   # should jump to previous window
prefix + BSpace   # should jump to one before that
prefix + BSpace   # should keep stepping back / looping
```

- [ ] **Step 4: Commit**

```bash
cd ~/projects/tmux-window-history
git add scripts/window_history.sh
git commit -m "feat: implement back command with loop and dead-window recovery"
```

---

## Task 5: menu and jump commands

**Files:**
- Modify: `scripts/window_history.sh`

- [ ] **Step 1: Implement cmd_menu and cmd_jump**

Add these functions after `cmd_back`, before `_main`:

```bash
# Called by prefix + W key binding. Shows display-menu of history stack.
# Args: session_id
cmd_menu() {
  local session_id="$1"
  local stack; stack=$(get_stack "$session_id")
  [ -z "$stack" ] && tmux display-message "No window history yet" && return
  local script; script="${BASH_SOURCE[0]}"
  local args=(-T "Window History")
  local i=0
  for window_id in $stack; do
    local name
    name=$(tmux display-message -t "$window_id" -p "#I: #W" 2>/dev/null) || { i=$((i + 1)); continue; }
    local key=""
    [ "$i" -lt 9 ] && key=$((i + 1))
    args+=("$name" "$key" "run-shell '\"$script\" jump \"$session_id\" \"$window_id\"'")
    i=$((i + 1))
  done
  tmux display-menu "${args[@]}"
}

# Called from display-menu item selection.
# Args: session_id window_id
cmd_jump() {
  local session_id="$1" window_id="$2"
  set_navigating "$session_id" "1"
  tmux select-window -t "$window_id" 2>/dev/null || set_navigating "$session_id" "0"
}
```

- [ ] **Step 2: Verify tests still pass**

```bash
cd ~/projects/tmux-window-history
./tests/bats-core/bin/bats tests/window_history.bats
```

Expected: 26 tests, 0 failures.

- [ ] **Step 3: Manual smoke test of the menu**

In a live tmux session with history built up:
```
prefix + W   # should open a numbered menu of recent windows
Press 1      # should jump to that window without corrupting the stack
```

- [ ] **Step 4: Commit**

```bash
cd ~/projects/tmux-window-history
git add scripts/window_history.sh
git commit -m "feat: implement menu and jump commands using display-menu"
```

---

## Task 6: TPM entry point

**Files:**
- Modify: `tmux-window-history.tmux`

- [ ] **Step 1: Implement the full entry point**

Replace the contents of `tmux-window-history.tmux` with:

```bash
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
```

- [ ] **Step 2: Full integration test in a live tmux session**

Source the plugin and exercise all features:

```bash
# In tmux, source the entry point
tmux source-file ~/projects/tmux-window-history/tmux-window-history.tmux
```

Then verify:
1. Switch through 5+ windows — `prefix + BSpace` steps back through them
2. Mash `BSpace` past the oldest entry — confirms looping back to start
3. Kill a window that's in the stack — `prefix + BSpace` skips it cleanly
4. `prefix + W` — opens menu listing history with 1-9 shortcuts
5. Press a number in the menu — jumps to that window

- [ ] **Step 3: Test custom config options**

```bash
# In tmux.conf or tmux command prompt:
tmux set -g @window-history-size 5
tmux set -g @window-history-back-key H
tmux set -g @window-history-menu-key G
tmux source-file ~/projects/tmux-window-history/tmux-window-history.tmux
```

Verify that `prefix + H` navigates back and the stack truncates at 5 entries.

- [ ] **Step 4: Commit**

```bash
cd ~/projects/tmux-window-history
git add tmux-window-history.tmux
git commit -m "feat: implement TPM entry point with hook and key binding wiring"
```

---

## Task 7: README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README.md**

Create `README.md`:

```markdown
# tmux-window-history

A lightweight tmux plugin that keeps a per-session window history stack. Step backwards through recently visited windows with a single repeatable key, or open a visual menu to jump anywhere in your history at once.

No external dependencies — built with tmux built-ins only.

## Features

- Per-session window history stack (configurable depth, default 10)
- Repeatable back key: press once, then mash to step through history
- History loops — keep pressing to cycle back to where you started
- Visual menu (`display-menu`) showing your history with 1–9 shortcuts
- Dead windows removed automatically (hook + fallback recovery)
- TPM compatible

## Requirements

- tmux 2.1+
- [TPM](https://github.com/tmux-plugins/tpm)

## Installation

Add to your `tmux.conf`:

```tmux
set -g @plugin 'sunnypatel/tmux-window-history'
```

Then press `prefix + I` to install.

## Key Bindings

| Binding | Action |
|---|---|
| `prefix + BSpace` | Step back one entry in history (repeatable) |
| `prefix + W` | Open visual history menu |

## Configuration

```tmux
# Maximum entries to keep in the history stack (default: 10)
set -g @window-history-size '10'

# Key for stepping back through history (default: BSpace)
set -g @window-history-back-key 'BSpace'

# Key for opening the visual menu (default: W)
set -g @window-history-menu-key 'W'
```

## How It Works

Each tmux session tracks its own history stack in session options. Switching windows pushes the new window to the top. Pressing `BSpace` moves a pointer through the stack without modifying it — your normal navigation history is preserved until you switch windows non-historically, which resets the pointer and pushes a new entry.

## License

MIT
```

- [ ] **Step 2: Commit and push**

```bash
cd ~/projects/tmux-window-history
git add README.md
git commit -m "docs: add README with installation, config, and usage"
git push
```
