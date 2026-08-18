#!/usr/bin/env bash
# wrap-gate.sh — SessionStart wrap-state gate (GENERIC: in-repo + workspace; HI Mode).
#
# Companion to handoff-gate.sh. Wired via .claude/settings.json SessionStart hook
# (matchers: startup, resume, clear, compact). SessionStart stdout is injected into
# the session context, so this banner lands in front of the agent at boot AND after
# every compaction — surfacing a PRIOR session that committed/changed work but never
# wrapped (no HANDOFF block written, commits left unpushed).
#
# Mechanism backstop for the "wrap is prose, so an abrupt session drops it" gap. The
# boot/read edge and the pre-commit/publish edge were already mechanized (handoff-gate
# model banner, drift-sweep up-sync); this closes the session-end/wrap edge. See the
# repo-manager memory feedback-mechanize-every-skippable-edge.
#
# Handoff carrier (auto-detected, mirrors handoff-gate.sh). <ext> is RESOLVED
# from the repo's own substrate since 2026-08-16, not hardcoded to `chloeai`:
#   <repo>/readme_AI.<ext>                          present → in-repo session
#   <repo>/.claude/skills/hi-mode/HANDOFF_LOG.<ext> else    → workspace session
#
# Three checks, all against the git repo containing this hook (resolved from the
# script's own physical path, so it works from any cwd / the non-git parent):
#   1. commits since the last HANDOFF block (last commit touching the carrier)
#   2. unpushed commits (@{u}..HEAD)
#   3. uncommitted changes (excl. known runtime churn: .repo-manager/queue/)
#
# Advisory only: ALWAYS exits 0 — a SessionStart gate must never block the session.

set -uo pipefail

# --- read stdin JSON (best-effort; only `source` is used, for a context note) ---
input=$(cat 2>/dev/null || true)
src=$(printf '%s' "$input" \
  | grep -oE '"source"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)".*/\1/')

# --- resolve the git repo from this script's physical location ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)" || SCRIPT_DIR=""
R="$(git -C "${SCRIPT_DIR:-.}" rev-parse --show-toplevel 2>/dev/null)"
[ -z "$R" ] && exit 0   # not in a git repo — nothing to gate

# Fetch from origin silently — keeps refs current for the behind-origin check below.
# (No-op when offline or no remote; always exits 0.)
git -C "$R" fetch --quiet origin 2>/dev/null || true

# --- resolve the carrier extension, then the HANDOFF carrier itself ---
# `chloeai` used to be hardcoded here. It is detected now, from the repo's own
# root waystone card, exactly as drift-sweep and validate-substrate do — see the
# long note at drift-sweep's resolver for the defects the hardcoding caused. A
# hook is advisory and must always exit 0, so an unresolvable carrier CANNOT
# refuse the way those two do; it says so in the banner instead. Saying nothing
# would make "I could not look" indistinguishable from "nothing to report",
# which is the same confusion the backstop band below exists to end.
AI_EXT=""
# ORDERED ANCHORS. `_waystone` first (unambiguous), then Tier-1 substrate —
# because init-project.sh DELETES the root cards when it seeds a repo, so a fresh
# project has none and would otherwise never resolve a carrier at all.
for _stem in _waystone STARTUP_AI readme_AI AI_HANDOFF SIDEQUESTS; do
  for _f in "$R/$_stem".*; do
    { [ -e "$_f" ] || [ -L "$_f" ]; } || continue
    _s="${_f##*/}"; _s="${_s#"$_stem".}"
    case "$_s" in
      md|txt|json|yml|yaml|toml|bak|orig|swp|tmp|lock) ;;
      hey*) ;;                                  # human doorway, not the AI carrier
      *) [ -z "$AI_EXT" ] && AI_EXT="$_s" ;;
    esac
  done
done

carrier_note=""
HB_PATH=""
if [ -z "$AI_EXT" ]; then
  carrier_note="  • carrier extension UNRESOLVED (no ${R}/_waystone.<ext>) — the unwrapped-commits check below did not run."
elif [ -f "$R/readme_AI.${AI_EXT}" ]; then
  HB_PATH="readme_AI.${AI_EXT}"
elif [ -f "$R/.claude/skills/hi-mode/HANDOFF_LOG.${AI_EXT}" ]; then
  HB_PATH=".claude/skills/hi-mode/HANDOFF_LOG.${AI_EXT}"
fi

issues=0
details=""

# 1. commits since the last HANDOFF block (carrier last-touched)
if [ -n "$HB_PATH" ]; then
  last_hb=$(git -C "$R" log -1 --format=%H -- "$HB_PATH" 2>/dev/null)
  if [ -n "$last_hb" ]; then
    unwrapped=$(git -C "$R" log "${last_hb}..HEAD" --format='%h %s' 2>/dev/null || true)
    if [ -n "$unwrapped" ]; then
      n=$(printf '%s\n' "$unwrapped" | grep -c .)
      details+="  • ${n} commit(s) since the last HANDOFF block (${HB_PATH}) — prior session may not have wrapped:"$'\n'
      details+="$(printf '%s\n' "$unwrapped" | sed 's/^/        /')"$'\n'
      issues=$((issues + 1))
    fi
  fi
fi

# 2. unpushed commits
if git -C "$R" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  unpushed=$(git -C "$R" log '@{u}..HEAD' --format='%h %s' 2>/dev/null || true)
  if [ -n "$unpushed" ]; then
    n=$(printf '%s\n' "$unpushed" | grep -c .)
    details+="  • ${n} unpushed commit(s) — off-box backup stale; push on the owner's go."$'\n'
    issues=$((issues + 1))
  fi
fi

# 3. uncommitted changes (excl. known runtime churn — workspace daemon queue/;
#    harmless no-op in repos that have no such path)
dirty=$(git -C "$R" status --porcelain 2>/dev/null | grep -v '\.repo-manager/queue/' || true)
if [ -n "$dirty" ]; then
  n=$(printf '%s\n' "$dirty" | grep -c .)
  details+="  • ${n} uncommitted change(s) (excl. runtime churn):"$'\n'
  details+="$(printf '%s\n' "$dirty" | sed 's/^/        /')"$'\n'
  issues=$((issues + 1))
fi

# 4. behind-origin (fetch above makes this accurate; a pull is needed if non-zero)
if git -C "$R" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  _behind=$(git -C "$R" rev-list 'HEAD..@{u}' --count 2>/dev/null || echo 0)
  if [ -n "$_behind" ] && [ "$_behind" -gt 0 ]; then
    details+="  • ${_behind} commit(s) behind origin — run git pull (HANDOFF carrier may be stale)."$'\n'
    issues=$((issues + 1))
  fi
fi

# --- 5. server-side backstop health (only in the repo that OWNS the workflow) ---
#
# WHY THIS LIVES IN A SessionStart HOOK. The check itself already existed —
# drift-sweep --maintenance has reported backstop health since v0.1.21 — but nothing
# made a boot RUN it. The charter runs the boot sweep only when the tree is DIRTY,
# and its --fail-on list does not include maintenance. On 2026-08-14 the tree was
# clean, so the sweep never ran, and fourteen consecutive nightly failures had gone
# unseen for four days. A check reachable only by deliberate manual invocation is the
# skippable edge this fleet keeps re-learning (see the repo-manager memory
# feedback-mechanize-every-skippable-edge, and SESSION-039, which gated the boot and
# publish edges and left the wrap edge open until it recurred).
#
# COST IS SCOPED TO ONE REPO: the guard is the workflow file, which exists only in
# repoManager, so the other ten fleet repos do no network work and print nothing.
# Set BACKSTOP_CHECK=0 to opt out entirely.
#
# Deliberately NOT folded into `issues`: a red backstop is not a wrap failure, and
# reporting "WRAP gate: 1 unresolved item" for a CI credential would make one banner
# mean two different things. It gets its own band, below the wrap verdict.
_bs_wf="${BACKSTOP_WORKFLOW:-fleet-sweep.yml}"
backstop_lines=""
if [ -f "$R/.github/workflows/${_bs_wf}" ]; then
  _sweep="$SCRIPT_DIR/../skills/drift-sweep/sweep.sh"
  if [ -f "$_sweep" ]; then
    # ONE bound around the whole probe. backstop_report bounds each of its own gh
    # calls, but it makes three of them and a BOOT must never be held hostage to a
    # bad network. Never allowed to affect exit status — this hook always exits 0.
    #
    # THE BOUND USED TO NOT EXIST HERE (2026-08-16). It was `timeout 20` where
    # `timeout`/`gtimeout` was found and an EMPTY STRING otherwise, with a comment
    # saying we'd "accept gh's own timeouts". Stock macOS ships neither binary and
    # this fleet's primary machine is a Mac, so on the box this hook was written
    # for there was no bound at all — and `gh` has no whole-operation deadline to
    # fall back on. It stopped being theoretical when this exact line ran past two
    # minutes on the boot path and had to be killed by hand. Now a bash-native
    # watchdog: background the probe, kill it on expiry, no coreutils required.
    # POLLING, not a `( sleep 20; kill ) &` watchdog. That form works, but on the
    # normal fast path the sleeper LINGERS for the rest of its 20 seconds — a
    # stray process left behind on every single boot, still holding whatever
    # descriptors it inherited. Polling costs 1-second granularity and leaves
    # nothing running.
    _bs_out="$(mktemp)"
    bash "$_sweep" --backstop-only "$R" >"$_bs_out" 2>/dev/null &
    _bs_pid=$!; _bs_waited=0
    while kill -0 "$_bs_pid" 2>/dev/null && [ "$_bs_waited" -lt 20 ]; do
      sleep 1; _bs_waited=$((_bs_waited + 1))
    done
    if kill -0 "$_bs_pid" 2>/dev/null; then
      kill -TERM "$_bs_pid" 2>/dev/null; wait "$_bs_pid" 2>/dev/null
      # A probe that did not complete is a THIRD state, neither green nor red.
      # Printing nothing would make it look like green — the exact confusion this
      # whole category exists to end.
      backstop_lines="    backstop ${_bs_wf}: COULD NOT CHECK — probe exceeded its 20s bound (network? gh auth?)"
    else
      wait "$_bs_pid" 2>/dev/null
      backstop_lines=$(cat "$_bs_out")
    fi
    rm -f "$_bs_out"
  else
    # Loud, not silent. This whole category exists because absence of signal got read
    # as health for four days; a missing probe must not print like a green one.
    backstop_lines="    backstop ${_bs_wf}: COULD NOT CHECK — drift-sweep not found at ${_sweep}"
  fi
fi

note=""
[ "$src" = "compact" ] && note=" (post-compaction re-entry)"

if [ "$issues" -eq 0 ]; then
  echo "✓ WRAP gate${note}: $(basename "$R") clean — nothing unwrapped/unpushed/uncommitted."
  [ -n "$carrier_note" ] && printf '%s\n' "$carrier_note"
else
  echo "⚠ WRAP gate${note}: ${issues} unresolved item(s) in $(basename "$R") — a prior session may not have wrapped:"
  printf '%s' "$details"
  [ -n "$carrier_note" ] && printf '%s\n' "$carrier_note"
  echo "   → Resolve before the first non-read action: append the HANDOFF block, commit, push on the owner's go (HI Mode SESSION WRAP)."
fi

# Silent when green and current, when this repo owns no backstop, or when opted out.
if [ -n "$backstop_lines" ]; then
  echo "⚠ BACKSTOP (server-side CI — what catches a bypassed local gate):"
  printf '%s\n' "$backstop_lines"
fi

# --- versioned git hooks: installed, or merely present? (SESSION-098) ---
# A hook committed to the repo is NOT a hook that runs. `core.hooksPath` is local
# config, so it does not travel with a clone — the Mini pulling this repo gets the
# script and none of the enforcement, and a gate that is present but unwired fails
# exactly the way a gate that does not exist fails: silently.
#
# Deliberately a WARNING, not a self-install. Setting the config from here would be
# a hook silently mutating git config on a machine whose owner never asked — cheap
# to reverse, but surprising, and surprise is how trust in these banners dies.
# Naming the one-line fix is the mechanism; running it is the owner's call.
if [ -d "$R/.claude/githooks" ]; then
  _hp=$(git -C "$R" config --get core.hooksPath 2>/dev/null || true)
  _missing=""
  if [ "$_hp" != ".claude/githooks" ]; then
    _missing="core.hooksPath is '${_hp:-<unset, using .git/hooks>}'"
  elif [ ! -x "$R/.claude/githooks/pre-commit" ]; then
    _missing="pre-commit is not executable"
  fi
  if [ -n "$_missing" ]; then
    echo "⚠ GIT HOOKS ($(basename "$R")): versioned hooks present but NOT ACTIVE — ${_missing}."
    echo "   Local commits are not being format-checked. Install with:"
    echo "     git -C \"$R\" config core.hooksPath .claude/githooks"
    echo "     chmod +x \"$R\"/.claude/githooks/*"
  fi
fi
exit 0
