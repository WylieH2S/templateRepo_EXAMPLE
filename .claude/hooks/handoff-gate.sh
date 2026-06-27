#!/usr/bin/env bash
# handoff-gate.sh — SessionStart model/effort gate (generic; in-repo + workspace).
#
# Wired via .claude/settings.json SessionStart hook (matchers: startup, resume).
# Reads the hook's stdin JSON, extracts the current `model`, compares it to the
# active handoff's recommended_model, and prints a banner. SessionStart stdout is
# injected into the session context, so the banner lands in front of the agent at
# boot. A model MISMATCH is elevated to STOP-THE-LINE (HI Mode charter, B3).
#
# Recommendation source (auto-detected by context):
#   ./readme_AI.chloeai                          present → in-repo session
#   .claude/skills/hi-mode/HANDOFF_LOG.chloeai   else    → workspace session
# Both fields are read from the LAST block in that file.
#
# Effort is NOT on stdin (Claude Code doesn't pass it) → surface-only: the
# recommended effort is always printed for the agent to confirm via /effort.
#
# Always exits 0 — a startup gate must never block the session.

set -uo pipefail

input=$(cat 2>/dev/null || true)

# current model from stdin JSON (no jq dependency)
raw_model=$(printf '%s' "$input" \
  | grep -oE '"model"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)".*/\1/')

normalize() {  # claude-opus-4-8 → opus, *sonnet* → sonnet, *haiku* → haiku
  case "$1" in
    *opus*)   echo opus ;;
    *sonnet*) echo sonnet ;;
    *haiku*)  echo haiku ;;
    *)        echo "$1" ;;
  esac
}
cur_model=$(normalize "$raw_model")

# recommendation source by context
if [ -f ./readme_AI.chloeai ]; then
  SRC="./readme_AI.chloeai"; CTX="in-repo: $(basename "$(pwd)")"
elif [ -f .claude/skills/hi-mode/HANDOFF_LOG.chloeai ]; then
  SRC=".claude/skills/hi-mode/HANDOFF_LOG.chloeai"; CTX="workspace"
else
  echo "ℹ HANDOFF gate: no recommendation source (readme_AI.chloeai / HANDOFF_LOG.chloeai) found — skipping model/effort check."
  exit 0
fi

rec_model=$(grep -oE 'recommended_model="?[a-z]+"?'  "$SRC" 2>/dev/null | tail -1 | sed 's/.*=//; s/"//g')
rec_effort=$(grep -oE 'recommended_effort="?[a-z]+"?' "$SRC" 2>/dev/null | tail -1 | sed 's/.*=//; s/"//g')
eff_note="${rec_effort:-unspecified}"

if [ -z "$rec_model" ]; then
  echo "ℹ HANDOFF gate ($CTX): no recommended_model= in the latest handoff block — skipping."
elif [ -z "$cur_model" ]; then
  echo "ℹ HANDOFF ($CTX): recommends ${rec_model} / ${eff_note}. (Couldn't read current model from stdin — confirm /model + /effort manually.)"
elif [ "$cur_model" != "$rec_model" ]; then
  echo "⚠ HANDOFF ($CTX): recommends ${rec_model} / ${eff_note}.  You are on: ${cur_model}."
  echo "   MODEL MISMATCH → STOP-THE-LINE: confirm /model (and /effort) before the first non-read action."
else
  echo "✓ HANDOFF ($CTX): on ${cur_model}, matching the recommendation. Recommended effort: ${eff_note} — confirm via /effort."
fi
exit 0
