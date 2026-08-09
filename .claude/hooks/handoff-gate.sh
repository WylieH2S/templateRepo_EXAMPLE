#!/usr/bin/env bash
# handoff-gate.sh — SessionStart capability/effort gate (generic; in-repo + workspace).
#
# Wired via .claude/settings.json SessionStart hook (matchers: startup, resume,
# clear, compact). Reads the hook's stdin JSON, maps the current provider-native
# `model` to a provider-neutral capability, compares it to the active handoff's
# recommended_capability, and prints a banner. SessionStart stdout is injected into
# the session context, so the banner lands in front of the agent at boot. A
# capability MISMATCH is elevated to STOP-THE-LINE (HI Mode charter, B3).
# Historical recommended_model handoffs remain dual-readable.
#
# Recommendation source (first hit wins), searched under each candidate root:
#   readme_AI.{{AI}}ai                          present → in-repo session
#   .claude/skills/hi-mode/HANDOFF_LOG.{{AI}}ai else    → workspace session
# Both fields are read from the LAST @-block in that file.
#
# ROOT RESOLUTION (2026-08-09). Candidate roots are tried in order:
#   $CLAUDE_PROJECT_DIR  → git toplevel  → $PWD
# Previously this script looked for `./readme_AI.{{AI}}ai` relative to CWD alone.
# Launched from a subdirectory that resolved to nothing and the gate announced
# "no recommendation source — skipping", which is indistinguishable from a pass.
# That is the same false-comfort failure that let a stale fork of this file sit
# undetected for ~17 days across the fleet; it just arrives by a different route,
# and fixing the fork did not close it. Anchor to the project root instead.
#
# LOUD-SKIP CONTRACT (2026-08-09). Exactly ONE path prints `✓`, and only when a
# real comparison happened and matched. Every path where the comparison did NOT
# happen prints `⚠ ... GATE DID NOT RUN` and names what was missing. A gate that
# skips must never look like a gate that passed.
#
# Effort is NOT on stdin (Claude Code doesn't pass it) → surface-only: the
# recommended effort is always printed for the agent to confirm via /effort.
#
# Always exits 0 — a startup gate must never block the session. (Claude Code
# treats a non-zero SessionStart exit as "show stderr to user", not a block, but
# this script owns its own reporting and keeps the contract explicit.)

set -uo pipefail

input=$(cat 2>/dev/null || true)

# current model from stdin JSON (no jq dependency)
raw_model=$(printf '%s' "$input" \
  | grep -oE '"model"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)".*/\1/')

native_capability() {  # Claude adapter boundary; universal labels stay generic.
  case "$1" in
    *fable*|*mythos*) echo frontier_max ;;
    *opus*)   echo frontier ;;
    *sonnet*) echo balanced ;;
    *haiku*)  echo economy ;;
    *)        echo "" ;;
  esac
}
cur_capability=$(native_capability "$raw_model")

# ── Resolve the recommendation source, anchored to the project root ──
SRC=""; CTX=""; ROOT=""
_git_top=$(git rev-parse --show-toplevel 2>/dev/null || true)
for _root in "${CLAUDE_PROJECT_DIR:-}" "$_git_top" "$PWD"; do
  [ -n "$_root" ] && [ -d "$_root" ] || continue
  if [ -f "$_root/readme_AI.{{AI}}ai" ]; then
    ROOT="$_root"; SRC="$_root/readme_AI.{{AI}}ai"
    CTX="in-repo: $(basename "$_root")"; break
  elif [ -f "$_root/.claude/skills/hi-mode/HANDOFF_LOG.{{AI}}ai" ]; then
    ROOT="$_root"; SRC="$_root/.claude/skills/hi-mode/HANDOFF_LOG.{{AI}}ai"
    CTX="workspace"; break
  fi
done

if [ -z "$SRC" ]; then
  echo "⚠ HANDOFF gate: GATE DID NOT RUN — no recommendation source found."
  echo "   Looked for readme_AI.{{AI}}ai / .claude/skills/hi-mode/HANDOFF_LOG.{{AI}}ai under:"
  echo "     CLAUDE_PROJECT_DIR=${CLAUDE_PROJECT_DIR:-<unset>}  git-toplevel=${_git_top:-<none>}  PWD=$PWD"
  echo "   The capability check did NOT happen. This is not a pass — confirm provider/model + effort manually."
  exit 0
fi

# Fetch from origin silently — keeps the recommendation source up-to-date.
# (No-op when offline or no remote; always exits 0.) Anchored to ROOT so a
# subdirectory launch still talks to the right repo.
git -C "$ROOT" fetch --quiet origin 2>/dev/null || true

# Warn if still behind origin after fetch — a pull is needed to read the latest recommendation.
if git -C "$ROOT" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  _behind=$(git -C "$ROOT" rev-list 'HEAD..@{u}' --count 2>/dev/null || echo 0)
  [ "${_behind:-0}" -gt 0 ] && echo "   ⚠ HANDOFF ($CTX): ${_behind} commit(s) behind origin — git pull to read the latest recommendation."
fi

active_block=$(awk '
  /^@[0-9][0-9][0-9][0-9]-/ { block=$0 ORS; next }
  block != "" { block=block $0 ORS }
  END { printf "%s", block }
' "$SRC" 2>/dev/null)
rec_capability=$(printf '%s' "$active_block" \
  | grep -oE 'recommended_capability="?[a-z_]+"?' \
  | tail -1 | sed 's/.*=//; s/"//g')
legacy_model=$(printf '%s' "$active_block" \
  | grep -oE 'recommended_model="?[a-z]+"?' \
  | tail -1 | sed 's/.*=//; s/"//g')
if [ -z "$rec_capability" ] && [ -n "$legacy_model" ]; then
  rec_capability=$(native_capability "$legacy_model")
fi
rec_effort=$(printf '%s' "$active_block" \
  | grep -oE 'recommended_effort="?[a-z]+"?' \
  | tail -1 | sed 's/.*=//; s/"//g')
eff_note="${rec_effort:-unspecified}"

if [ -z "$rec_capability" ]; then
  echo "⚠ HANDOFF gate ($CTX): GATE DID NOT RUN — no recommended_capability= (or legacy recommended_model=) in the latest handoff block of ${SRC#"$ROOT"/}."
  echo "   The capability check did NOT happen. This is not a pass — either the handoff is missing the field, or this gate is out of date with the handoff format."
elif [ -z "$cur_capability" ]; then
  echo "⚠ HANDOFF ($CTX): GATE DID NOT RUN — recommends capability=${rec_capability} / effort=${eff_note}, but the current provider-native model (${raw_model:-<unreadable>}) has no capability mapping."
  echo "   The comparison did NOT happen. Confirm provider/model + effort manually."
else
  rec_model_capability="$rec_capability"
  [ "$rec_model_capability" = "frontier_max" ] && rec_model_capability="frontier"
  cur_model_capability="$cur_capability"
  [ "$cur_model_capability" = "frontier_max" ] && cur_model_capability="frontier"
  if [ "$cur_model_capability" != "$rec_model_capability" ]; then
    echo "⚠ HANDOFF ($CTX): recommends capability=${rec_capability} / effort=${eff_note}. Current ${raw_model:-unknown} maps to capability=${cur_capability}."
    echo "   CAPABILITY MISMATCH → STOP-THE-LINE: confirm provider/model (and effort) before the first non-read action."
  else
    echo "✓ HANDOFF ($CTX): current ${raw_model:-unknown} maps to capability=${cur_capability}, matching ${rec_capability}. Recommended effort: ${eff_note} — confirm separately."
  fi
fi
exit 0
