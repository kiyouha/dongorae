#!/usr/bin/env bash
set -euo pipefail

# Keep output small for AI consumption.
# Customize this script for your project.

CHANGED_FILES=$(git diff --name-only HEAD 2>/dev/null || true)

echo "== changed files =="
echo "$CHANGED_FILES" | sed '/^$/d' | head -50

echo
echo "== suggested validation =="

if echo "$CHANGED_FILES" | grep -E '(^|/)tests?/|_test\.py$|test_.*\.py$' >/dev/null; then
  echo "Run focused tests for changed test files."
fi

if [ -f manage.py ]; then
  echo "python manage.py check"
fi

if [ -f pyproject.toml ] || [ -f pytest.ini ] || [ -d tests ]; then
  echo "pytest -q"
fi

# Uncomment and customize after choosing project test commands.
# python manage.py check
# pytest -q tests/path/to/focused_test.py
