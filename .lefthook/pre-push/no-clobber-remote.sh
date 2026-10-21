#!/bin/sh
# lefthook pre-push job `no-clobber-remote`. What it measures, how it passes falsely
# and why it is a script: the comments above it in lefthook.yml (D-18, D-75).
# Identical in every fleet repo; keep it that way.
br=$(git rev-parse --abbrev-ref HEAD)
up=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) || exit 0
git fetch --quiet origin "$br" 2>/dev/null || true
behind=$(git rev-list --count "HEAD..$up" 2>/dev/null || echo 0)
if [ "${behind:-0}" -gt 0 ]; then
  echo "✗ $up has $behind commit(s) this clone does not have."
  echo "  A force-push here DISCARDS them. Integrate first: git pull --rebase"
  if [ "${ALLOW_FORCE_PUSH:-0}" = "1" ]; then
    echo "  → ALLOW_FORCE_PUSH=1 set; proceeding on explicit intent."
  else
    echo "  Override deliberately with: ALLOW_FORCE_PUSH=1 git push --force ..."
    exit 1
  fi
fi
