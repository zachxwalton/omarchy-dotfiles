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
- [`herdr/`](herdr/) — herdr + omp keybind setup: opens a new herdr tab running
  omp instantly from a Hyprland keybind (`SUPER + CTRL + RETURN`).
- [`apps.txt`](apps.txt) — installed & removed apps vs. base Omarchy.

## Restore

```bash
git clone https://github.com/zachxwalton/omarchy-dotfiles.git ~/omarchy-dotfiles
# copy (or symlink) the pieces you want, e.g.
cp -r ~/omarchy-dotfiles/home/.config/* ~/.config/
cp ~/omarchy-dotfiles/home/.XCompose ~/.XCompose
cp ~/omarchy-dotfiles/home/.local/bin/omarchy-slack ~/.local/bin/
```

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
