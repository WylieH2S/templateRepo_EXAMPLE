#!/usr/bin/env bash
# handoff-gate.sh — SessionStart model/effort gate (generic; in-repo + workspace).
#
# Wired via .claude/settings.json SessionStart hook (matchers: startup, resume).
# Reads the hook's stdin JSON, maps the current provider-native `model` to a
# provider-neutral capability, compares it to the active handoff's
# recommended_capability, and prints a banner. SessionStart stdout is
# injected into the session context, so the banner lands in front of the agent at
# boot. A capability MISMATCH is elevated to STOP-THE-LINE (HI Mode charter, B3).
# Historical recommended_model handoffs remain dual-readable.
#
# Recommendation source (auto-detected by context):
#   ./readme_AI.{{AI}}ai                          present → in-repo session
#   .claude/skills/hi-mode/HANDOFF_LOG.{{AI}}ai   else    → workspace session
# Both fields are read from the LAST block in that file.
#
# Effort is NOT on stdin (Claude Code doesn't pass it) → surface-only: the
# recommended effort is always printed for the agent to confirm via /effort.
#
# Always exits 0 — a startup gate must never block the session.

set -uo pipefail

# Fetch from origin silently — keeps the recommendation source up-to-date.
# (No-op when offline or no remote; always exits 0.)
git fetch --quiet origin 2>/dev/null || true

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

# recommendation source by context
if [ -f ./readme_AI.{{AI}}ai ]; then
  SRC="./readme_AI.{{AI}}ai"; CTX="in-repo: $(basename "$(pwd)")"
elif [ -f .claude/skills/hi-mode/HANDOFF_LOG.{{AI}}ai ]; then
  SRC=".claude/skills/hi-mode/HANDOFF_LOG.{{AI}}ai"; CTX="workspace"
else
  echo "ℹ HANDOFF gate: no recommendation source (readme_AI.{{AI}}ai / HANDOFF_LOG.{{AI}}ai) found — skipping model/effort check."
  exit 0
fi

# Warn if still behind origin after fetch — a pull is needed to read the latest recommendation.
if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  _behind=$(git rev-list 'HEAD..@{u}' --count 2>/dev/null || echo 0)
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
  echo "ℹ HANDOFF gate ($CTX): no recommended_capability= (or recognized legacy recommended_model=) in the latest handoff block — skipping."
elif [ -z "$cur_capability" ]; then
  echo "ℹ HANDOFF ($CTX): recommends capability=${rec_capability} / effort=${eff_note}. (Couldn't map current provider-native model ${raw_model:-unknown} — confirm provider/model + effort manually.)"
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
