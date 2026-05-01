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
