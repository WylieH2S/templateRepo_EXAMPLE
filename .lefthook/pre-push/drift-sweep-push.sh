#!/usr/bin/env bash
# lefthook pre-push job `drift-sweep-push`. Why this is a script and not a `run:`
# command: the comment above `pre-push:` in lefthook.yml (D-75).
# The --fail-on list is this repo's own and arrives as `args` from lefthook.yml.
# Identical in every fleet repo; keep it that way.
if [ $# -eq 0 ]; then
  echo "✗ drift-sweep-push got no --fail-on list; check its args: in lefthook.yml"
  exit 1
fi
cd "$(git rev-parse --show-toplevel)" || exit 1
exec bash .claude/skills/drift-sweep/sweep.sh "$@"
