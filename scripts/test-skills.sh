#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
ERRORS=0

echo "=== 1. Validating Shell Scripts Syntax ==="
for sh_file in "$REPO"/scripts/*.sh; do
  if [ -f "$sh_file" ]; then
    bash -n "$sh_file"
    echo "  OK: $(basename "$sh_file")"
  fi
done

echo ""
echo "=== 2. Validating Python Scripts Syntax ==="
while IFS= read -r -d '' py_file; do
  python3 -m py_compile "$py_file"
  echo "  OK: ${py_file#"$REPO"/}"
done < <(find "$REPO/skills" -name "*.py" -print0)

echo ""
echo "=== 3. Validating SKILL.md Frontmatter ==="
while IFS= read -r -d '' skill_md; do
  rel="${skill_md#"$REPO"/}"
  # Check leading ---
  first_line="$(head -n 1 "$skill_md")"
  if [ "$first_line" != "---" ]; then
    echo "  FAIL: $rel missing leading '---' frontmatter delimiter"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # Check name
  if ! grep -q "^name:" "$skill_md"; then
    echo "  FAIL: $rel missing 'name:' in frontmatter"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # Check description
  if ! grep -q "^description:" "$skill_md"; then
    echo "  FAIL: $rel missing 'description:' in frontmatter"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  echo "  OK: $rel"
done < <(find "$REPO/skills" -name SKILL.md -print0)

echo ""
echo "=== 4. Sanitization & Leak Audit ==="

# Check for hardcoded local absolute paths (/Users/ or /home/)
echo -n "  Checking for local user directory references... "
LEAK_PATHS="$(grep -rnE "(/Users/[a-zA-Z0-9_-]+|/home/[a-zA-Z0-9_-]+)" "$REPO" \
  --exclude-dir=".git" \
  --exclude-dir="__pycache__" \
  --exclude="test-skills.sh" || true)"

if [ -n "$LEAK_PATHS" ]; then
  echo "FAILED!"
  echo "$LEAK_PATHS"
  ERRORS=$((ERRORS + 1))
else
  echo "PASSED (None found)"
fi

# Check for internal test domains and hosts
echo -n "  Checking for internal test domains (*.local, *.internal)... "
LEAK_DOMAINS="$(grep -rnE "(am\.ping\.local|idm\.ping\.local|ping\.local)" "$REPO" \
  --exclude-dir=".git" \
  --exclude-dir="__pycache__" \
  --exclude="test-skills.sh" || true)"

if [ -n "$LEAK_DOMAINS" ]; then
  echo "FAILED!"
  echo "$LEAK_DOMAINS"
  ERRORS=$((ERRORS + 1))
else
  echo "PASSED (None found)"
fi

# Check for hardcoded passwords or credentials
echo -n "  Checking for sample platform passwords and secrets... "
LEAK_SECRETS="$(grep -rnE "(Ch@ng3|Welc0me_P1ng|Adm1n_P@ss)" "$REPO" \
  --exclude-dir=".git" \
  --exclude-dir="__pycache__" \
  --exclude="test-skills.sh" || true)"

if [ -n "$LEAK_SECRETS" ]; then
  echo "FAILED!"
  echo "$LEAK_SECRETS"
  ERRORS=$((ERRORS + 1))
else
  echo "PASSED (None found)"
fi

echo ""
echo "=== 5. Functional Testing (ping-docs.py) ==="
PING_DOCS_SCRIPT="$REPO/skills/ping-identity/ping-docs/scripts/ping-docs.py"
if [ -f "$PING_DOCS_SCRIPT" ]; then
  python3 "$PING_DOCS_SCRIPT" --help > /dev/null
  echo "  OK: ping-docs.py --help"

  python3 "$PING_DOCS_SCRIPT" list-products | head -n 5 > /dev/null
  echo "  OK: ping-docs.py list-products"
else
  echo "  FAIL: ping-docs.py not found at $PING_DOCS_SCRIPT"
  ERRORS=$((ERRORS + 1))
fi

echo ""
echo "=== 6. Functional Testing (link-skills-workspace.sh) ==="
LINK_WS="$REPO/scripts/link-skills-workspace.sh"
TMP_WS="$(mktemp -d)"
trap 'rm -rf "$TMP_WS"' EXIT

check() {
  # check <description> <command...>
  local desc="$1"; shift
  if "$@" > /dev/null 2>&1; then
    echo "  OK: $desc"
  else
    echo "  FAIL: $desc"
    ERRORS=$((ERRORS + 1))
  fi
}

check "dry-run creates nothing" \
  bash -c '"$0" --dry-run "$1" && [ ! -e "$1/.agents" ]' "$LINK_WS" "$TMP_WS"
check "links all skills when no selector is given" \
  bash -c '"$0" "$1" && [ -L "$1/.agents/skills/ping-docs" ]' "$LINK_WS" "$TMP_WS"
check "accepts a category name" \
  "$LINK_WS" "$TMP_WS" ping-identity
check "accepts a skill name and --claude" \
  bash -c '"$0" --claude "$1" ping-docs && [ -L "$1/.claude/skills/ping-docs" ]' "$LINK_WS" "$TMP_WS"
check "rejects an unknown selector" \
  bash -c '! "$0" "$1" not-a-real-skill' "$LINK_WS" "$TMP_WS"
check "rejects the skills repo itself as workspace" \
  bash -c '! "$0" "$1"' "$LINK_WS" "$REPO"
check "keeps an existing real folder without --force" \
  bash -c 'mkdir -p "$1/c/.agents/skills/ping-docs" && "$0" "$1/c" ping-docs && [ ! -L "$1/c/.agents/skills/ping-docs" ]' "$LINK_WS" "$TMP_WS"
check "replaces an existing real folder with --force" \
  bash -c '"$0" --force "$1/c" ping-docs && [ -L "$1/c/.agents/skills/ping-docs" ]' "$LINK_WS" "$TMP_WS"

echo ""
echo "=== 7. Functional Testing (link-skills.sh, using a temporary HOME) ==="
LINK_GLOBAL="$REPO/scripts/link-skills.sh"
FAKE_HOME="$TMP_WS/home"
mkdir -p "$FAKE_HOME"

check "dry-run creates nothing" \
  bash -c 'HOME="$1" "$0" --dry-run && [ ! -e "$1/.agents" ] && [ ! -e "$1/.claude" ]' "$LINK_GLOBAL" "$FAKE_HOME"
check "links all skills into ~/.agents/skills and ~/.claude/skills" \
  bash -c 'HOME="$1" "$0" && [ -L "$1/.agents/skills/ping-docs" ] && [ -L "$1/.claude/skills/ping-docs" ]' "$LINK_GLOBAL" "$FAKE_HOME"
check "accepts a category name" \
  bash -c 'HOME="$1" "$0" ping-identity' "$LINK_GLOBAL" "$FAKE_HOME"
check "accepts a skill name" \
  bash -c 'HOME="$1" "$0" ping-docs' "$LINK_GLOBAL" "$FAKE_HOME"
check "rejects an unknown selector" \
  bash -c '! HOME="$1" "$0" not-a-real-skill' "$LINK_GLOBAL" "$FAKE_HOME"
check "keeps an existing real folder without --force" \
  bash -c 'H="$1/h2"; mkdir -p "$H/.agents/skills/ping-docs" && HOME="$H" "$0" ping-docs && [ ! -L "$H/.agents/skills/ping-docs" ]' "$LINK_GLOBAL" "$TMP_WS"
check "replaces an existing real folder with --force" \
  bash -c 'H="$1/h2"; HOME="$H" "$0" --force ping-docs && [ -L "$H/.agents/skills/ping-docs" ]' "$LINK_GLOBAL" "$TMP_WS"

echo ""
echo "=== 8. Functional Testing (list-workspace-skills.sh) ==="
LIST_WS="$REPO/scripts/list-workspace-skills.sh"

check "displays help message" \
  "$LIST_WS" --help
check "lists workspace and global skills across all harnesses" \
  bash -c 'HOME="$1" "$0" "$2" | grep -q "ping-docs"' "$LIST_WS" "$FAKE_HOME" "$TMP_WS"
check "filters by specific harness (--harness antigravity)" \
  bash -c 'HOME="$1" "$0" --harness antigravity "$2" | grep -q "Antigravity"' "$LIST_WS" "$FAKE_HOME" "$TMP_WS"
check "accepts harness as positional argument (<workspace> <harness>)" \
  bash -c 'HOME="$1" "$0" "$2" claude | grep -q "Harness:   Claude Code"' "$LIST_WS" "$FAKE_HOME" "$TMP_WS"
check "accepts harness as single positional argument (<harness>)" \
  bash -c 'cd "$2" && HOME="$1" "$0" gemini | grep -q "Harness:   Gemini CLI"' "$LIST_WS" "$FAKE_HOME" "$TMP_WS"
check "detects workspace shadowing of global skill with same name" \
  bash -c 'HOME="$1" "$0" --harness claude "$2" | grep -q "shadowed by workspace"' "$LIST_WS" "$FAKE_HOME" "$TMP_WS"
check "outputs valid JSON with --json" \
  bash -c 'HOME="$1" "$0" --json "$2" | python3 -c "import json, sys; data = json.load(sys.stdin); assert \"harnesses\" in data"' "$LIST_WS" "$FAKE_HOME" "$TMP_WS"
check "rejects unknown harness name" \
  bash -c '! HOME="$1" "$0" --harness unknown-harness "$2"' "$LIST_WS" "$FAKE_HOME" "$TMP_WS"

echo ""
if [ "$ERRORS" -eq 0 ]; then
  echo "ALL VERIFICATION CHECKS PASSED SUCCESSFULLY."
  exit 0
else
  echo "VERIFICATION FAILED WITH $ERRORS ERROR(S)."
  exit 1
fi
