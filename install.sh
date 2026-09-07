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
#   * Keybindings are opinionated: each one is applied only after per-key
#     confirmation (bindings.lua is an override layer, never rewritten
#     wholesale). Declined keys are remembered for later runs.
#     OMARCHY_DOTFILES_BINDINGS=ask (default) | all | skip
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
BIND_TMP=""
trap 'rm -rf "$STAGE" "$TMP_SRC" "$BIND_TMP"' EXIT
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

# home/ mirrors $HOME — but bindings.lua is consent-gated (see below)
BIND_REL=".config/hypr/bindings.lua"
while IFS= read -r -d '' f; do
  rel="${f#"$STAGE/home/"}"
  [ "$rel" = "$BIND_REL" ] && continue
  apply_one "$f" "$HOME/$rel" "$rel"
done < <(find "$STAGE/home" \( -type f -o -type l \) -print0 | sort -z)

# extra helpers not under home/
apply_one "$STAGE/herdr/herdr-omp" "$HOME/.local/bin/herdr-omp" ".local/bin/herdr-omp"
if [ ! -e "$HOME/.config/herdr/config.toml" ] && [ ! -L "$HOME/.config/herdr/config.toml" ]; then
  # optional; herdr works without it — never clobber local herdr preferences
  apply_one "$STAGE/herdr/config.toml" "$HOME/.config/herdr/config.toml" ".config/herdr/config.toml"
fi

# --- keybindings: opinionated, per-key consent ------------------------------
# ~/.config/hypr/bindings.lua is an override layer: Omarchy defaults live in
# /usr/share/omarchy/default/hypr/bindings/. This file only carries personal
# rebinds, so we apply each binding individually and never rewrite the user's
# file wholesale. Declined bindings are remembered so later runs stay silent.
BIND_STAGE="$STAGE/home/$BIND_REL"
BIND_LIVE="$HOME/$BIND_REL"
CACHE="$HOME/.cache/omarchy-dotfiles"
BIND_POLICY="${OMARCHY_DOTFILES_BINDINGS:-ask}"   # ask | all | skip
BIND_SKIP="$CACHE/bindings.skip"
BIND_TMP="$(mktemp -d)"
bind_pending=0

have_terminal() { [ -t 0 ] || { [ -r /dev/tty ] && [ -e /dev/tty ]; }; }

confirm() { # $1 prompt → 0 yes / 1 no (never hangs without a terminal)
  local ans
  printf '%b' "$1" >&2
  if [ -t 0 ]; then read -r ans || ans=n
  else read -r ans < /dev/tty || ans=n
  fi
  case "$ans" in y|Y|yes|YES) return 0;; *) return 1;; esac
}

bind_name_of() { # $1 lua o.bind line → action label ("" if unlabeled)
  local l="$1"
  l="${l#*o.bind(}"
  l="${l#*\"}"            # past key
  l="${l#*\"}"            # past key's closing quote
  l="${l#,}"              # past comma
  l="${l#*[[:space:]]}"   # strip whitespace
  case "$l" in
    \"*) l="${l#\"}"; l="${l%%\"*}" ;;
    *) l="" ;;
  esac
  printf '%s' "$l"
}

# Split the staged file into executable units (hl.unbind + o.bind lines only;
# comments/template text are dropped). Emit one file per unit + an index.
if [ -s "$BIND_STAGE" ]; then
  awk -v out="$BIND_TMP" '
    {
      if ($0 !~ /^[[:space:]]*--/ && $0 ~ /o\.bind\(/) {
        n++
        exe = ""
        nb = split(buf, L, "\n")
        for (i = 1; i <= nb; i++) {
          ln = L[i]
          if (ln !~ /^[[:space:]]*--/ && (ln ~ /o\.bind\(/ || ln ~ /hl\.unbind\(/))
            exe = exe ln "\n"
        }
        printf "%s", exe > (out "/unit-" n)
        close(out "/unit-" n)
        printf "%s\n", $0 >> (out "/unit-" n)   # the o.bind line itself
        close(out "/unit-" n)
        print n "\t" $0 > (out "/index")
        buf = ""
        next
      }
      buf = buf $0 ORS
    }
  ' "$BIND_STAGE"
fi

if [ -s "$BIND_TMP/index" ]; then
  warned=0
  while IFS=$'\t' read -r idx oline; do
    [ -n "$idx" ] || continue
    key="$(printf '%s' "$oline" | sed -n 's/^[[:space:]]*o\.bind("\([^"]*\)".*/\1/p')"
    [ -n "$key" ] || continue
    name="$(bind_name_of "$oline")"
    [ -n "$name" ] || name="(unlabeled action)"
    unit="$(cat "$BIND_TMP/unit-$idx")"
    oline_exact="$(printf '%s' "$unit" | awk '/^[[:space:]]*o\.bind\(/{l=$0} END{print l}')"
    hash="$(printf '%s' "$oline_exact" | md5sum | cut -d' ' -f1)"

    # already effective on this machine?
    if [ -e "$BIND_LIVE" ] && grep -Fqx "$oline_exact" "$BIND_LIVE" 2>/dev/null; then
      continue
    fi
    # previously declined, unchanged since?
    if [ "$BIND_POLICY" != "all" ] && grep -Fq "$key	$hash" "$BIND_SKIP" 2>/dev/null; then
      continue
    fi

    bind_pending=$((bind_pending + 1))
    occupant=""
    if [ -e "$BIND_LIVE" ] && grep -Fq "o.bind(\"$key\"" "$BIND_LIVE" 2>/dev/null; then
      occ_line="$(grep -F "o.bind(\"$key\"" "$BIND_LIVE" | head -n1)"
      occ="$(bind_name_of "$occ_line")"
      [ -n "$occ" ] && occupant=" (currently: $occ)"
    fi
    desc="  [$idx] $key  →  $name$occupant"

    approve=0
    case "$BIND_POLICY" in
      all) approve=1 ;;
      skip) ;;
      *)
        if have_terminal; then
          if [ "$warned" -eq 0 ]; then
            warned=1
            echo
            echo "Keybindings: the repo rebinds some keys to personal, opinionated"
            echo "actions (it replaces Omarchy defaults and launches private scripts)."
            echo "Each key below is applied only if you confirm it."
          fi
          if confirm "$desc\n      Apply this keybinding? [y/N] "; then approve=1; fi
        else
          if [ "$warned" -eq 0 ]; then
            warned=1
            echo "install.sh: no terminal available to ask about keybindings — leaving" >&2
            echo "  them untouched. Re-run in a terminal, or set" >&2
            echo "  OMARCHY_DOTFILES_BINDINGS=all (apply all) / skip (never touch)." >&2
          fi
        fi
        ;;
    esac

    if [ "$approve" -eq 1 ]; then
      mkdir -p "$BIND_TMP/approved"
      printf '%s' "$unit" > "$BIND_TMP/approved/unit-$idx"
    elif [ "$BIND_POLICY" = "ask" ]; then
      mkdir -p "$CACHE"
      printf '%s\t%s\n' "$key" "$hash" >> "$BIND_SKIP"
    fi
  done < "$BIND_TMP/index"
fi

approved_units=""
if [ -d "$BIND_TMP/approved" ]; then
  approved_units="$(find "$BIND_TMP/approved" -type f | sort -V)"
fi
if [ -n "$approved_units" ]; then
  orig=""
  if [ -e "$BIND_LIVE" ] || [ -L "$BIND_LIVE" ]; then
    orig="$(cat "$BIND_LIVE")"
  fi
  content="$orig"
  for u in $approved_units; do
    if [ -n "$content" ] && [[ "$content" != *$'\n' ]]; then
      content+=$'\n'
    fi
    content+=$'\n'"$(cat "$u")"
  done
  if [ "$content" != "$orig" ]; then
    if [ -n "$orig" ]; then
      mkdir -p "$BAK_ROOT/$TS/$(dirname "$BIND_REL")"
      mv "$BIND_LIVE" "$BAK_ROOT/$TS/$BIND_REL"
      updated=$((updated + 1))
    else
      added=$((added + 1))
    fi
    mkdir -p "$(dirname "$BIND_LIVE")"
    printf '%s' "$content" > "$BIND_LIVE"
    changed_paths+=("$BIND_REL")
    echo "install.sh: keybindings applied: $(for u in $approved_units; do sed -n 's/^[[:space:]]*o\.bind("\([^"]*\)".*/  \1/p' "$u"; done)"
  fi
fi
if [ "$bind_pending" -gt 0 ] && [ -z "$approved_units" ]; then
  case "$BIND_POLICY" in
    skip) echo "install.sh: keybindings left as-is (OMARCHY_DOTFILES_BINDINGS=skip)." ;;
    *) echo "install.sh: keybindings left as-is (declined or no terminal to confirm)." ;;
  esac
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
