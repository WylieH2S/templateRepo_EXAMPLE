#!/usr/bin/env bash
# drift-sweep v0.1.3 — detect code/substrate drift in a repo.
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
#                              orphans, mission-freshness, claude-md
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
    | grep -iE '(audit|findings|mission|handoff|decisions|charter|rules).*\.(md|chloeai)$' \
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
  for sub in ai_context/CURRENT_MISSION.md readme_AI.chloeai; do
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
