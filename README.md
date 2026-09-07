# omarchy-dotfiles

Personal configuration for [Omarchy](https://omarchy.org/) — an Arch Linux /
Hyprland desktop.

## Contents

- [`home/`](home/) — mirrors `$HOME`. Copy or symlink into place to restore.
  - `.config/hypr/` — Hyprland: bindings (incl. `SUPER + CTRL + RETURN` →
    herdr + omp, and `SUPER + SHIFT + S` → Slack via launch-or-focus script),
    monitors, input, look'n'feel, autostart, hyprsunset (identity profile),
    xdg-desktop-portal share picker.
  - `.config/omarchy/` — transparent shell/bar layout with custom
    `zwalton.clock` (EST) and `zwalton.clock-bst` plugins, idle & lock times,
    custom `vantablack-purple` theme, menu config, branding, post-update hooks
    (voxtype, fingerprint, agent setup invitations).
  - `.local/bin/` — `omarchy-slack`: launch-or-focus helper for the Slack
    binding (class-matched, unlike omarchy's title-based launcher).
  - `.config/{alacritty,ghostty,kitty,foot}/` — terminals: JetBrainsMono Nerd
    Font, 14px padding, CSI-u Shift+Enter keybindings for tmux.
  - `.config/nvim/` — LazyVim setup with custom plugins (theme hot-reload,
    all-themes) and config overrides.
  - `.config/git/config`, `starship.toml`, `tmux/tmux.conf`, `imv/config`,
    `mise/config.toml`, `fcitx5/profile`, `mimeapps.list`,
    `xdg-terminals.list`, `user-dirs.dirs`, autostart overrides,
    `hyprland-preview-share-picker/config.yaml`.
  - `.XCompose` — compose-key identification (name, email).
- [`install.sh`](install.sh) — idempotent one-line installer (see Install).
- [`herdr/`](herdr/) — herdr + omp keybind setup: opens a new herdr tab running
  omp instantly from a Hyprland keybind (`SUPER + CTRL + RETURN`).
- [`apps.txt`](apps.txt) — installed & removed apps vs. base Omarchy.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/zachxwalton/omarchy-dotfiles/main/install.sh | bash
# or, from a clone:
./install.sh
```

Safe on any machine state — bare Omarchy, partially configured, or already in
sync:

- Copies only files whose content differs from the repo (pure `cmp`, no rsync
  dependency); never deletes local extras.
- Idempotent: a run on a synced machine writes nothing and exits 0.
- Replaced files are backed up to
  `~/.cache/omarchy-dotfiles/backups/<timestamp>/`.
- On another user/machine, `/home/zwalton` paths in `hypr/bindings.lua` and
  `git/config` are rewritten to `$HOME` automatically. The `zwalton.clock`
  plugin IDs are left verbatim (shell.json references them).
- `herdr/config.toml` installs only when absent — local herdr preferences are
  never clobbered. `herdr/bindings.lua` is a reference snippet already merged
  into `hypr/bindings.lua`; it is not installed.

Not covered (manual by design): `apps.txt` provisioning (root), logins/secrets
(gh auth, git credential store, ssh, fingerprint), herdr daemon state, nvim
plugin/mise first-run fetches.

Notes:

- `.config/git/config` hardcodes the `gh` credential-helper path under
  `~/.local/share/mise/`; adjust if your mise install lives elsewhere.
- `~/.config/hypr/bindings.lua` calls `/home/zwalton/.local/bin/herdr-omp`
  (installed from `herdr/herdr-omp`).
- The same binding file's `SUPER + SHIFT + S` binding calls
  `/home/zwalton/.local/bin/omarchy-slack` (installed from
  `home/.local/bin/omarchy-slack`); install before that binding works.
- The `vantablack-purple` theme lives in `.config/omarchy/themes/`; apply with
  `omarchy theme set vantablack-purple`.
