#!/usr/bin/env bash
set -euo pipefail

# Links skills from this repository into a specific workspace (project folder)
# instead of the global home directory. Each entry is a symlink into this repo,
# so a `git pull` keeps the linked skills up to date.

usage() {
  cat <<'EOF'
Usage: link-skills-workspace.sh [options] <workspace-dir> [skill-or-category ...]

Links skills from this repository into <workspace-dir>/.agents/skills.

Arguments:
  <workspace-dir>      Existing project folder to link skills into.
  skill-or-category    Optional, repeatable. Either a skill name (e.g. ping-docs)
                       or a category folder under skills/ (e.g. ping-identity),
                       which links every skill inside it.
                       If omitted, all skills are linked.

Options:
  --claude     Also link into <workspace-dir>/.claude/skills (Claude Code).
  --force      Replace an existing real folder that has the same skill name.
               Without this flag, such folders are left untouched and skipped.
  --dry-run    Show what would happen without changing anything.
  -h, --help   Show this help.

Examples:
  link-skills-workspace.sh ~/projects/my-app
  link-skills-workspace.sh ~/projects/my-app ping-docs
  link-skills-workspace.sh ~/projects/my-app ping-identity
  link-skills-workspace.sh --dry-run --claude ~/projects/my-app ping-identity
EOF
}

REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
SKILLS_ROOT="$REPO/skills"

WITH_CLAUDE=0
FORCE=0
DRY_RUN=0
POSITIONAL=()

while [ $# -gt 0 ]; do
  case "$1" in
    --claude) WITH_CLAUDE=1 ;;
    --force) FORCE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    --)
      shift
      while [ $# -gt 0 ]; do POSITIONAL+=("$1"); shift; done
      break
      ;;
    -*) echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) POSITIONAL+=("$1") ;;
  esac
  shift
done

if [ ${#POSITIONAL[@]} -lt 1 ]; then
  echo "error: missing <workspace-dir>" >&2
  usage >&2
  exit 2
fi

WS_INPUT="${POSITIONAL[0]}"
SELECTORS=()
i=1
while [ $i -lt ${#POSITIONAL[@]} ]; do
  SELECTORS+=("${POSITIONAL[$i]}")
  i=$((i + 1))
done

# --- Validate workspace -------------------------------------------------------
if [ ! -d "$WS_INPUT" ]; then
  echo "error: workspace folder does not exist: $WS_INPUT" >&2
  exit 1
fi
WS="$(cd "$WS_INPUT" && pwd -P)"

case "$WS" in
  "$REPO"|"$REPO"/*)
    echo "error: the workspace cannot be this skills repository or a folder inside it." >&2
    exit 1
    ;;
esac

# --- Discover all skills ------------------------------------------------------
ALL_NAMES=()
ALL_SRCS=()
ALL_CATS=()
while IFS= read -r -d '' skill_md; do
  src="$(dirname "$skill_md")"
  rel="${src#"$SKILLS_ROOT"/}"
  ALL_SRCS+=("$src")
  ALL_NAMES+=("$(basename "$src")")
  ALL_CATS+=("${rel%%/*}")
done < <(find "$SKILLS_ROOT" -name SKILL.md -not -path '*/node_modules/*' -print0)

if [ ${#ALL_NAMES[@]} -eq 0 ]; then
  echo "No skills found in $SKILLS_ROOT."
  exit 0
fi

print_available() {
  echo "Available categories and skills:" >&2
  for idx in "${!ALL_NAMES[@]}"; do
    echo "  ${ALL_CATS[$idx]}/${ALL_NAMES[$idx]}" >&2
  done
}

# --- Resolve selection --------------------------------------------------------
SELECTED=" "
add_idx() {
  case "$SELECTED" in
    *" $1 "*) ;;
    *) SELECTED="$SELECTED$1 " ;;
  esac
}

if [ ${#SELECTORS[@]} -eq 0 ]; then
  for idx in "${!ALL_NAMES[@]}"; do add_idx "$idx"; done
else
  for sel in "${SELECTORS[@]}"; do
    matched=0
    # 1. Category: a top-level folder under skills/
    for idx in "${!ALL_CATS[@]}"; do
      if [ "${ALL_CATS[$idx]}" = "$sel" ]; then
        add_idx "$idx"
        matched=1
      fi
    done
    # 2. Skill name
    if [ $matched -eq 0 ]; then
      for idx in "${!ALL_NAMES[@]}"; do
        if [ "${ALL_NAMES[$idx]}" = "$sel" ]; then
          add_idx "$idx"
          matched=1
        fi
      done
    fi
    if [ $matched -eq 0 ]; then
      echo "error: '$sel' is not a known skill or category." >&2
      print_available
      exit 1
    fi
  done
fi

# Two selected skills with the same name would overwrite each other.
SEEN_NAMES=" "
for idx in $SELECTED; do
  name="${ALL_NAMES[$idx]}"
  case "$SEEN_NAMES" in
    *" $name "*)
      echo "error: more than one selected skill is named '$name'. Select them individually." >&2
      exit 1
      ;;
  esac
  SEEN_NAMES="$SEEN_NAMES$name "
done

# --- Link ---------------------------------------------------------------------
DESTS=("$WS/.agents/skills")
if [ $WITH_CLAUDE -eq 1 ]; then
  DESTS+=("$WS/.claude/skills")
fi

TAG=""
if [ $DRY_RUN -eq 1 ]; then
  TAG="[dry-run] "
fi

run() {
  if [ $DRY_RUN -eq 0 ]; then
    "$@"
  fi
}

SKIPPED=0
for DEST in "${DESTS[@]}"; do
  # If DEST is a symlink into this repo, linking would write back into the repo.
  if [ -L "$DEST" ]; then
    resolved="$(cd "$DEST" 2>/dev/null && pwd -P || true)"
    case "$resolved" in
      "$REPO"|"$REPO"/*)
        echo "warning: $DEST is a symlink into this repo ($resolved). Skipping." >&2
        continue
        ;;
    esac
  fi

  echo "${TAG}Target: $DEST"
  run mkdir -p "$DEST"

  for idx in $SELECTED; do
    name="${ALL_NAMES[$idx]}"
    src="${ALL_SRCS[$idx]}"
    target="$DEST/$name"

    if [ -L "$target" ]; then
      current="$(readlink "$target")"
      if [ "$current" = "$src" ]; then
        echo "  ${TAG}up to date: $name"
      else
        run ln -sfn "$src" "$target"
        echo "  ${TAG}relinked:   $name -> $src (was $current)"
      fi
    elif [ -e "$target" ]; then
      if [ $FORCE -eq 1 ]; then
        run rm -rf "$target"
        run ln -sfn "$src" "$target"
        echo "  ${TAG}replaced:   $name -> $src (existing folder removed)"
      else
        echo "  ${TAG}skipped:    $name ($target already exists and is not a symlink; use --force to replace)"
        SKIPPED=$((SKIPPED + 1))
      fi
    else
      run ln -sfn "$src" "$target"
      echo "  ${TAG}linked:     $name -> $src"
    fi
  done
done

if [ -e "$WS/.git" ]; then
  echo ""
  echo "Note: $WS is a git repository. The symlinks point to absolute paths on this"
  echo "machine. Add them to that repo's .gitignore if you don't want to commit them."
fi

if [ $SKIPPED -gt 0 ]; then
  echo ""
  echo "${TAG}Done with $SKIPPED skipped skill(s)."
else
  echo ""
  echo "${TAG}Done."
fi
