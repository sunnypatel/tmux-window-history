# tmux-window-history

A lightweight tmux plugin that keeps a per-session window history stack. Step backwards through recently visited windows with a single repeatable key, or open a visual menu to jump anywhere in your history at once.

No external dependencies — built with tmux built-ins only.

## Features

- Per-session window history stack (configurable depth, default 10)
- Back key always takes you to wherever you just came from — press again to return
- Visual menu (`display-menu`) showing your full history with 1–9 shortcuts
- Dead windows removed automatically (hook + fallback recovery)
- TPM compatible

## Requirements

- tmux 3.0+
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
| `prefix + B` | Go back to the previous window (press again to return) |
| `prefix + W` | Open visual history menu |

## Configuration

```tmux
# Maximum entries to keep in the history stack (default: 10)
set -g @window-history-size '10'

# Key for stepping back through history (default: B)
set -g @window-history-back-key 'B'

# Key for opening the visual menu (default: W)
set -g @window-history-menu-key 'W'
```

## How It Works

Each tmux session maintains two things: a **history stack** (for the visual menu) and a **previous-window pointer** (for the back key).

Every time you switch windows, the previous window is recorded. Pressing `B` swaps you to that window and updates the pointer — so pressing `B` again takes you back to where you just were. It behaves like a browser back button: go back, then go back again to undo the back.

The visual menu (`prefix + W`) shows your full deduplicated history. Jumping via the menu also updates the back pointer so `B` always returns you to where you were before jumping.

## License

MIT
