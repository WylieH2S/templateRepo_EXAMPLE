#!/usr/bin/env bash
# drift-sweep v0.1.9 — detect code/substrate drift in a repo.
#
# v0.1.9: NEW wrap-continuity category — the Agent Boot Contract W1 WRITE edge
# (ADR-BOOT-001). The session-wrap gate moves to git-native ground: the carrier
# (readme_AI.{{AI}}ai in-repo / the workspace HANDOFF log in the substrate repo)
# must not lag HEAD by more than WRAP_LAG_WARN commits (default 10), and a commit
# that stages the carrier passes as the wrap itself. soft_fail: WARN by default,
# gate via --fail-on=wrap-continuity. Graceful where no carrier exists, so the
# symlinked fleet rollout is advisory-only until a repo arms it. Closes the
# Codex/any-agent wrap gap (OFS SL-001/THR-004): .claude SessionStart gates fire
# only for Claude sessions; every agent commits through git.
#
# v0.1.8: up-sync AND waystone-freshness gates are now STAGED-AWARE, closing the
# same one-commit lag in both. (1) up-sync: inspects the staged index at commit
# time, not just committed history, so an unaccompanied readme_AI move is caught at
# its creating commit and the parity-restoring commit is no longer blocked.
# (2) waystone-freshness: REFRAMED from a verified_at SHA-range diff to commit-time
# RECENCY (the waystone must be touched as recently as the files it owns). The
# SHA-range approach lagged because verified_at cannot point to the in-flight commit,
# so it always flagged the commit AFTER an owned-file change, forcing a no-op
# re-stamp; recency + staged-awareness removes that tail. verified_at is retained
# for the dangling-sha check + as the documented last-reconciliation marker. Both
# gates fall through to committed-date/recency comparison on a clean checkout (CI),
# so determinism there is unchanged. See WISL-STANDARD §Enforcement + the schema's
# verified_at field note.
#
# Usage: bash sweep.sh [flags] [<repo-path>]   (default: current dir)
#
# Flags:
#   --quiet                  Suppress PASS lines; show only WARN and FAIL.
#   --json                   Emit JSON to stdout instead of human-readable output.
#   --fail-on=<categories>   Comma-separated list of categories that count toward
#                            the exit code. All categories still run and report.
#                            If omitted, all failures count. Categories:
#                              working-tree, untracked-docs, cruft, file-journals,
#                              orphans, mission-freshness, claude-md, waystone-freshness,
#                              up-sync, wrap-continuity, wisl-graph, seam-coverage
#
# wrap-continuity, wisl-graph + seam-coverage are ADVISORY (soft_fail): WARN by
# default, hard FAIL only when explicitly named in --fail-on (the "advisory-first,
# then arm" rollout). All graceful-pass where their inputs are absent (no carrier /
# no waystones / no seam map).
#
# Companion to validate-substrate. validate-substrate checks STRUCTURAL substrate
# compliance (Tier 1 files exist, size thresholds, tracked junk). drift-sweep
# checks CODE/SUBSTRATE CONSISTENCY (orphaned exports, journal-in-code, stale
# CURRENT_MISSION vs code, uncommitted iteration accumulation).
#
# Configuration (optional, sourced from .claude/drift-sweep.conf):
#   CODE_ROOTS                — space-separated list of source dirs (default: "src lib")
#   EXCLUDE_FILES             — regex of files to exclude (e.g. "bf6_briefcase\.ts$")
#   DIFF_FAIL_THRESHOLD       — uncommitted insertions+deletions FAIL threshold (default 1000)
#   DIRTY_FILES_WARN          — dirty file count WARN threshold (default 10)
#   JOURNAL_DIFF_LINES_FAIL   — version-bump lines added in a single file's diff (default 3)
#   JOURNAL_HEADER_SCAN       — how many leading lines of each file to scan (default 80)
#   JOURNAL_HEADER_FAIL       — version-bump lines in file header FAIL threshold (default 5)
#   MISSION_STALE_DAYS        — code-newer-than-mission FAIL threshold in days (default 14)
#   ORPHAN_EXPORT_ALLOWLIST   — regex of export names to skip (default "^$")
#   SOURCE_EXTENSIONS         — file extensions to treat as source (default "ts tsx js py rs go swift")
#   TIER1_FILES               — space-separated always-loaded substrate files to size-check
#   TIER1_BLOAT_WARN_KB       — always-loaded file size WARN threshold in KB (default 25)
#   WRAP_CARRIER              — wrap-continuity carrier override (default: auto-detect
#                               readme_AI.{{AI}}ai, else the workspace HANDOFF log)
#   WRAP_LAG_WARN             — commits the carrier may lag HEAD before wrap-continuity
#                               flags (default 10)
#
# The tier1-bloat category is ADVISORY (warn-only) — it never counts toward the
# exit code, so it cannot be gated via --fail-on. It enforces the ADR-004 paging
# discipline: always-loaded substrate stays lean; history pages out to archives.
#
# Exit codes:
#   0 = no failures (warnings allowed) [or no failures in --fail-on categories]
#   1 = one or more FAIL checks [in --fail-on categories]
#   2 = cannot enter repo

set -uo pipefail

# ── Arg parsing ───────────────────────────────────────────────
REPO="."
JSON_OUTPUT=0
QUIET_OUTPUT=0
FAIL_ON_CATEGORIES=""

while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON_OUTPUT=1; shift ;;
    --quiet) QUIET_OUTPUT=1; shift ;;
    --fail-on=*) FAIL_ON_CATEGORIES="${1#--fail-on=}"; shift ;;
    -*) echo "Unknown flag: $1" >&2; exit 1 ;;
    *) REPO="$1"; shift ;;
  esac
done

cd "$REPO" || { echo "Cannot enter $REPO" >&2; exit 2; }

# ── Defaults + optional config ────────────────────────────────
CONFIG=".claude/drift-sweep.conf"
[ -f "$CONFIG" ] && source "$CONFIG"

CODE_ROOTS="${CODE_ROOTS:-src lib}"
EXCLUDE_FILES="${EXCLUDE_FILES:-}"
DIFF_FAIL_THRESHOLD="${DIFF_FAIL_THRESHOLD:-1000}"
DIRTY_FILES_WARN="${DIRTY_FILES_WARN:-10}"
JOURNAL_DIFF_LINES_FAIL="${JOURNAL_DIFF_LINES_FAIL:-3}"
JOURNAL_HEADER_SCAN="${JOURNAL_HEADER_SCAN:-80}"
JOURNAL_HEADER_FAIL="${JOURNAL_HEADER_FAIL:-5}"
MISSION_STALE_DAYS="${MISSION_STALE_DAYS:-14}"
ORPHAN_EXPORT_ALLOWLIST="${ORPHAN_EXPORT_ALLOWLIST:-^$}"
SOURCE_EXTENSIONS="${SOURCE_EXTENSIONS:-ts tsx js py rs go swift}"
TIER1_FILES="${TIER1_FILES:-readme_AI.{{AI}}ai CLAUDE.md ai_context/ai_rules.{{AI}}ai ai_context/glossary.{{AI}}ai ai_context/CURRENT_MISSION.md ai_context/START_HERE.md}"
TIER1_BLOAT_WARN_KB="${TIER1_BLOAT_WARN_KB:-25}"
WRAP_CARRIER="${WRAP_CARRIER:-}"
WRAP_LAG_WARN="${WRAP_LAG_WARN:-10}"

FAILS=0
WARNS=0
EXIT_FAILS=0
CURRENT_CATEGORY=""
declare -a JSON_CHECKS
JSON_CHECKS=()

# Returns 0 (true) if failures in this category count toward the exit code.
should_fail_on() {
  [ -z "$FAIL_ON_CATEGORIES" ] && return 0
  echo "$FAIL_ON_CATEGORIES" | tr ',' '\n' | grep -qxF "$1"
}

pass() {
  if [ "$JSON_OUTPUT" -eq 1 ]; then
    local msg_esc; msg_esc=$(printf '%s' "$*" | sed 's/\\/\\\\/g; s/"/\\"/g')
    JSON_CHECKS+=("{\"category\":\"${CURRENT_CATEGORY}\",\"status\":\"pass\",\"message\":\"${msg_esc}\"}")
  elif [ "$QUIET_OUTPUT" -eq 0 ]; then
    echo "  ✓ $*"
  fi
}
warn() {
  WARNS=$((WARNS+1))
  if [ "$JSON_OUTPUT" -eq 1 ]; then
    local msg_esc; msg_esc=$(printf '%s' "$*" | sed 's/\\/\\\\/g; s/"/\\"/g')
    JSON_CHECKS+=("{\"category\":\"${CURRENT_CATEGORY}\",\"status\":\"warn\",\"message\":\"${msg_esc}\"}")
  else
    echo "  ⚠ $*"
  fi
}
fail() {
  FAILS=$((FAILS+1))
  should_fail_on "$CURRENT_CATEGORY" && EXIT_FAILS=$((EXIT_FAILS+1))
  if [ "$JSON_OUTPUT" -eq 1 ]; then
    local msg_esc; msg_esc=$(printf '%s' "$*" | sed 's/\\/\\\\/g; s/"/\\"/g')
    JSON_CHECKS+=("{\"category\":\"${CURRENT_CATEGORY}\",\"status\":\"fail\",\"message\":\"${msg_esc}\"}")
  else
    echo "  ✗ $*"
  fi
}
# soft_fail — WARN by default; hard FAIL only when this category is explicitly
# named in --fail-on. The asymmetry vs fail() (which counts when --fail-on is
# omitted) is deliberate: advisory categories like up-sync are opt-in-to-gate.
soft_fail() {
  if [ -n "$FAIL_ON_CATEGORIES" ] && should_fail_on "$CURRENT_CATEGORY"; then
    fail "$@"
  else
    warn "$@"
  fi
}
section() {
  if [ "$JSON_OUTPUT" -eq 0 ]; then
    echo
    echo "── $* ──"
  fi
}

if [ "$JSON_OUTPUT" -eq 0 ]; then
  echo "Drift-sweep in: $(pwd)"
  echo "  CODE_ROOTS: ${CODE_ROOTS}"
  [ -n "$EXCLUDE_FILES" ] && echo "  EXCLUDE_FILES: ${EXCLUDE_FILES}"
fi

# ── List source files helper ──────────────────────────────────
list_source_files() {
  for root in $CODE_ROOTS; do
    [ -d "$root" ] || continue
    for ext in $SOURCE_EXTENSIONS; do
      find "$root" -type f -name "*.${ext}" 2>/dev/null
    done
  done | { if [ -n "$EXCLUDE_FILES" ]; then grep -vE "$EXCLUDE_FILES"; else cat; fi; }
}

# ── 1. Working-tree health ────────────────────────────────────
CURRENT_CATEGORY="working-tree"
section "Working-tree health"
if [ -d .git ]; then
  shortstat=$(git diff --shortstat HEAD 2>/dev/null || true)
  insertions=0
  deletions=0
  if [ -n "$shortstat" ]; then
    insertions=$(echo "$shortstat" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || true)
    deletions=$(echo "$shortstat" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || true)
  fi
  total=$((insertions + deletions))
  dirty_count=$(git diff --name-only HEAD 2>/dev/null | wc -l | tr -d ' ')

  if [ "$total" -gt "$DIFF_FAIL_THRESHOLD" ]; then
    fail "uncommitted churn: ${total} lines across ${dirty_count} files (threshold ${DIFF_FAIL_THRESHOLD})"
  elif [ "$dirty_count" -gt "$DIRTY_FILES_WARN" ]; then
    warn "${dirty_count} files dirty in working tree (threshold ${DIRTY_FILES_WARN})"
  else
    pass "working tree healthy (${total} lines, ${dirty_count} files)"
  fi

  # Probe-journal accumulation in any single file's diff.
  journal_diff_hits=0
  while IFS= read -r f; do
    [ -z "$f" ] || [ ! -f "$f" ] && continue
    bump_count=$(git diff -- "$f" 2>/dev/null | grep -cE '^\+[[:space:]]*(//|#)[[:space:]]*v[0-9]+\.' || true)
    if [ "$bump_count" -gt "$JOURNAL_DIFF_LINES_FAIL" ]; then
      fail "probe-journal-in-diff: ${f} (+${bump_count} version-bump lines, threshold +${JOURNAL_DIFF_LINES_FAIL})"
      journal_diff_hits=$((journal_diff_hits+1))
    fi
  done < <(git diff --name-only HEAD 2>/dev/null)
  [ "$journal_diff_hits" -eq 0 ] && pass "no probe-journal accumulation in dirty diffs"
else
  warn "Not a git repo — skipping working-tree checks"
fi

# ── 2. Untracked important docs ───────────────────────────────
CURRENT_CATEGORY="untracked-docs"
section "Untracked important docs"
if [ -d .git ]; then
  untracked_important=$(git ls-files --others --exclude-standard 2>/dev/null \
    | grep -iE '(audit|findings|mission|handoff|decisions|charter|rules).*\.(md|[a-z0-9]*ai)$' \
    || true)
  if [ -n "$untracked_important" ]; then
    while IFS= read -r f; do
      [ -n "$f" ] && fail "untracked: ${f}"
    done <<< "$untracked_important"
  else
    pass "no untracked audit/mission/handoff/charter docs"
  fi
fi

# ── 3. Known-cruft directories + versioned backups ────────────
CURRENT_CATEGORY="cruft"
section "Known-cruft directories + versioned backups"
cruft_found=0
if [ -d .git ]; then
  cruft_files=$(git ls-files 2>/dev/null \
    | grep -E '/(old|testing|_backup[^/]*|_TEMP[^/]*)/[^/]*$' \
    || true)
  if [ -n "$cruft_files" ]; then
    cruft_dirs=$(echo "$cruft_files" | sed 's|/[^/]*$||' | sort -u)
    while IFS= read -r d; do
      [ -z "$d" ] && continue
      file_count=$(echo "$cruft_files" | grep -c "^${d}/" || true)
      warn "cruft dir: ${d}/ (${file_count} tracked files)"
      cruft_found=1
    done <<< "$cruft_dirs"
  fi

  vbak=$(git ls-files 2>/dev/null \
    | grep -E '_v[0-9]+(_[0-9]+)*\.(ts|tsx|js|py|rs|go|swift|md)$' \
    | grep -vE '(/tests?/|/spec/|/snapshots?/)' \
    || true)
  if [ -n "$vbak" ]; then
    while IFS= read -r f; do
      [ -n "$f" ] && warn "versioned-backup file: ${f}"
      cruft_found=1
    done <<< "$vbak"
  fi
fi
[ "$cruft_found" -eq 0 ] && pass "no obvious cruft directories or versioned backups"

# ── 4. File-header probe journals ─────────────────────────────
CURRENT_CATEGORY="file-journals"
section "File-header probe journals"
header_hits=0
while IFS= read -r f; do
  [ -z "$f" ] || [ ! -f "$f" ] && continue
  journal_count=$(head -"$JOURNAL_HEADER_SCAN" "$f" 2>/dev/null \
    | grep -cE '^[[:space:]]*(//|#)[[:space:]]*v[0-9]+\.' || true)
  if [ "$journal_count" -gt "$JOURNAL_HEADER_FAIL" ]; then
    fail "file-header probe journal: ${f} (${journal_count} version-bump lines in first ${JOURNAL_HEADER_SCAN} lines)"
    header_hits=$((header_hits+1))
  fi
done < <(list_source_files)
[ "$header_hits" -eq 0 ] && pass "no file-header probe journals over threshold"

# ── 5. Orphaned exports ───────────────────────────────────────
CURRENT_CATEGORY="orphans"
section "Orphaned exports"
orphan_count=0

src_list=$(mktemp 2>/dev/null || echo "/tmp/drift-sweep-srclist.$$")
list_source_files > "$src_list"

bulk_text=$(mktemp 2>/dev/null || echo "/tmp/drift-sweep-bulk.$$")
while IFS= read -r f; do
  [ -f "$f" ] && cat "$f" >> "$bulk_text"
  echo "" >> "$bulk_text"
done < "$src_list"

while IFS= read -r f; do
  [ -z "$f" ] || [ ! -f "$f" ] && continue
  basename_f=$(basename "$f")
  case "$basename_f" in index.* | mod.d.ts) continue ;; esac
  while IFS=: read -r lineno line; do
    sym=$(echo "$line" | sed -nE 's/^[[:space:]]*export[[:space:]]+(async[[:space:]]+)?(function|const|class|let|var|interface|type|enum)[[:space:]]+([A-Za-z_][A-Za-z_0-9]*).*$/\3/p')
    [ -z "$sym" ] && continue
    kind=$(echo "$line" | sed -nE 's/^[[:space:]]*export[[:space:]]+(async[[:space:]]+)?(function|const|class|let|var|interface|type|enum)[[:space:]]+([A-Za-z_][A-Za-z_0-9]*).*$/\2/p')
    # type/interface exports are structural TS API surface — cross-file absence is not drift.
    if [ "$kind" = "type" ] || [ "$kind" = "interface" ]; then continue; fi
    if echo "$sym" | grep -qE "$ORPHAN_EXPORT_ALLOWLIST"; then continue; fi

    self_count=$(grep -vE '^[[:space:]]*(//|#|\*|/\*)' "$f" 2>/dev/null | grep -cE "\\b${sym}\\b" || true)
    total_count=$(grep -vE '^[[:space:]]*(//|#|\*|/\*)' "$bulk_text" 2>/dev/null | grep -cE "\\b${sym}\\b" || true)
    external=$((total_count - self_count))

    if [ "$external" -le 0 ]; then
      fail "orphaned export: ${f}:${lineno} ${sym}"
      orphan_count=$((orphan_count+1))
    fi
  done < <(grep -nE '^[[:space:]]*export[[:space:]]+(async[[:space:]]+)?(function|const|class|let|var|interface|type|enum)[[:space:]]+[A-Za-z_]' "$f" 2>/dev/null)
done < "$src_list"

rm -f "$src_list" "$bulk_text" 2>/dev/null
[ "$orphan_count" -eq 0 ] && pass "no orphaned exports detected"

# ── 6. Substrate vs. code freshness ───────────────────────────
CURRENT_CATEGORY="mission-freshness"
section "Substrate vs. code freshness"
if [ -d .git ]; then
  newest_code=0
  while IFS= read -r f; do
    [ -z "$f" ] || [ ! -f "$f" ] && continue
    mt=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)
    [ "$mt" -gt "$newest_code" ] && newest_code=$mt
  done < <(list_source_files)

  stale_seconds=$((MISSION_STALE_DAYS * 86400))
  for sub in ai_context/CURRENT_MISSION.md readme_AI.{{AI}}ai; do
    if [ -f "$sub" ]; then
      sub_mt=$(stat -f %m "$sub" 2>/dev/null || stat -c %Y "$sub" 2>/dev/null || echo 0)
      delta=$((newest_code - sub_mt))
      if [ "$delta" -gt "$stale_seconds" ]; then
        days=$((delta / 86400))
        fail "${sub} stale: code is ${days}d newer (threshold ${MISSION_STALE_DAYS}d)"
      else
        if [ "$sub_mt" -gt "$newest_code" ]; then
          pass "${sub} newer than code"
        else
          days_behind=$((delta / 86400))
          pass "${sub} ${days_behind}d behind code (within threshold)"
        fi
      fi
    fi
  done
fi

# ── 7. CLAUDE.md path-rules table sanity ──────────────────────
CURRENT_CATEGORY="claude-md"
section "CLAUDE.md path-rules table"
if [ -f CLAUDE.md ]; then
  if grep -qE '^\| Glob \|' CLAUDE.md; then
    pass "CLAUDE.md has path-scoped rules table"
  else
    warn "CLAUDE.md missing path-scoped rules table (no '| Glob | ...' table header found)"
  fi
else
  fail "CLAUDE.md missing"
fi

# ── 8. Always-loaded (Tier 1) substrate bloat ─────────────────
# Advisory only (warn). Enforces ADR-004 paging discipline: files loaded on
# every boot must stay lean; session/decision history pages out to on-demand
# archives. A growing always-loaded file is the charter-127KB pattern recurring.
CURRENT_CATEGORY="tier1-bloat"
section "Always-loaded substrate bloat"
tier1_bloat_hits=0
warn_bytes=$((TIER1_BLOAT_WARN_KB * 1024))
for sub in $TIER1_FILES; do
  [ -f "$sub" ] || continue
  sz=$(wc -c < "$sub" 2>/dev/null | tr -d ' ')
  if [ "$sz" -gt "$warn_bytes" ]; then
    warn "tier1 bloat: ${sub} is $((sz / 1024)) KB (>${TIER1_BLOAT_WARN_KB} KB) — page history out to an on-demand archive (ADR-004)"
    tier1_bloat_hits=$((tier1_bloat_hits+1))
  fi
done
[ "$tier1_bloat_hits" -eq 0 ] && pass "no always-loaded substrate files over ${TIER1_BLOAT_WARN_KB} KB"

# ── 9. WISL waystone freshness (v0.1.8: recency-based, staged-aware, lag-free) ──
# For each _waystone.{{AI}}ai: verified_at must parse + resolve (dangling-sha check),
# and the waystone must have been touched at least as RECENTLY as any file it owns
# (excluding itself). Recency replaced the old `verified_at..HEAD` SHA-range diff,
# which lagged: verified_at can't point to the in-flight commit, so the diff always
# flagged the commit AFTER an owned-file change → a forced no-op re-stamp. With
# recency + staged-awareness, staging code + re-stamping the waystone TOGETHER is
# fresh forever; staging owned code without the waystone fails at the creating
# commit. verified_at is kept for the dangling check + as the last-reconciliation
# marker (re-stamp it to HEAD when you re-touch the card). No waystones → graceful
# pass. See WISL-STANDARD §Enforcement.
CURRENT_CATEGORY="waystone-freshness"
section "WISL waystone freshness"
if [ -d .git ]; then
  ws_found=0
  while IFS= read -r wf; do
    [ -z "$wf" ] || [ ! -f "$wf" ] && continue
    ws_found=1
    # verified_at — quote-tolerant (schema friction #6: quoted to survive YAML int-parse)
    sha=$(grep -oE '^verified_at:[[:space:]]*"?[0-9a-f]{7,40}"?' "$wf" | grep -oE '[0-9a-f]{7,40}' | head -1)
    if [ -z "$sha" ]; then
      fail "waystone ${wf}: no parseable verified_at (schema: 7–40 hex, quoted)"
      continue
    fi
    if ! git cat-file -e "${sha}^{commit}" 2>/dev/null; then
      fail "waystone ${wf}: verified_at ${sha} not in git history (dangling sha)"
      continue
    fi
    # owns globs — flat parse (schema's bash extractor; no YAML dep on the gate path)
    globs=$(awk '/^owns:/{f=1;next} f&&/^[[:space:]]+-[[:space:]]/{sub(/^[[:space:]]+-[[:space:]]/,"");print;next} f&&/^[^[:space:]]/{f=0}' "$wf")
    if [ -z "$globs" ]; then
      fail "waystone ${wf}: empty or unparseable owns"
      continue
    fi
    # Freshness by RECENCY (staged-aware), EXCLUDING the waystone file itself.
    owned_staged=$(git diff --cached --name-only -- $globs ':(exclude)**/_waystone.{{AI}}ai' 2>/dev/null)
    ws_staged=0; git diff --cached --quiet -- "$wf" 2>/dev/null || ws_staged=1
    if [ -n "$owned_staged" ]; then
      # Owned files are part of THIS commit → the waystone must be re-stamped with them.
      if [ "$ws_staged" -eq 1 ]; then
        pass "waystone fresh (re-stamped with this commit): ${wf}"
      else
        n=$(printf '%s\n' "$owned_staged" | grep -c .)
        fail "waystone STALE: ${wf} — ${n} owned file(s) staged without re-stamping the waystone; re-read the folder, re-stamp verified_at, and stage it in this commit"
      fi
    elif [ "$ws_staged" -eq 1 ]; then
      pass "waystone fresh (re-stamp staged): ${wf}"
    else
      # Nothing staged → committed-recency comparison (CI clean-checkout path).
      owned_last=$(git log -1 --format=%ct -- $globs ':(exclude)**/_waystone.{{AI}}ai' 2>/dev/null)
      ws_last=$(git log -1 --format=%ct -- "$wf" 2>/dev/null)
      if [ -n "$owned_last" ] && { [ -z "$ws_last" ] || [ "$owned_last" -gt "$ws_last" ]; }; then
        fail "waystone STALE: ${wf} — owned file(s) committed more recently than the waystone (verified_at ${sha}); re-read the folder + re-stamp verified_at"
      else
        pass "waystone fresh: ${wf} (verified_at ${sha})"
      fi
    fi
  done < <(find . -type f -name '_waystone.{{AI}}ai' -not -path './.git/*' 2>/dev/null | sed 's|^\./||')
  [ "$ws_found" -eq 0 ] && pass "no waystones present (WISL not adopted in this repo)"
fi

# ── 10. Up-sync hint freshness ────────────────────────────────
# Opt-in by ai_context/upsync.{{AI}}ai presence. Where a repo publishes workspace-
# relevant deltas UP (a shipped version, a stale ROSTER focus, a cross-cutting
# finding), the hint ledger must not lag readme_AI.
#
# STAGED-AWARE (v0.1.8): at commit time we evaluate the PROSPECTIVE post-commit
# state via the staged index (git diff --cached), not just committed history. This
# closes the one-commit lag of the pure committed-date approach: previously a commit
# that moved readme_AI WITHOUT an upsync block passed (committed dates were still
# equal), and then the *next* commit — the one adding the upsync block to restore
# parity — got blocked, because committed history showed readme ahead. Now: if
# readme_AI is staged, an upsync block must be staged in the SAME commit (caught at
# creation); staging the upsync block alone always passes (restoring parity). On a
# clean checkout (CI) nothing is staged, so we fall through to the committed-date
# comparison — determinism there is preserved. --cached (index vs HEAD) means
# unstaged working-tree edits don't count, so boot-dirty behavior is unchanged too.
# soft_fail: WARN by default, hard FAIL only via --fail-on=up-sync (boot-dirty /
# pre-commit / CI). No hint file → silent pass, so the fleet-canonical sweep stays
# dormant until a repo adopts the loop. (Distinct from waystone-freshness, which
# binds folder edits to a waystone re-stamp; this binds repo state to an up-sync.)
CURRENT_CATEGORY="up-sync"
section "Up-sync hint freshness"
if [ ! -f ai_context/upsync.{{AI}}ai ]; then
  pass "up-sync not configured (no ai_context/upsync.{{AI}}ai)"
elif [ ! -d .git ]; then
  pass "up-sync: not a git repo — skipping"
else
  # Staged (index vs HEAD): non-zero exit ⇒ that path is part of this commit.
  readme_staged=0; git diff --cached --quiet -- readme_AI.{{AI}}ai 2>/dev/null || readme_staged=1
  hint_staged=0;   git diff --cached --quiet -- ai_context/upsync.{{AI}}ai 2>/dev/null || hint_staged=1
  if [ "$readme_staged" -eq 1 ] || [ "$hint_staged" -eq 1 ]; then
    # This commit touches the substrate pair — require them to move together.
    if [ "$readme_staged" -eq 1 ] && [ "$hint_staged" -eq 0 ]; then
      soft_fail "up-sync stale: readme_AI is staged without an ai_context/upsync.{{AI}}ai block — stage an up-sync block in the same commit (timestamps match)"
    else
      pass "up-sync hint current (upsync staged with this change)"
    fi
  else
    # Nothing staged → committed-history comparison (CI clean-checkout path, unchanged).
    last_readme=$(git log -1 --format=%ct -- readme_AI.{{AI}}ai 2>/dev/null)
    last_hint=$(git log -1 --format=%ct -- ai_context/upsync.{{AI}}ai 2>/dev/null)
    if [ -z "$last_hint" ] || { [ -n "$last_readme" ] && [ "$last_readme" -gt "$last_hint" ]; }; then
      soft_fail "up-sync stale: readme_AI moved since the last published hint — append an ai_context/upsync.{{AI}}ai block (commit it WITH the substrate change so timestamps match)"
    else
      pass "up-sync hint current (readme_AI not ahead of last hint)"
    fi
  fi
fi

# ── 11. Wrap continuity (Agent Boot Contract W1) ──────────────
# The tool-agnostic WRITE-edge floor (ADR-BOOT-001): every agent commits through
# git, so the wrap gate lives here — not only in Claude's SessionStart hooks,
# which Codex never fires (the OFS SL-001/THR-004 gap). Carrier = the repo's
# session-continuity file: readme_AI.{{AI}}ai in-repo, or the workspace HANDOFF
# log in the substrate repo (override via WRAP_CARRIER in drift-sweep.conf).
# Staged-aware: a commit that moves the carrier IS the wrap — passes. Otherwise
# the carrier must not lag HEAD by more than WRAP_LAG_WARN commits (default 10);
# a bigger lag means sessions are piling commits on an unwrapped carrier and the
# next agent will boot stale. File-touch is the deliberate proxy for "gained a
# HANDOFF block" — content parsing stays in the Claude-native gates; a non-wrap
# carrier touch resetting the counter is acceptable for an advisory floor.
# soft_fail: WARN by default, FAIL via --fail-on=wrap-continuity. No carrier →
# graceful pass (template pre-bootstrap, non-substrate repos).
CURRENT_CATEGORY="wrap-continuity"
section "Wrap continuity (boot contract W1)"
if [ ! -d .git ]; then
  pass "wrap-continuity: not a git repo — skipping"
else
  wrap_carrier="${WRAP_CARRIER}"
  if [ -z "$wrap_carrier" ]; then
    if [ -f readme_AI.{{AI}}ai ]; then
      wrap_carrier="readme_AI.{{AI}}ai"
    elif [ -f .claude/skills/hi-mode/HANDOFF_LOG.{{AI}}ai ]; then
      wrap_carrier=".claude/skills/hi-mode/HANDOFF_LOG.{{AI}}ai"
    fi
  fi
  if [ -z "$wrap_carrier" ] || [ ! -f "$wrap_carrier" ]; then
    pass "wrap-continuity: no wrap carrier present (not adopted here)"
  else
    wc_staged=0; git diff --cached --quiet -- "$wrap_carrier" 2>/dev/null || wc_staged=1
    if [ "$wc_staged" -eq 1 ]; then
      pass "wrap-continuity: carrier staged with this commit (wrap in flight): ${wrap_carrier}"
    else
      wc_last=$(git log -1 --format=%H -- "$wrap_carrier" 2>/dev/null)
      if [ -z "$wc_last" ]; then
        soft_fail "wrap-continuity: carrier ${wrap_carrier} exists but has never been committed — commit it (untracked continuity is one crash from gone)"
      else
        wc_lag=$(git rev-list --count "${wc_last}..HEAD" 2>/dev/null || echo 0)
        if [ "$wc_lag" -gt "$WRAP_LAG_WARN" ]; then
          soft_fail "wrap-continuity: ${wc_lag} commit(s) since ${wrap_carrier} last moved (threshold ${WRAP_LAG_WARN}) — a session may not have wrapped; wrap or re-stamp the carrier before piling on more"
        else
          pass "wrap-continuity: carrier lag ${wc_lag} ≤ ${WRAP_LAG_WARN} (${wrap_carrier})"
        fi
      fi
    fi
  fi
fi

# ── 12. WISL waystone graph connectivity ──────────────────────
# For each _waystone.{{AI}}ai: every depends_on (a folder) and boot_path (a file or
# dir) edge must resolve on disk. Self-propagation (WISL-STANDARD §design intent)
# requires the graph to actually connect — a dangling edge means the next AI lands
# on a card pointing at a moved/renamed/typo'd path. Parses FRONTMATTER ONLY (between
# the --- fences) so prose mentions of "boot_path" don't match; strips inline # comments.
# No waystones → graceful pass. ADVISORY (soft_fail): WARN unless --fail-on=wisl-graph.
CURRENT_CATEGORY="wisl-graph"
section "WISL waystone graph connectivity"
wg_found=0
wg_dangling=0
while IFS= read -r wf; do
  [ -z "$wf" ] || [ ! -f "$wf" ] && continue
  wg_found=1
  wdir=$(dirname "$wf")
  # frontmatter only (first --- … second ---), so body prose can't false-match
  fm=$(awk '/^---[[:space:]]*$/{c++; next} c==1{print} c>=2{exit}' "$wf")
  for key in depends_on boot_path; do
    # extract list items under KEY: strip "- ", inline "# comment", trailing ws
    entries=$(printf '%s\n' "$fm" | awk -v key="$key" '
      $0 ~ "^"key":" {f=1; next}
      f && /^[[:space:]]+-[[:space:]]/ { sub(/^[[:space:]]+-[[:space:]]*/,""); sub(/[[:space:]]*#.*$/,""); sub(/[[:space:]]+$/,""); if (length($0)) print; next }
      f && /^[^[:space:]]/ {f=0}
    ')
    [ -z "$entries" ] && continue
    while IFS= read -r e; do
      [ -z "$e" ] && continue
      # entries are repo-relative; boot_path may cross folders (incl. out-of-folder files)
      if [ ! -e "$e" ]; then
        soft_fail "wisl-graph: ${wf} ${key} → '${e}' does not resolve (dangling edge)"
        wg_dangling=$((wg_dangling+1))
      fi
    done <<< "$entries"
  done
done < <(find . -type f -name '_waystone.{{AI}}ai' -not -path './.git/*' 2>/dev/null | sed 's|^\./||')
if [ "$wg_found" -eq 0 ]; then
  pass "wisl-graph: no waystones present (WISL not adopted in this repo)"
elif [ "$wg_dangling" -eq 0 ]; then
  pass "wisl-graph: all waystone edges resolve"
fi

# ── 13. WISL seam coverage ────────────────────────────────────
# A folder the seam map declares a 'needed' or 'live' seam MUST carry a _waystone.{{AI}}ai
# (catches a MISSING card, which waystone-freshness can't — it only catches STALE ones).
# Reads the workspace seam-coverage projection (whitespace: repo folder status). Runs at
# lefthook/boot only — the workspace file is absent in a single-repo CI checkout, where this
# graceful-passes (same dangle posture as the symlinked skill). 'none'/'defer'/'candidate'
# rows are recorded DECISIONS, not gaps, and are not checked. ADVISORY (soft_fail): WARN
# unless --fail-on=seam-coverage (the "arm" step, deferred).
CURRENT_CATEGORY="seam-coverage"
section "WISL seam coverage"
if [ ! -d .git ]; then
  pass "seam-coverage: not a git repo — skipping"
else
  top=$(git rev-parse --show-toplevel 2>/dev/null)
  seam_tsv=""
  for cand in \
    "${top:+${top}/../.repo-manager/standards/WISL/seam-coverage.tsv}" \
    "${HOME}/GitHub/.repo-manager/standards/WISL/seam-coverage.tsv"; do
    [ -n "$cand" ] && [ -f "$cand" ] && { seam_tsv="$cand"; break; }
  done
  if [ -z "$seam_tsv" ]; then
    pass "seam-coverage: no workspace seam map reachable (single-repo checkout or not adopted)"
  else
    repo_name=$(basename "${top:-$(pwd)}")
    sc_missing=0
    sc_checked=0
    while read -r r folder status _rest; do
      [ -z "$r" ] && continue
      case "$r" in \#*) continue ;; esac
      [ "$r" = "$repo_name" ] || continue
      case "$status" in needed|live) ;; *) continue ;; esac
      sc_checked=$((sc_checked+1))
      if [ ! -f "${folder}/_waystone.{{AI}}ai" ]; then
        soft_fail "seam-coverage: ${repo_name}/${folder} is a '${status}' seam with no _waystone.{{AI}}ai"
        sc_missing=$((sc_missing+1))
      fi
    done < "$seam_tsv"
    if [ "$sc_checked" -eq 0 ]; then
      pass "seam-coverage: no declared seams for ${repo_name} in the seam map"
    elif [ "$sc_missing" -eq 0 ]; then
      pass "seam-coverage: all ${sc_checked} declared seam(s) for ${repo_name} have waystones"
    fi
  fi
fi

# ── Summary ───────────────────────────────────────────────────
if [ "$JSON_OUTPUT" -eq 1 ]; then
  fail_on_display="${FAIL_ON_CATEGORIES:-all}"
  echo "{"
  echo "  \"repo\": \"$(pwd)\","
  echo "  \"code_roots\": \"${CODE_ROOTS}\","
  echo "  \"failures\": ${FAILS},"
  echo "  \"warnings\": ${WARNS},"
  echo "  \"exit_failures\": ${EXIT_FAILS},"
  echo "  \"fail_on\": \"${fail_on_display}\","
  echo "  \"checks\": ["
  count=${#JSON_CHECKS[@]}
  for i in "${!JSON_CHECKS[@]}"; do
    if [ $((i + 1)) -lt "$count" ]; then
      echo "    ${JSON_CHECKS[$i]},"
    else
      echo "    ${JSON_CHECKS[$i]}"
    fi
  done
  echo "  ]"
  echo "}"
else
  echo
  echo "── Summary ──"
  echo "Failures: $FAILS"
  echo "Warnings: $WARNS"
  [ -n "$FAIL_ON_CATEGORIES" ] && echo "Gated on: ${FAIL_ON_CATEGORIES} (exit failures: ${EXIT_FAILS})"
fi

if [ "$EXIT_FAILS" -gt 0 ]; then
  exit 1
fi
exit 0
