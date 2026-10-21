#!/usr/bin/env bash
# lefthook-skip-fixture.sh — does THIS lefthook still run script-form pre-push jobs
# on the two pushes where it skips run-form ones? (D-75, D-18)
#
# lefthook skips a `run:` pre-push job with "(skip) no matching push files" when
# HEAD has no diff against its own @{push}, whatever refs are actually pushed. Two
# pushes hit that by construction:
#   ff-already-pushed   `git push origin work:main` when work is level with origin/work
#   stale-cache-rewind  `git push --force` from a clone whose origin/<br> is stale,
#                       i.e. another host pushed. The destructive one.
# Script-form jobs (`script:` + `runner:`) were measured NOT to skip there:
# lefthook 2.1.11 on CHLOE-WyliNux and 2.1.8 on ChloeMac, 2026-10-20 (D-75). The
# fleet's pre-push arms are script-form BECAUSE of this. It is observed behaviour,
# not documented, so re-run this after any lefthook upgrade, on every host:
#   bash ~/GitHub/.claude/skills/drift-sweep/lefthook-skip-fixture.sh
# Exit 0 = script form still fires. Exit 1 = the arms are inert on those pushes
# again; fall back to `lefthook run pre-push --force` by hand until fixed.
#
# Writes only under a mktemp dir, with HOME pointed inside it; removes it on exit.
set -u
command -v lefthook >/dev/null 2>&1 || { echo "lefthook not on PATH"; exit 2; }
T=$(mktemp -d "${TMPDIR:-/tmp}/lh-skip.XXXXXX") || exit 2
trap 'rm -rf "$T"' EXIT
export HOME="$T/home" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME" && printf '[user]\n\tname = fixture\n\temail = fixture@localhost\n[init]\n\tdefaultBranch = main\n' > "$HOME/.gitconfig"
LOG="$T/fired.log"
q() { "$@" >/dev/null 2>&1; }

q git init --bare "$T/remote.git" && q git clone "$T/remote.git" "$T/a" && cd "$T/a" || exit 2
q git checkout -b main
mkdir -p .lefthook/pre-push
printf '#!/bin/sh\necho "S:$*" >> "%s"\n' "$LOG" > .lefthook/pre-push/s.sh
cat > lefthook.yml <<EOF
pre-push:
  jobs:
    - name: run-form
      run: echo R >> "$LOG"
    - name: script-form
      script: s.sh
      runner: sh
      args: --quiet --fail-on=x,y
EOF
echo 1 > f && q git add -A && q git commit -m init && q lefthook install || { echo "lefthook install failed"; exit 2; }
q git push -u origin main

fired() { r=SKIP; s=SKIP; grep -qx R "$LOG" 2>/dev/null && r=FIRED; grep -q '^S:' "$LOG" 2>/dev/null && s=FIRED; echo "run=$r script=$s"; }

# ff-already-pushed
q git checkout -b work && echo 2 >> f && q git commit -am w1 && q git push -u origin work
: > "$LOG"; q git push origin work:main; FF=$(fired)
ARGS=$(grep -m1 '^S:' "$LOG" 2>/dev/null)

# stale-cache-rewind: b clones, a pushes, b force-pushes without fetching
q git clone -b work "$T/remote.git" "$T/b" && (cd "$T/b" && q lefthook install)
echo 3 >> f && q git commit -am fromA && q git push origin work
: > "$LOG"; (cd "$T/b" && q git push --force origin work); RW=$(fired)

echo "lefthook $(lefthook version 2>/dev/null)"
echo "ff-already-pushed:  $FF"
echo "stale-cache-rewind: $RW"
echo "script args:        ${ARGS:-none}"
case "$FF|$RW|$ARGS" in
  *"script=FIRED"*"|"*"script=FIRED"*"|S:--quiet --fail-on=x,y") echo "PASS: script form fires on both"; exit 0 ;;
  *) echo "FAIL: script form skipped or lost its args — the pre-push arms are inert on this push"; exit 1 ;;
esac
