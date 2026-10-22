#!/usr/bin/env bash
set -euo pipefail

# Links all active skills in the repository into the standard skill directories:
#   - ~/.agents/skills (Codex, Antigravity, and Agent Skills harnesses)
#   - ~/.claude/skills (Claude Code)
#
# Each entry is a symlink into this repository, so a `git pull` keeps installed
# skills up to date.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DESTS=("$HOME/.agents/skills" "$HOME/.claude/skills")

# Collect skills from skills/
names=()
srcs=()
while IFS= read -r -d '' skill_md; do
  src="$(dirname "$skill_md")"
  names+=("$(basename "$src")")
  srcs+=("$src")
done < <(find "$REPO/skills" -name SKILL.md -not -path '*/node_modules/*' -print0)

if [ ${#names[@]} -eq 0 ]; then
  echo "No active skills found to link."
  exit 0
fi

for DEST in "${DESTS[@]}"; do
  # Avoid circular linking if DEST is already a symlink pointing into this repo
  if [ -L "$DEST" ]; then
    resolved="$(readlink -f "$DEST" 2>/dev/null || readlink "$DEST")"
    case "$resolved" in
      "$REPO"|"$REPO"/*)
        echo "Warning: $DEST is a symlink into this repo ($resolved). Skipping." >&2
        continue
        ;;
    esac
  fi

  mkdir -p "$DEST"

  for i in "${!names[@]}"; do
    name="${names[$i]}"
    src="${srcs[$i]}"
    target="$DEST/$name"

    if [ -e "$target" ] && [ ! -L "$target" ]; then
      echo "Note: Replacing non-symlink existing file/directory at $target"
      rm -rf "$target"
    fi

    ln -sfn "$src" "$target"
    echo "Linked: $name -> $src ($DEST)"
  done
done

echo "Skills linking complete."
