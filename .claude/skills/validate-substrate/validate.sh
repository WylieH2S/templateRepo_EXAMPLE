#!/usr/bin/env bash
# validate-substrate — check a repo for two-tier substrate compliance
# + Agent Boot Contract conformance (ADR-BOOT-001: the tool-agnostic boot floor).
#
# Usage: bash validate.sh [<repo-path>]   (default: current dir)
#        bash validate.sh --fleet [<workspace-path>]   (iterate every child repo)
#
# Exit codes:
#   0 = no failures (warnings allowed)
#   1 = one or more FAIL checks
#   2 = usage error (unreadable path, or a container pointed at by mistake)

set -uo pipefail

SELF="${BASH_SOURCE[0]}"

# ── Fleet mode ────────────────────────────────────────────────
# Explicit opt-in to iterate a workspace root, validating each child repo in its
# OWN root — the only context where that repo's card paths mean anything.
if [ "${1:-}" = "--fleet" ]; then
  shift
  cd "${1:-.}" || { echo "Cannot enter ${1:-.}" >&2; exit 2; }
  _fleet_rc=0
  _fleet_n=0
  for _d in */; do
    _r="${_d%/}"
    [ -d "$_r/.git" ] || continue
    echo "════════ $_r ════════"
    VALIDATE_FLEET_CHILD=1 bash "$SELF" "$_r" || _fleet_rc=1
    _fleet_n=$((_fleet_n + 1))
    echo
  done
  # A FLEET PASS THAT VALIDATED NOTHING MUST NOT EXIT 0 — same silent pass fixed in
  # drift-sweep v0.1.36, found the same way. Aimed at ~/repoManager (whose only
  # children are dotdirs) this loop never ran, printed nothing, and exited 0. Clean
  # and never-ran were indistinguishable.
  if [ "$_fleet_n" -eq 0 ]; then
    echo "FAIL: --fleet validated 0 repos from $(pwd -P)" >&2
    echo "  No child directory here contains a .git. The fleet root is the workspace" >&2
    echo "  parent (~/GitHub), not the control-plane repo — run it from there, or pass" >&2
    echo "  the root explicitly: validate.sh --fleet <fleet-root>" >&2
    exit 2
  fi
  exit "$_fleet_rc"
fi

REPO="${1:-.}"
cd "$REPO" || { echo "Cannot enter $REPO"; exit 2; }

# ── Container guard ───────────────────────────────────────────
# This is a PER-REPO tool. Aimed at a directory that is not itself a git repo but
# CONTAINS git repos (the ~/GitHub workspace root being the live example), it
# descends into every child repo and reads their repo-RELATIVE `folder:` fields
# as though they were relative to the container. Every card then reports
# `folder 'src/x' != actual location '<repo>/src/x'` — a large pile of failures
# that describe nothing real, and which invite a "fix" that would corrupt every
# card in the fleet. Refuse rather than emit a confident wrong answer.
#
# Discriminator: not a git repo, yet holding git children. A genuine standalone
# non-git folder has no git children and still validates normally. A repo with
# submodules has its own .git, so this never fires there.
if [ ! -d .git ] && [ "${VALIDATE_FLEET_CHILD:-0}" != "1" ]; then
  _child_repos=0
  for _d in */; do
    [ -d "${_d}.git" ] && _child_repos=$((_child_repos + 1))
  done
  if [ "$_child_repos" -ge 2 ]; then
    echo "REFUSING: $(pwd)" >&2
    echo "  is not a git repo, but contains $_child_repos git repos." >&2
    echo "  validate-substrate is a PER-REPO tool: run it inside a repo," >&2
    echo "  or use '--fleet' to iterate each child repo in its own root." >&2
    echo "  (Results from here would be path-confusion artifacts, not drift.)" >&2
    exit 2
  fi
fi

FAILS=0
WARNS=0

pass() { echo "  ✓ $*"; }
warn() { echo "  ⚠ $*"; WARNS=$((WARNS+1)); }
fail() { echo "  ✗ $*"; FAILS=$((FAILS+1)); }

section() { echo; echo "── $* ──"; }

# ── Carrier extensions, RESOLVED not hardcoded (2026-08-16) ───
# Identical mechanism and identical reasoning to drift-sweep's — see the long
# note at its resolver for the two live defects the old hardcoding produced.
# In short: detect the AI/human carrier suffixes from the repo's own root
# waystone card (present in 12/12 fleet repos), so `chloeai`/`heywy` and
# `{{AI}}ai`/`hey{{HUMAN}}` are the SAME code path rather than two.
#
# This is what retires the template's declared FORK of this skill. The fork
# existed because "the canonical cannot do that" — genericize the canonical and
# the reason evaporates.
#
# NO SILENT DEFAULT: an unresolved suffix makes every substrate path end in a
# bare `.`, every file reads as missing, and the run becomes a wall of FAILs
# describing nothing. Loud refusal beats a confident wrong answer — the same
# principle as the container guard above.
if [ -z "${AI_EXT:-}" ] || [ -z "${HUMAN_EXT:-}" ]; then
  # ORDERED ANCHORS, and the order is load-bearing. `_waystone` is unambiguous
  # and comes first — but init-project.sh DELETES both root cards when it seeds a
  # project ("new repos start with NO waystones by design"), so a fresh repo has
  # none. Anchoring on the card alone would have made every newly-seeded repo
  # refuse on its own pre-commit hook. The rest of the list is Tier-1 substrate
  # that init RENAMES rather than removes, so it always survives.
  for _stem in _waystone STARTUP_AI readme_AI AI_HANDOFF SIDEQUESTS WORKSHEET; do
    for _f in "$_stem".*; do
      # -e OR -L: the human doorway is a symlink, and -e is FALSE for a dangling
      # one — so a broken doorway made HUMAN_EXT undetectable and the doorway
      # check reported MISSING when the truth was DANGLES.
      { [ -e "$_f" ] || [ -L "$_f" ]; } || continue   # unmatched glob = literal pattern
      _sfx="${_f#"$_stem".}"
      case "$_sfx" in
        # Generic suffixes are never a carrier. Without this a stray
        # `readme_AI.md` or an editor's `.bak` would be adopted as THE extension
        # and every subsequent path would be built on it.
        md|txt|json|yml|yaml|toml|bak|orig|swp|tmp|lock) ;;
        hey*) [ -z "${HUMAN_EXT:-}" ] && HUMAN_EXT="$_sfx" ;;
        *)    [ -z "${AI_EXT:-}" ]    && AI_EXT="$_sfx" ;;
      esac
    done
  done
fi
AI_EXT="${AI_EXT:-}"
# NOT defaulted to `heywy`. A fallback here would smuggle back the exact hardcode
# this change removes, and it would be invisible: a repo whose human carrier is
# named anything else would quietly validate against Wy's name instead of its own.
HUMAN_EXT="${HUMAN_EXT:-}"
HUMAN_EXT_DISPLAY="${HUMAN_EXT:-hey<human>}"
if [ -z "$AI_EXT" ]; then
  echo "REFUSING: $(pwd)" >&2
  echo "  has no ./_waystone.<ext> root card, so the AI carrier extension cannot" >&2
  echo "  be resolved. Every substrate path would end in a bare '.', every file" >&2
  echo "  would read as missing, and the result would describe nothing real." >&2
  echo "  Fix: author the root card, or preset AI_EXT=<ext> for a deliberate probe." >&2
  exit 2
fi

# Template mode: we're validating the template ITSELF, not a bootstrapped
# project. Several checks are softened here because placeholder tokens and
# unresolved EXTENDS paths are the correct state for a blueprint.
#
# TWO CONDITIONS, not one (tightened 2026-08-16). This used to test only
# `-f init-project.sh`, and init-project.sh's self-delete is a PROMPT that
# DEFAULTS TO NO. So a real seeded repo whose owner pressed Enter kept the
# script and was silently validated in template mode — with the leftover-
# placeholder check, the EXTENDS check and resolve_file() all softened, on the
# one repo where an unfilled placeholder is an actual defect.
#
# The second condition now reads the resolved carrier: AI_EXT is `{{AI}}ai`
# exactly when unsubstituted substrate is on disk, which is the property no
# seeded repo can have (init renames every such file unconditionally, no prompt).
TEMPLATE_MODE=0
if [ -f init-project.sh ] && [ "$AI_EXT" = '{{AI}}ai' ]; then
  TEMPLATE_MODE=1
fi

echo "Validating substrate in: $(pwd)"
echo "(carrier: .${AI_EXT} / .${HUMAN_EXT_DISPLAY})"
[ "$TEMPLATE_MODE" -eq 1 ] && echo "(template mode — init-project.sh present AND substrate still placeholder-named)"

# Kept as a function so ~20 call sites keep reading the same way, but the
# template-mode alternate-name branch is GONE: there is only one name now, and
# it is the resolved one. That branch was the fork's whole reason to exist.
resolve_file() {
  if [ -f "$1" ]; then printf '%s' "$1"; return 0; fi
  return 1
}

# ── Tier 1 required files ─────────────────────────────────────
section "Tier 1 required files"
for f in CLAUDE.md "STARTUP_AI.${AI_EXT}" "readme_AI.${AI_EXT}" "ai_context/ai_rules.${AI_EXT}" "ai_context/glossary.${AI_EXT}" ai_context/START_HERE.md; do
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
  if HI_MODE_FILE=$(resolve_file "ai_modules/hi_mode.${AI_EXT}"); then
    pass "$HI_MODE_FILE"
  else
    fail "ai_modules/hi_mode.${AI_EXT} (missing — HI Mode shim required)"
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
    warn "hi_mode.${AI_EXT} has no EXTENDS line"
  fi
fi

# ── Path-scoped rules ─────────────────────────────────────────
section "Path-scoped rules (.claude/rules/)"
for f in "code.${AI_EXT}" "tests.${AI_EXT}" "ai-context.${AI_EXT}" "docs.${AI_EXT}"; do
  path=".claude/rules/$f"
  if found=$(resolve_file "$path"); then
    pass "$found"
  else
    warn "$path (missing — OK if not referenced from CLAUDE.md)"
  fi
done

# ── Agent Boot Contract (ADR-BOOT-001) ────────────────────────
# Conformance per .repo-manager/standards/boot-contract/BOOT-CONTRACT.chloeai.
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

# Retired-capsule mode. A repo may retire STARTUP_AI.chloeai by logged decision
# and move the boot contract into the entry docs + ai_context/START_HERE.md
# (Task-Force-Nerd-LLC DEC-003 is the live case). R2/R3 otherwise assume the
# capsule is authoritative and mis-report such a repo: R3 warns that START_HERE
# "competes" when START_HERE is in fact the authority, and following that warning
# would revive a retired boot entry and revert an Active DEC.
#
# The signal is an explicit opt-in declaration the repo must WRITE — never a
# heuristic — so a merely-stale capsule still gets caught.
CAPSULE_RETIRED=0
if [ -f "STARTUP_AI.${AI_EXT}" ] && grep -qE '^STATUS:[[:space:]]*RETIRED' "STARTUP_AI.${AI_EXT}"; then
  CAPSULE_RETIRED=1
fi

if [ "$CAPSULE_RETIRED" -eq 1 ]; then
  pass "STARTUP_AI.${AI_EXT} declares STATUS: RETIRED — evaluating R2/R3 in retired-capsule mode"

  # R2 (retired) — the entry docs ARE the boot contract, and must say the capsule
  # is dead. A bare 'STARTUP_AI' mention is NOT enough: the plain check passes on
  # any incidental reference, including a retirement note, so it can be right for
  # the wrong reason and would break if that sentence were ever reworded.
  for doc in CLAUDE.md AGENTS.md; do
    if [ ! -f "$doc" ]; then
      fail "$doc missing (R2: with the capsule retired, the entry docs ARE the boot contract)"
    elif grep -qiE 'no longer the boot|retired|superseded' "$doc"; then
      pass "$doc records the capsule retirement (R2, retired-capsule mode)"
    else
      warn "$doc does not record that STARTUP_AI is retired (R2: a reader cannot tell which boot path is live)"
    fi
  done

  # R3 (retired) — START_HERE is the authority here, so a Boot Sequence heading
  # is correct rather than competing. What matters is that the capsule itself
  # cannot be mistaken for live; that is checked above by STATUS: RETIRED.
  if [ -f ai_context/START_HERE.md ]; then
    if grep -qE '^#{1,6}[[:space:]].*[Bb]oot[[:space:]][Ss]equence' ai_context/START_HERE.md; then
      pass "START_HERE.md carries the live Boot Sequence (R3, retired-capsule mode — expected)"
    else
      warn "START_HERE.md has no Boot Sequence heading, and the capsule is retired (R3: no live boot order anywhere)"
    fi
  fi
else
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
if found=$(resolve_file "AI_HANDOFF.${AI_EXT}"); then pass "$found"; else warn "AI_HANDOFF.${AI_EXT} (missing — OK for very new repos)"; fi
if [ -n "$HUMAN_EXT" ] && found=$(resolve_file "WORKSHEET.${HUMAN_EXT}"); then pass "$found"; else warn "WORKSHEET.${HUMAN_EXT_DISPLAY} (missing)"; fi
if found=$(resolve_file "SIDEQUESTS.${AI_EXT}"); then pass "$found"; else warn "SIDEQUESTS.${AI_EXT} (missing)"; fi

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
  #
  # PATHS INIT NEVER SUBSTITUTES ARE EXCLUDED STRUCTURALLY (2026-08-16). This
  # check asks "did init-project.sh finish?", so it must only look where init
  # ACTS. init's own find carries an exclusion list — stacks/, workspace/,
  # init-project.sh itself, and (since the tooling stopped being substituted)
  # .claude/skills/ and .claude/hooks/. A `{{TOKEN}}` in any of those is not an
  # unfilled slot; it is either a stack pack awaiting a future init, or a
  # substitution RULE stated by the tool that performs it.
  #
  # This is the mention-vs-use distinction for the THIRD time in this fleet, and
  # the third form it has taken: prose describing a placeholder (planTheBeast's
  # upsync hint), a doc quoting a stale version string (drift-sweep doc-version),
  # and now a script that names the token it substitutes. The oracle lookup below
  # approximates the answer by asking whether the template ships the file; this
  # list IS the answer for these paths, so it runs first and needs no oracle —
  # which matters most for someone who cloned the template alone and has no
  # template to look up.
  # FILE TYPES ARE MIRRORED TOO, for the same reason as the paths. init
  # substitutes exactly four shapes — *.md, *.sh, *.<ai-ext>, *.hey<human> — so a
  # placeholder in any other file type was never going to be filled and its
  # presence says nothing about whether init finished. `.claude/drift-sweep.conf`
  # is the live example: a comment there explains the {{AI}}/{{HUMAN}}/{{TOKEN}}
  # convention, and it was the last surviving false positive after the path
  # exclusions. Rewording that comment to appease the gate was the obvious fix
  # and the wrong one — editing content to silence a check is how a check stops
  # describing reality. Fix the check.
  #
  # AI_EXT is a plain alphanumeric suffix wherever this runs: TEMPLATE_MODE skips
  # this whole block, so the placeholder-named case never reaches here and the
  # extensions need no regex escaping.
  leftover=$(git ls-files 2>/dev/null \
    | grep -vE '^(stacks/|workspace/|init-project\.sh$|\.claude/skills/|\.claude/hooks/)' \
    | grep -E "\.(md|sh|${AI_EXT}|${HUMAN_EXT:-hey_none})$" \
    | xargs grep -lE '\{\{[A-Z_]+\}\}' 2>/dev/null || true)

  # MENTION vs USE (2026-08-16). Matching `{{TOKEN}}` anywhere cannot tell an
  # unfilled slot from prose that DESCRIBES the placeholder mechanism, and this
  # fleet writes a lot of the latter: planTheBeast's ai_context/upsync.chloeai
  # was the fleet's only validate-substrate failure for weeks purely because a
  # hint entry explains what {{AI}} is. A gate whose one standing failure is
  # known-bogus is a gate people learn to scroll past.
  #
  # The discriminator is not a heuristic about sentence shape — it is the
  # definition of the thing being checked. This check asks ONE question: "did
  # init-project.sh finish?" That question is only answerable about files init
  # ever touched, i.e. files the TEMPLATE ships. A file with no counterpart in
  # templateRepo_EXAMPLE was authored by this project; init never saw it, so it
  # cannot be carrying an unfilled placeholder. Same oracle-by-lookup shape as
  # drift-sweep's hook-canonical / skill-canonical categories.
  #
  # Path mapping is resolve_file() run backwards: the template holds
  # ai_context/foo.{{AI}}ai where a seeded repo holds ai_context/foo.chloeai.
  #
  # DEGRADES TOWARD OVER-DETECTION, NEVER UNDER. No reachable template (repo
  # cloned outside the fleet, single-repo CI checkout) means every hit stays a
  # failure, exactly as before. A missing oracle must not quietly turn a gate
  # off — that is how the CI backstop failed 15 times unseen.
  tmpl=""
  _top=$(git rev-parse --show-toplevel 2>/dev/null)
  for cand in "${_top:+${_top}/../templateRepo_EXAMPLE}" "${HOME}/GitHub/templateRepo_EXAMPLE"; do
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
      case "$lf" in
        *".${AI_EXT}")    alt="${lf%".${AI_EXT}"}.{{AI}}ai" ;;
        *".${HUMAN_EXT}") alt="${lf%".${HUMAN_EXT}"}.hey{{HUMAN}}" ;;
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
    fail "$count file(s) inherited from the template still contain unfilled {{TOKEN}} placeholders:"
    printf '%s' "$inherited" | head -10 | sed 's/^/      /'
    [ "$count" -gt 10 ] && echo "      ... and $((count - 10)) more"
    [ -z "$tmpl" ] && echo "      (templateRepo_EXAMPLE not reachable — every hit is reported, mention or use)"
  else
    pass "No leftover {{TOKEN}} placeholders in template-inherited files"
  fi
  if [ -n "$authored" ]; then
    acount=$(printf '%s' "$authored" | grep -c . || true)
    pass "$acount project-authored file(s) mention {{TOKEN}} syntax (prose about the mechanism, not an unfilled slot)"
    printf '%s' "$authored" | head -5 | sed 's/^/      /'
  fi
fi

# ── Freshness ─────────────────────────────────────────────────
section "Freshness"
ninety_days_ago=$(date -v-90d +%s 2>/dev/null || date -d "90 days ago" +%s)

for f in ai_context/current_state.md "AI_HANDOFF.${AI_EXT}" "readme_AI.${AI_EXT}"; do
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
if [ -f "AI_HANDOFF.${AI_EXT}" ]; then
  size=$(wc -c < "AI_HANDOFF.${AI_EXT}")
  if [ "$size" -gt 204800 ]; then
    warn "AI_HANDOFF.${AI_EXT} is $((size / 1024)) KB — consider rotating older entries to an archive (threshold 200 KB)"
  else
    pass "AI_HANDOFF.${AI_EXT} size OK"
  fi
fi
if [ -f ai_context/current_state.md ]; then
  size=$(wc -c < ai_context/current_state.md)
  if [ "$size" -gt 51200 ]; then
    warn "ai_context/current_state.md is $((size / 1024)) KB — consider rotating older deltas to readme_AI_archive.${AI_EXT} (threshold 50 KB)"
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
waystones=$(find . -name "_waystone.${AI_EXT}" -not -path '*/.git/*' 2>/dev/null | sed 's|^\./||')
if [ -z "$waystones" ]; then
  pass "No waystones present (WISL not adopted here — skipping)"
else
  REQUIRED_FIELDS="wisl_version folder orient owns depends_on actors boot_path"
  while IFS= read -r wf; do
    [ -z "$wf" ] && continue
    wdir=$(dirname "$wf"); wdir="${wdir#./}"
    wok=1
    # (1) required fields present
    for key in $REQUIRED_FIELDS; do
      grep -qE "^${key}:" "$wf" || { fail "$wf: missing required field '$key'"; wok=0; }
    done
    # The human reconciliation stamp, required as EITHER name (drift-sweep v0.1.13
    # split verified_at; `reviewed_at` is the preferred name and `verified_at` its
    # permanently-supported predecessor). Checked as a pair rather than listed in
    # REQUIRED_FIELDS above, because listing one would fail every card that adopted
    # the other — the two skills disagreeing about a required field is precisely the
    # split brain this fleet keeps paying for. NOTE `validated_at` is NOT accepted
    # here: it is the machine stamp and satisfies nothing a human owes this card.
    if ! grep -qE '^(reviewed_at|verified_at):' "$wf"; then
      fail "$wf: missing required field 'reviewed_at' (or its predecessor 'verified_at')"; wok=0
    fi
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
    # (8) heywy — the human inscription (WISL-STANDARD v1.5 §Human inscription).
    # ADVISORY BY DESIGN: absent is valid everywhere, so this only WARNs, and only on a
    # repo-ROOT card (folder '.') where the doorway lands. Observability before
    # enforcement — teeth only once there is evidence the blocks stay current.
    if [ "$wdir" = "." ] || [ "$wdir" = "" ]; then
      # `heywy:` here is the card's fixed INSCRIPTION KEY, not a carrier
      # suffix. init never rewrites it — templateRepo's own card says `heywy:`.
      # Do NOT parameterise these four lines; conflating the key with the
      # filename suffix is precisely what killed drift-sweep's doorway check
      # inside the template (see the v0.1.29 note in sweep.sh).
      if grep -qE '^heywy:' "$wf"; then
        # Sub-keys must be known; an unknown one is silently dropped by the renderer,
        # so surfacing it here is the only way an author finds out.
        hk=$(awk '/^heywy:/{f=1;next} f&&/^[[:space:]]+[a-z]+:/{sub(/^[[:space:]]+/,"");sub(/:.*$/,"");print;next} f&&/^[^[:space:]]/{f=0}' "$wf")
        for key in $hk; do
          case "$key" in
            what|state|run|check|next) ;;
            *) warn "$wf: unknown heywy sub-key '$key' (renderer drops it)" ;;
          esac
        done
      else
        warn "$wf: repo-root card has no 'heywy:' inscription (readout falls back to orient/continuity)"
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
