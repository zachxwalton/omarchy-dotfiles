#!/usr/bin/env bash
#
# install.sh — apply zachxwalton/omarchy-dotfiles to this machine.
#
# Properties:
#   * Any state: works on a bare Omarchy install or a fully configured one.
#   * Partial state: only files whose content differs from the repo are
#     touched; local extras are never deleted.
#   * Idempotent: on a machine already in sync it writes nothing — no mtime
#     churn, no backup directory, exit 0.
#
# What it does NOT do (deliberately):
#   * No root, no pacman/omarchy pkg changes — apps.txt provisioning is manual
#     (it lists removals too; destructive by design).
#   * No secrets/auth: gh, git credential store contents, ssh, fingerprint.
#   * No herdr daemon/state, no app logins, no nvim plugin fetch.
#
# Usage:
#   install.sh [path-to-clone]     # use an existing checkout (no network)
#   curl -fsSL https://raw.githubusercontent.com/zachxwalton/omarchy-dotfiles/main/install.sh | bash
#
# Replaced files are backed up to
#   ~/.cache/omarchy-dotfiles/backups/<timestamp>/

set -euo pipefail

REPO_URL="${OMARCHY_DOTFILES_URL:-https://github.com/zachxwalton/omarchy-dotfiles.git}"
OLD_USER_DIR="/home/zwalton"   # paths in the repo are pinned to this user

# --- refuse to run as root: dotfiles are per-user ---------------------------
if [ "$(id -u)" -eq 0 ]; then
  echo "install.sh: refusing to run as root (would install into /root). Run as your user." >&2
  exit 1
fi
[ -n "${HOME:-}" ] && [ -d "$HOME" ] || { echo "install.sh: HOME not set or missing." >&2; exit 1; }

# --- locate a source checkout (never mutate it) ----------------------------
SRC=""
TMP_SRC=""
if [ $# -ge 1 ] && [ -d "$1" ]; then
  SRC="$(cd "$1" && pwd)"
elif [ -f "$(cd "$(dirname "$0")" 2>/dev/null && pwd)/home/.config/hypr/hyprland.lua" ]; then
  SRC="$(cd "$(dirname "$0")" && pwd)"
else
  echo "install.sh: cloning $REPO_URL …"
  TMP_SRC="$(mktemp -d)"
  trap 'rm -rf "$TMP_SRC"' EXIT
  git clone --quiet --depth 1 "$REPO_URL" "$TMP_SRC/repo"
  SRC="$TMP_SRC/repo"
fi
[ -f "$SRC/home/.config/hypr/hyprland.lua" ] || { echo "install.sh: $SRC is not an omarchy-dotfiles checkout." >&2; exit 1; }

# --- stage a private copy so substitutions never dirty the source ----------
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE" "$TMP_SRC"' EXIT
cp -a "$SRC/." "$STAGE/"

# Rewrite the pinned user dir. No-op on the machine that produced the repo.
if [ "$HOME" != "$OLD_USER_DIR" ]; then
  sed -i "s|$OLD_USER_DIR|${HOME//&/\\&}|g" \
    "$STAGE/home/.config/hypr/bindings.lua" \
    "$STAGE/home/.config/git/config"
fi

# --- walk the tree and apply only real differences -------------------------
BAK_ROOT="$HOME/.cache/omarchy-dotfiles/backups"
TS="$(date +%Y%m%dT%H%M%S)"
added=0
updated=0

changed_paths=()

same_file() { # $1 staged, $2 dest  → 0 when identical
  local s="$1" d="$2"
  if [ -L "$s" ]; then
    [ -L "$d" ] && [ "$(readlink "$s")" = "$(readlink "$d")" ]
  else
    [ ! -L "$d" ] && cmp -s "$s" "$d"
  fi
}

apply_one() { # $1 source path, $2 dest path, $3 display name
  local s="$1" d="$2" name="$3"
  if [ -e "$d" ] || [ -L "$d" ]; then
    if same_file "$s" "$d"; then
      return
    fi
    # dest is a dir (rare state conflict) or a file/symlink: move aside whole
    mkdir -p "$BAK_ROOT/$TS/$(dirname "$name")"
    mv "$d" "$BAK_ROOT/$TS/$name"
    updated=$((updated + 1))
  else
    added=$((added + 1))
  fi
  mkdir -p "$(dirname "$d")"
  cp -a "$s" "$d"
  changed_paths+=("$name")
}

# home/ mirrors $HOME
while IFS= read -r -d '' f; do
  rel="${f#"$STAGE/home/"}"
  apply_one "$f" "$HOME/$rel" "$rel"
done < <(find "$STAGE/home" \( -type f -o -type l \) -print0 | sort -z)

# extra helpers not under home/
apply_one "$STAGE/herdr/herdr-omp" "$HOME/.local/bin/herdr-omp" ".local/bin/herdr-omp"
if [ ! -e "$HOME/.config/herdr/config.toml" ] && [ ! -L "$HOME/.config/herdr/config.toml" ]; then
  # optional; herdr works without it — never clobber local herdr preferences
  apply_one "$STAGE/herdr/config.toml" "$HOME/.config/herdr/config.toml" ".config/herdr/config.toml"
fi

# executable bits are stored in git, but be explicit anyway
chmod +x "$HOME/.local/bin/herdr-omp" "$HOME/.local/bin/omarchy-slack" 2>/dev/null || true

# --- report ----------------------------------------------------------------
if [ "$added" -eq 0 ] && [ "$updated" -eq 0 ]; then
  echo "install.sh: already in sync — no changes."
  exit 0
fi

echo "install.sh: $added added, $updated updated."
for p in "${changed_paths[@]}"; do
  printf '  %s\n' "$p"
done
if [ "$updated" -gt 0 ]; then
  echo "install.sh: replaced files backed up in $BAK_ROOT/$TS/"
fi

# pick up Hyprland changes when running inside a live session
if [ "$updated" -gt 0 ] || [ "$added" -gt 0 ]; then
  if command -v hyprctl >/dev/null 2>&1 && hyprctl activeworkspace >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 && echo "install.sh: hyprctl reload applied."
  fi
fi

echo
echo "Still manual (not covered by this script):"
echo "  - apps.txt provisioning (sudo pacman/omarchy pkg) — see apps.txt"
echo "  - logins/secrets: gh auth, git credential store, ssh, fingerprint"
echo "  - first-run: nvim plugin fetch, mise tool installs, herdr daemon state"
echo "  - note: .config/git/config's gh helper is pinned to the mise gh version"
echo "    on the source machine; re-run 'gh auth login' if https pushes stall."
