#!/usr/bin/env bash
# validate-substrate — check a repo for two-tier substrate compliance
# + Agent Boot Contract conformance (ADR-BOOT-001: the tool-agnostic boot floor).
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

# The two placeholder tokens, as LITERAL text, assembled from pieces so that
# init-project.sh's substitution pass cannot rewrite them: neither `{{AI}}` nor
# `{{HUMAN}}` ever appears contiguously in this file's source. Everywhere else
# in this fork the tokens are written plainly BECAUSE they are meant to be
# substituted; the two checks below are the exception — they have to keep
# talking about an unfilled placeholder after this repo's own placeholders are
# filled, which is only possible if the sed cannot see them.
_PH_AI='{'"{AI}"'}'
_PH_HUMAN='{'"{HUMAN}"'}'

# Template mode: we're validating the template ITSELF, not a bootstrapped
# project. Several checks are softened here because placeholder tokens and
# unresolved EXTENDS paths are the correct state for a blueprint.
#
# TWO CONDITIONS, not one (tightened 2026-08-16). This used to test only
# `-f init-project.sh`, and init-project.sh's self-delete is a PROMPT that
# DEFAULTS TO NO. So a real seeded repo whose owner pressed Enter kept the
# script and was silently validated in template mode — with the leftover-
# placeholder check and the EXTENDS check both softened, on the one repo where
# an unfilled placeholder is an actual defect. A softened check on a repo that
# needs the strict one reports clean and means nothing.
#
# The second condition cannot survive seeding: init renames every placeholder-
# named file unconditionally — no prompt — so a repo that has been through init
# has no such file left, whatever it did with init-project.sh afterwards. Note
# this MUST use the escaped tokens above: written plainly, the glob would be
# substituted to this project's real extension and then match after init,
# putting every seeded repo permanently in template mode.
TEMPLATE_MODE=0
if [ -f init-project.sh ]; then
  if compgen -G "*.${_PH_AI}ai" >/dev/null 2>&1 || compgen -G "*.hey${_PH_HUMAN}" >/dev/null 2>&1; then
    TEMPLATE_MODE=1
  fi
fi

echo "Validating substrate in: $(pwd)"
[ "$TEMPLATE_MODE" -eq 1 ] && echo "(template mode — init-project.sh present AND substrate still placeholder-named)"

# Resolve a substrate filename. The AI-file extension in this script is the
# per-duo placeholder token (ADR-009) that init-project.sh expands at
# bootstrap; the script itself is substituted in the same pass, so the name it
# checks always matches what is on disk — in template mode (token unexpanded,
# files carry the token name) AND post-init (both expanded). Echoes the
# filename if present; rc=1 if missing. Kept as a function so any future
# naming-variant logic only has to change one place. This is what lets the
# template itself validate 0-fails and serve as the boot-contract conformance
# oracle (ADR-BOOT-001).
resolve_file() {
  if [ -f "$1" ]; then printf '%s' "$1"; return 0; fi
  return 1
}

# ── Tier 1 required files ─────────────────────────────────────
section "Tier 1 required files"
for f in CLAUDE.md STARTUP_AI.{{AI}}ai readme_AI.{{AI}}ai ai_context/ai_rules.{{AI}}ai ai_context/glossary.{{AI}}ai ai_context/START_HERE.md; do
  if found=$(resolve_file "$f"); then
    pass "$found"
  else
    fail "$f (missing)"
  fi
done

# ── ai_modules/ required modules ──────────────────────────────
section "ai_modules/"
HI_MODE_FILE=""
if [ -d ai_modules ]; then
  pass "ai_modules/ directory"
  if HI_MODE_FILE=$(resolve_file ai_modules/hi_mode.{{AI}}ai); then
    pass "$HI_MODE_FILE"
  else
    fail "ai_modules/hi_mode.{{AI}}ai (missing — HI Mode shim required)"
  fi
else
  fail "ai_modules/ (missing — required for HI Mode shim)"
fi

# ── EXTENDS path resolution ───────────────────────────────────
section "EXTENDS path resolution"
if [ -n "$HI_MODE_FILE" ]; then
  extends_raw=$(grep -E '^EXTENDS=' "$HI_MODE_FILE" | head -1 | sed -E 's/^EXTENDS="?([^"]*)"?$/\1/')
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
    warn "hi_mode.{{AI}}ai has no EXTENDS line"
  fi
fi

# ── Path-scoped rules ─────────────────────────────────────────
section "Path-scoped rules (.claude/rules/)"
for f in code.{{AI}}ai tests.{{AI}}ai ai-context.{{AI}}ai docs.{{AI}}ai; do
  path=".claude/rules/$f"
  if found=$(resolve_file "$path"); then
    pass "$found"
  else
    warn "$path (missing — OK if not referenced from CLAUDE.md)"
  fi
done

# ── Agent Boot Contract (ADR-BOOT-001) ────────────────────────
# Conformance per .repo-manager/standards/boot-contract/BOOT-CONTRACT.{{AI}}ai.
# R1 (STARTUP_AI capsule present → FAIL) is enforced by the Tier-1 loop above.
# R2  CLAUDE.md + AGENTS.md must name STARTUP_AI as the bootstrap    → FAIL
# R3  START_HERE.md must not present a competing "Boot Sequence"     → WARN
#     (a Boot Sequence heading is fine iff the file carries the
#      "not a competing boot sequence" deferral to STARTUP_AI)
# W1  lefthook.yml must carry the drift-sweep wrap-continuity arm    → FAIL
#     (git-native: fires for ANY agent that commits — Claude, Codex, …;
#      the .claude/ SessionStart gates are UX on top, never the floor)
# W3  .claude/settings.json SessionStart gate pair                   → WARN
section "Agent Boot Contract (ADR-BOOT-001)"

# R2 — entry docs are pointers to the capsule, not boot sequences
for doc in CLAUDE.md AGENTS.md; do
  if [ ! -f "$doc" ]; then
    fail "$doc missing (R2: both entry docs must exist and name STARTUP_AI as the bootstrap)"
  elif grep -q 'STARTUP_AI' "$doc"; then
    pass "$doc references STARTUP_AI (R2)"
  else
    fail "$doc does not reference STARTUP_AI (R2: entry docs must route to the capsule)"
  fi
done

# R3 — START_HERE must defer, not compete
if [ -f ai_context/START_HERE.md ]; then
  if grep -qE '^#{1,6}[[:space:]].*[Bb]oot[[:space:]][Ss]equence' ai_context/START_HERE.md; then
    if grep -qi 'not a competing boot sequence' ai_context/START_HERE.md; then
      pass "START_HERE.md Boot Sequence section defers to STARTUP_AI (R3)"
    else
      warn "START_HERE.md presents a competing Boot Sequence without the STARTUP_AI deferral (R3)"
    fi
  else
    pass "START_HERE.md has no competing Boot Sequence heading (R3)"
  fi
fi

# W1 — the git-native wrap gate (the tool-agnostic WRITE-edge floor)
if [ ! -f lefthook.yml ]; then
  fail "lefthook.yml missing (W1: the git-native wrap-continuity gate is the WRITE-edge floor)"
elif grep -q 'wrap-continuity' lefthook.yml; then
  pass "lefthook.yml carries the wrap-continuity arm (W1)"
else
  fail "lefthook.yml lacks the wrap-continuity arm (W1: add wrap-continuity to the drift-sweep --fail-on set)"
fi

# W3 — Claude SessionStart gate pair (optional UX layer on the W1 floor)
if [ -f .claude/settings.json ] && grep -q 'handoff-gate.sh' .claude/settings.json && grep -q 'wrap-gate.sh' .claude/settings.json; then
  pass ".claude SessionStart gate pair present (W3)"
else
  warn ".claude SessionStart gate pair absent (W3 — optional Claude UX; W1 is the floor)"
fi

# ── Hygiene ───────────────────────────────────────────────────
section "Hygiene"
[ -f .gitignore ] && pass ".gitignore" || fail ".gitignore (missing)"
if found=$(resolve_file AI_HANDOFF.{{AI}}ai); then pass "$found"; else warn "AI_HANDOFF.{{AI}}ai (missing — OK for very new repos)"; fi
if found=$(resolve_file WORKSHEET.hey{{HUMAN}}); then pass "$found"; else warn "WORKSHEET.hey{{HUMAN}} (missing)"; fi
if found=$(resolve_file SIDEQUESTS.{{AI}}ai); then pass "$found"; else warn "SIDEQUESTS.{{AI}}ai (missing)"; fi

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

  # MENTION vs USE (2026-08-16). Matching a placeholder anywhere cannot tell an
  # unfilled slot from prose that DESCRIBES the placeholder mechanism — and a
  # repo built on this substrate WILL write that prose, in its journals, its
  # ADRs and its handoffs. A gate whose one standing failure is known-bogus is a
  # gate people learn to scroll past.
  #
  # The discriminator is the definition of the check, not a guess about
  # sentence shape. This asks ONE question: "did init-project.sh finish?" That
  # is only answerable about files init ever touched, i.e. files the TEMPLATE
  # ships. A file with no counterpart in the template was authored by this
  # project; init never saw it, so it cannot hold an unfilled placeholder.
  #
  # DEGRADES TOWARD OVER-DETECTION, NEVER UNDER. If the template is not
  # reachable — the normal case for a repo seeded elsewhere — every hit stays a
  # failure, exactly as before. A missing oracle must not quietly switch a gate
  # off. Set TEMPLATE_REPO_PATH to point at your copy of the template if you
  # keep one and want the distinction.
  tmpl=""
  _top=$(git rev-parse --show-toplevel 2>/dev/null)
  for cand in "${TEMPLATE_REPO_PATH:-}" "${_top:+${_top}/../templateRepo_EXAMPLE}"; do
    [ -n "$cand" ] && [ -d "$cand" ] && { tmpl="$cand"; break; }
  done

  inherited=""; authored=""
  if [ -n "$leftover" ]; then
    while IFS= read -r lf; do
      [ -n "$lf" ] || continue
      if [ -z "$tmpl" ]; then
        inherited="${inherited}${lf}"$'\n'
        continue
      fi
      # Path mapping: this repo's foo.<ai>ai is the template's placeholder-named
      # counterpart. The LEFT side is written plainly so init substitutes it to
      # this project's real extension; the RIGHT side uses the escaped tokens so
      # it keeps naming the template's unfilled form. Both suffixes go through
      # variables first — `${lf%.{{AI}}ai}` inline mis-parses, because bash
      # closes the `${...}` at the first `}` inside the token (the same trap
      # init-project.sh documents at its own rename loop).
      ai_suffix='.{{AI}}ai'
      human_suffix='.hey{{HUMAN}}'
      case "$lf" in
        *"$ai_suffix")    alt="${lf%$ai_suffix}.${_PH_AI}ai" ;;
        *"$human_suffix") alt="${lf%$human_suffix}.hey${_PH_HUMAN}" ;;
        *)                alt="$lf" ;;
      esac
      if [ -f "$tmpl/$lf" ] || [ -f "$tmpl/$alt" ]; then
        inherited="${inherited}${lf}"$'\n'
      else
        authored="${authored}${lf}"$'\n'
      fi
    done <<< "$leftover"
  fi

  if [ -n "$inherited" ]; then
    count=$(printf '%s' "$inherited" | grep -c . || true)
    fail "$count file(s) inherited from the template still contain unfilled placeholders:"
    printf '%s' "$inherited" | head -10 | sed 's/^/      /'
    [ "$count" -gt 10 ] && echo "      ... and $((count - 10)) more"
    [ -z "$tmpl" ] && echo "      (template not reachable — every hit is reported, mention or use)"
  else
    pass "No leftover placeholders in template-inherited files"
  fi
  if [ -n "$authored" ]; then
    acount=$(printf '%s' "$authored" | grep -c . || true)
    pass "$acount project-authored file(s) mention placeholder syntax (prose about the mechanism, not an unfilled slot)"
    printf '%s' "$authored" | head -5 | sed 's/^/      /'
  fi
fi

# ── Freshness ─────────────────────────────────────────────────
section "Freshness"
ninety_days_ago=$(date -v-90d +%s 2>/dev/null || date -d "90 days ago" +%s)

for f in ai_context/current_state.md AI_HANDOFF.{{AI}}ai readme_AI.{{AI}}ai; do
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
if [ -f AI_HANDOFF.{{AI}}ai ]; then
  size=$(wc -c < AI_HANDOFF.{{AI}}ai)
  if [ "$size" -gt 204800 ]; then
    warn "AI_HANDOFF.{{AI}}ai is $((size / 1024)) KB — consider rotating older entries to an archive (threshold 200 KB)"
  else
    pass "AI_HANDOFF.{{AI}}ai size OK"
  fi
fi
if [ -f ai_context/current_state.md ]; then
  size=$(wc -c < ai_context/current_state.md)
  if [ "$size" -gt 51200 ]; then
    warn "ai_context/current_state.md is $((size / 1024)) KB — consider rotating older deltas to readme_AI_archive.{{AI}}ai (threshold 50 KB)"
  else
    pass "ai_context/current_state.md size OK"
  fi
fi

# ── WISL waystone structure ───────────────────────────────────
# Structural well-formedness per .repo-manager/standards/WISL/waystone.schema
# §Well-formedness checks 1,2,5,6: required fields (incl boot_path) + known
# wisl_version (1); folder == own directory; owns non-empty + repo-relative;
# actors ≥1 with perms ∈ {read,write,none}. Check 3 (verified_at resolves) and
# the owns↔HEAD freshness binding are drift-sweep's job, not duplicated here.
# Additive + graceful: a repo with no waystones passes. Reuses the schema's
# reference bash extractors (owns/actors) so the parse stays gate-consistent.
section "WISL waystone structure"
waystones=$(find . -name '_waystone.{{AI}}ai' -not -path '*/.git/*' 2>/dev/null | sed 's|^\./||')
if [ -z "$waystones" ]; then
  pass "No waystones present (WISL not adopted here — skipping)"
else
  REQUIRED_FIELDS="wisl_version folder orient owns depends_on verified_at actors boot_path"
  while IFS= read -r wf; do
    [ -z "$wf" ] && continue
    wdir=$(dirname "$wf"); wdir="${wdir#./}"
    wok=1
    # (1) required fields present
    for key in $REQUIRED_FIELDS; do
      grep -qE "^${key}:" "$wf" || { fail "$wf: missing required field '$key'"; wok=0; }
    done
    # (1) wisl_version known (major 1)
    wv=$(grep -E '^wisl_version:' "$wf" | head -1 | grep -oE '[0-9]+' | head -1)
    if [ -n "$wv" ] && [ "$wv" != "1" ]; then
      fail "$wf: unknown wisl_version '$wv' (tool supports 1)"; wok=0
    fi
    # (2) folder == own directory (repo-relative)
    fdecl=$(grep -E '^folder:' "$wf" | head -1 | sed -E 's/^folder:[[:space:]]*//; s/^"?([^"]*)"?[[:space:]]*$/\1/')
    if [ -n "$fdecl" ] && [ "$fdecl" != "$wdir" ]; then
      fail "$wf: folder '$fdecl' != actual location '$wdir'"; wok=0
    fi
    # (5) owns non-empty + repo-relative (schema awk extractor)
    owns=$(awk '/^owns:/{f=1;next} f&&/^[[:space:]]+-[[:space:]]/{sub(/^[[:space:]]+-[[:space:]]/,"");print;next} f&&/^[^[:space:]]/{f=0}' "$wf")
    if [ -z "$owns" ]; then
      fail "$wf: owns is empty (need ≥1 glob)"; wok=0
    elif echo "$owns" | grep -qE '^/'; then
      fail "$wf: owns has a non-repo-relative glob (leading /)"; wok=0
    fi
    # (6) actors ≥1 + perms ∈ {read,write,none}
    actors=$(awk '/^actors:/{f=1;next} f&&/^[[:space:]]+[A-Za-z0-9_-]+:[[:space:]]*/{print;next} f&&/^[^[:space:]]/{f=0}' "$wf")
    if [ -z "$actors" ]; then
      fail "$wf: actors map empty (need ≥1)"; wok=0
    else
      bad=$(echo "$actors" | grep -vE ':[[:space:]]*(read|write|none)([[:space:]]|#|$)' || true)
      if [ -n "$bad" ]; then
        fail "$wf: actor perm(s) not in {read,write,none}: $(echo "$bad" | sed 's/^[[:space:]]*//' | tr '\n' '|')"; wok=0
      fi
    fi
    [ "$wok" -eq 1 ] && pass "$wf: structure OK (fields, folder, owns, actors)"
  done <<WAYSTONE_LIST
$waystones
WAYSTONE_LIST
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
