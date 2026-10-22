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
if [ "$ERRORS" -eq 0 ]; then
  echo "ALL VERIFICATION CHECKS PASSED SUCCESSFULLY."
  exit 0
else
  echo "VERIFICATION FAILED WITH $ERRORS ERROR(S)."
  exit 1
fi
