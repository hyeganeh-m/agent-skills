#!/usr/bin/env bash
set -euo pipefail

# Links skills from this repository into the global skill directories:
#   - ~/.agents/skills (Antigravity, Codex, and Agent Skills harnesses)
#   - ~/.claude/skills (Claude Code)
#
# Each entry is a symlink into this repository, so a `git pull` keeps installed
# skills up to date.
#
# This is a thin wrapper around link-skills-workspace.sh with the workspace set
# to $HOME and --claude enabled, so both scripts share the same selection and
# safety logic.

usage() {
  cat <<'EOF'
Usage: link-skills.sh [options] [skill-or-category ...]

Links skills from this repository into ~/.agents/skills and ~/.claude/skills.

Arguments:
  skill-or-category    Optional, repeatable. Either a skill name (e.g. ping-docs)
                       or a category folder under skills/ (e.g. ping-identity),
                       which links every skill inside it.
                       If omitted, all skills are linked.

Options:
  --force      Replace an existing real folder that has the same skill name.
               Without this flag, such folders are left untouched and skipped.
  --dry-run    Show what would happen without changing anything.
  -h, --help   Show this help.

Examples:
  link-skills.sh
  link-skills.sh ping-docs
  link-skills.sh ping-identity
  link-skills.sh --dry-run ping-identity
EOF
}

for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --) break ;;
  esac
done

exec "$(cd "$(dirname "$0")" && pwd -P)/link-skills-workspace.sh" --claude "$HOME" "$@"
