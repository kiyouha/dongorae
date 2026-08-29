#!/usr/bin/env bash
set -euo pipefail

echo "== git status =="
git status --short || true

echo
echo "== git diff stat =="
git diff --stat || true

echo
echo "== recent commits =="
git log --oneline -5 || true

echo
echo "== current AI state =="
if [ -f .ai/CURRENT.md ]; then
  sed -n '1,140p' .ai/CURRENT.md
else
  echo ".ai/CURRENT.md not found"
fi
