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

# Template mode: init-project.sh present means we're validating the template
# itself (not a bootstrapped project). Some checks are softened in this mode
# because placeholder tokens and unresolved EXTENDS paths are expected.
TEMPLATE_MODE=0
if [ -f init-project.sh ]; then
  TEMPLATE_MODE=1
fi

echo "Validating substrate in: $(pwd)"
[ "$TEMPLATE_MODE" -eq 1 ] && echo "(template mode — init-project.sh detected)"

# ── Tier 1 required files ─────────────────────────────────────
section "Tier 1 required files"
for f in CLAUDE.md STARTUP_AI.ai readme_AI.ai ai_context/ai_rules.ai ai_context/glossary.ai ai_context/START_HERE.md; do
  if [ -f "$f" ]; then
    pass "$f"
  else
    fail "$f (missing)"
  fi
done

# ── ai_modules/ required modules ──────────────────────────────
section "ai_modules/"
if [ -d ai_modules ]; then
  pass "ai_modules/ directory"
  if [ -f ai_modules/hi_mode.ai ]; then
    pass "ai_modules/hi_mode.ai"
  else
    fail "ai_modules/hi_mode.ai (missing — HI Mode shim required)"
  fi
else
  fail "ai_modules/ (missing — required for HI Mode shim)"
fi

# ── EXTENDS path resolution ───────────────────────────────────
section "EXTENDS path resolution"
if [ -f ai_modules/hi_mode.ai ]; then
  extends_raw=$(grep -E '^EXTENDS=' ai_modules/hi_mode.ai | head -1 | sed -E 's/^EXTENDS="?([^"]*)"?$/\1/')
  if [ -n "$extends_raw" ]; then
    # Expand ~ to $HOME
    extends_path="${extends_raw/#\~/$HOME}"
    if [ -f "$extends_path" ]; then
      pass "EXTENDS resolves: $extends_raw"
    elif [ "$TEMPLATE_MODE" -eq 1 ]; then
      warn "EXTENDS path not found: $extends_raw — expected in template (will be valid after bootstrap on target machine)"
    else
      fail "EXTENDS path not found: $extends_raw (expanded: $extends_path) — central charter missing or moved"
    fi
  else
    warn "hi_mode.ai has no EXTENDS line"
  fi
fi

# ── Path-scoped rules ─────────────────────────────────────────
section "Path-scoped rules (.claude/rules/)"
for f in code.ai tests.ai ai-context.ai docs.ai; do
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
[ -f AI_HANDOFF.ai ] && pass "AI_HANDOFF.ai" || warn "AI_HANDOFF.ai (missing — OK for very new repos)"
[ -f WORKSHEET.human ] && pass "WORKSHEET.human" || warn "WORKSHEET.human (missing)"
[ -f SIDEQUESTS.ai ] && pass "SIDEQUESTS.ai" || warn "SIDEQUESTS.ai (missing)"

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

  locals=$(git ls-files 2>/dev/null | grep -cE '\.local\.json$' || true)
  if [ "$locals" -gt 0 ]; then
    fail "$locals tracked *.local.json files"
  else
    pass "No tracked *.local.json files"
  fi
else
  warn "Not a git repo — skipping tracked-junk check"
fi

# ── Leftover placeholder tokens ───────────────────────────────
section "Leftover {{TOKEN}} placeholders"
if [ "$TEMPLATE_MODE" -eq 1 ]; then
  pass "Skipped (template mode — placeholders are expected and filled by init-project.sh)"
else
  # Scan only git-tracked files so vendor dirs, generated caches, and
  # untracked local files don't produce false positives.
  leftover=$(git ls-files 2>/dev/null | xargs grep -lE '\{\{[A-Z_]+\}\}' 2>/dev/null || true)
  if [ -n "$leftover" ]; then
    count=$(echo "$leftover" | wc -l | tr -d ' ')
    fail "$count file(s) contain unfilled {{TOKEN}} placeholders:"
    echo "$leftover" | head -10 | sed 's/^/      /'
    [ "$count" -gt 10 ] && echo "      ... and $((count - 10)) more"
  else
    pass "No leftover {{TOKEN}} placeholders"
  fi
fi

# ── Freshness ─────────────────────────────────────────────────
section "Freshness"
ninety_days_ago=$(date -v-90d +%s 2>/dev/null || date -d "90 days ago" +%s)

for f in ai_context/current_state.md AI_HANDOFF.ai readme_AI.ai; do
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
if [ -f AI_HANDOFF.ai ]; then
  size=$(wc -c < AI_HANDOFF.ai)
  if [ "$size" -gt 204800 ]; then
    warn "AI_HANDOFF.ai is $((size / 1024)) KB — consider rotating older entries to an archive (threshold 200 KB)"
  else
    pass "AI_HANDOFF.ai size OK"
  fi
fi
if [ -f ai_context/current_state.md ]; then
  size=$(wc -c < ai_context/current_state.md)
  if [ "$size" -gt 51200 ]; then
    warn "ai_context/current_state.md is $((size / 1024)) KB — consider rotating older deltas to readme_AI_archive.ai (threshold 50 KB)"
  else
    pass "ai_context/current_state.md size OK"
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
