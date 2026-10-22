#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"

printf "%-25s | %-15s | %s\n" "Skill" "Bucket" "Location"
printf "%s\n" "--------------------------+-----------------+----------------------------------------"

while IFS= read -r -d '' skill_md; do
  dir="$(dirname "$skill_md")"
  name="$(basename "$dir")"
  bucket="$(basename "$(dirname "$dir")")"
  rel_path="${skill_md#"$REPO"/}"
  printf "%-25s | %-15s | %s\n" "$name" "$bucket" "$rel_path"
done < <(find "$REPO/skills" -name SKILL.md -not -path '*/node_modules/*' | sort -z)
