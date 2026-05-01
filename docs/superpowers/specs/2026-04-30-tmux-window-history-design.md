# tmux-window-history — Design Spec

**Date:** 2026-04-30
**Repo:** sunnypatel/tmux-window-history

---

## Overview

A lightweight tmux plugin that tracks a per-session window history stack. Users can step backwards through recently visited windows with a repeatable key, loop through the full stack, and open a visual menu to jump to any entry. No external dependencies — built-in tmux features only.

---

## File Structure

```
tmux-window-history/
├── tmux-window-history.tmux   # TPM entry point — reads config, sets hooks and bindings
├── scripts/
│   └── window_history.sh      # All core logic: push, back, scrub, menu
└── README.md
```

The `.tmux` entry point is intentionally thin. It reads user config options, registers hooks, and sets key bindings. All logic lives in `window_history.sh` so it can be reasoned about and tested independently.

---

## Data Model

Each tmux session gets two session-scoped options:

| Option | Type | Description |
|---|---|---|
| `@window-history-stack` | string | Space-separated window IDs, most recent first (e.g. `@3 @1 @5 @2`) |
| `@window-history-index` | integer | Current position in the stack (0 = top/most recent) |

Window IDs (the `@N` format) are used instead of window indexes. IDs are stable — they do not shift when windows are closed or reordered.

A third option is used as an internal flag:

| Option | Type | Description |
|---|---|---|
| `@window-history-navigating` | 0 or 1 | Set to 1 during history navigation to suppress the push hook |

---

## Hooks

### `after-select-window` — push to stack

Fires on every window switch. Behavior:

1. If `@window-history-navigating` is `1`, skip and clear the flag.
2. Otherwise, prepend the newly selected window ID to `@window-history-stack`.
3. Reset `@window-history-index` to `0`.
4. Trim the stack to `@window-history-size` entries.

### `after-kill-window` — scrub closed windows

Fires when a window is killed. Behavior:

1. Remove the killed window's ID from `@window-history-stack`.
2. If `@window-history-index` pointed at or past the removed entry, decrement it by 1 (clamped to 0).

---

## Navigation Behavior

### BSpace — step back through history

Bound with `-r` (repeatable): press prefix once, then mash BSpace to step back through the stack.

1. Read `@window-history-index` from the current session.
2. Increment by 1.
3. If the new index exceeds the stack length, loop back to 0.
4. Look up the window ID at the new index position.
5. Set `@window-history-navigating 1`.
6. Switch to that window (`select-window -t <id>`).
7. Write the new index back to `@window-history-index`.

**Example:**
```
Stack: [@3, @1, @5, @2]   index: 0  (currently on @3)
BSpace →                  index: 1  (jump to @1)
BSpace →                  index: 2  (jump to @5)
BSpace →                  index: 3  (jump to @2)
BSpace →                  index: 0  (loop — back to @3)
```

Any non-history window switch (normal navigation) resets the index to 0 and pushes to the stack.

### W — visual stack menu

Opens a `display-menu` built dynamically from the current stack. Each entry shows the window index and name. Selecting an entry:

1. Sets `@window-history-navigating 1`.
2. Switches directly to that window.
3. Does not modify the stack position — just jumps.

Menu title: `Window History (<n> entries)`.

---

## Configuration Options

| Option | Default | Description |
|---|---|---|
| `@window-history-size` | `10` | Maximum stack depth |
| `@window-history-back-key` | `BSpace` | Repeatable key for stepping back |
| `@window-history-menu-key` | `W` | Key for opening the visual stack menu |

Example user configuration:
```tmux
set -g @plugin 'sunnypatel/tmux-window-history'
set -g @window-history-size '20'
set -g @window-history-back-key 'BSpace'
set -g @window-history-menu-key 'W'
```

---

## Compatibility

- Requires tmux 2.1+ (for `display-menu` and session-scoped options)
- No external dependencies
- Compatible with TPM (tmux Plugin Manager)
- Compatible with tmux-resurrect (stack lives in session options, which resurrect preserves)
