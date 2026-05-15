#!/usr/bin/env bash
# validate-substrate — check a repo for two-tier substrate compliance.
#
# Usage: bash validate.sh [<repo-path>]   (default: current dir)
#
# Exit codes:
#   0 = no failures (warnings allowed)
#   1 = one or more FAIL checks

set -uo pipefail

REPO="${1:-.}"
cd "$REPO" || { echo "Cannot enter $REPO"; exit 2; }

FAILS=0
WARNS=0

pass() { echo "  ✓ $*"; }
warn() { echo "  ⚠ $*"; WARNS=$((WARNS+1)); }
fail() { echo "  ✗ $*"; FAILS=$((FAILS+1)); }

section() { echo; echo "── $* ──"; }

echo "Validating substrate in: $(pwd)"

# ── Tier 1 required files ─────────────────────────────────────
section "Tier 1 required files"
for f in CLAUDE.md readme_AI.chloeai ai_context/ai_rules.chloeai ai_context/glossary.chloeai ai_context/START_HERE.md; do
  if [ -f "$f" ]; then
    pass "$f"
  else
    fail "$f (missing)"
  fi
done

# ── Path-scoped rules ─────────────────────────────────────────
section "Path-scoped rules (.claude/rules/)"
for f in code.chloeai tests.chloeai ai-context.chloeai docs.chloeai; do
  path=".claude/rules/$f"
  if [ -f "$path" ]; then
    pass "$path"
  else
    warn "$path (missing — OK if not referenced from CLAUDE.md)"
  fi
done

# ── Hygiene ───────────────────────────────────────────────────
section "Hygiene"
[ -f .gitignore ] && pass ".gitignore" || fail ".gitignore (missing)"
[ -f AI_HANDOFF.chloeai ] && pass "AI_HANDOFF.chloeai" || warn "AI_HANDOFF.chloeai (missing — OK for very new repos)"
[ -f WORKSHEET.heywy ] && pass "WORKSHEET.heywy" || warn "WORKSHEET.heywy (missing)"
[ -f SIDEQUESTS.chloeai ] && pass "SIDEQUESTS.chloeai" || warn "SIDEQUESTS.chloeai (missing)"

# ── Tracked junk ──────────────────────────────────────────────
section "Tracked junk check"
if [ -d .git ]; then
  ds=$(git ls-files 2>/dev/null | grep -c "\.DS_Store$" || true)
  if [ "$ds" -gt 0 ]; then
    fail "$ds tracked .DS_Store files"
  else
    pass "No tracked .DS_Store"
  fi

  envs=$(git ls-files 2>/dev/null | grep -cE '(^|/)\.env$|\.env\.local$|\.env\.production$' || true)
  if [ "$envs" -gt 0 ]; then
    fail "$envs tracked .env files"
  else
    pass "No tracked .env files"
  fi
else
  warn "Not a git repo — skipping tracked-junk check"
fi

# ── Freshness ─────────────────────────────────────────────────
section "Freshness"
ninety_days_ago=$(date -v-90d +%s 2>/dev/null || date -d "90 days ago" +%s)

for f in ai_context/current_state.md AI_HANDOFF.chloeai readme_AI.chloeai; do
  if [ -f "$f" ]; then
    mtime=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null)
    if [ "$mtime" -lt "$ninety_days_ago" ]; then
      warn "$f not touched in >90 days"
    else
      pass "$f fresh"
    fi
  fi
done

# ── Size sanity ───────────────────────────────────────────────
section "Size sanity"
if [ -f AI_HANDOFF.chloeai ]; then
  size=$(wc -c < AI_HANDOFF.chloeai)
  if [ "$size" -gt 204800 ]; then
    warn "AI_HANDOFF.chloeai is $((size / 1024)) KB — consider rotating older entries to an archive"
  else
    pass "AI_HANDOFF.chloeai size OK"
  fi
fi

# ── Summary ───────────────────────────────────────────────────
echo
echo "── Summary ──"
echo "Failures: $FAILS"
echo "Warnings: $WARNS"

if [ "$FAILS" -gt 0 ]; then
  exit 1
fi
exit 0
