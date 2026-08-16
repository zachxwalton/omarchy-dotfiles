# herdr + omp

One keybind opens a new tab in the persistent [herdr](https://herdr.dev)
session with [omp](https://oh-my-pi.dev) already running in it — no waiting
for the agent to be detected.

## Files

| File | Install to |
|------|------------|
| `herdr-omp` | `~/.local/bin/herdr-omp` (make executable) |
| `bindings.lua` | `~/.config/hypr/bindings.lua` (or append the `hl.unbind`/`o.bind` lines) |
| `config.toml` | `~/.config/herdr/config.toml` (optional — herdr works without it) |

## How it works

`SUPER + CTRL + RETURN` (previously bound to plain "Herdr") now runs
`herdr-omp`, which:

1. Launches the herdr terminal only when no herdr window is open yet — herdr
   disallows nested TUIs by default, so an open window is reused instead.
2. Creates a new focused tab labeled `omp` in the session, opening in the
   focused pane's working directory (herdr's own `new_cwd = "follow"`).
3. Dispatches `omp` into the tab immediately via `herdr pane run` — the shell
   queues it until its prompt is ready, so the keybind returns in a few
   hundred ms. herdr auto-detects the running omp as an agent.
4. Verifies in the background that omp actually started, and notifies via
   desktop notification if the dispatch was lost.

Diagnostics: `~/.local/state/herdr-omp.log`.

## Requirements

- herdr with the persistent server running (`herdr status` shows
  `server: status: running`)
- `omp` on `PATH`
- Omarchy (for `omarchy-cmd-terminal-cwd`, `uwsm-app`, `xdg-terminal-exec`)

## Keybind

To bind a different key, change the `o.bind` line in `bindings.lua`:

```lua
hl.unbind("SUPER + CTRL + RETURN")
o.bind("SUPER + CTRL + RETURN", "Herdr + omp", "/home/USER/.local/bin/herdr-omp")
```

After editing, reload with `hyprctl reload` and validate with
`hyprctl configerrors`.
