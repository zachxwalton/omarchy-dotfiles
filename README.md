# omarchy-dotfiles

Clean, light, and extremely opinionated configuration for [Omarchy](https://omarchy.org/)

## Screenshot

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/b127ed99-0d65-4307-b4ff-47b69bc234e3" />

## Contents

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

