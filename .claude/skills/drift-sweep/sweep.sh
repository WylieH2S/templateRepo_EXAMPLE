#!/usr/bin/env bash
# drift-sweep v0.1.28 — detect code/substrate drift in a repo.
#
# v0.1.28 (SESSION-093, 2026-08-16): `_bounded` polls instead of spawning a
# sleeping killer. v0.1.27 shipped the obvious `( sleep N; kill $pid ) &` form,
# which is correct but leaves the sleeper running for the rest of its N seconds
# every time the probe finishes fast — i.e. on every normal boot, since this runs
# from a SessionStart hook. A stray process per boot, still holding whatever
# descriptors it inherited. Polling costs 1-second granularity nobody can
# perceive and leaves nothing behind. Returns 124 on expiry, matching GNU
# timeout's convention. Bumped rather than amended because v0.1.27 was already
# pushed, and a version that means two different implementations is its own small
# version of the drift this file spent the day fixing.
#
# v0.1.27 (SESSION-093, 2026-08-16): `_bounded` — the network guard that was
# never actually there on this fleet's own machine.
#
# The backstop probe wrote `to="timeout 15"` when `timeout` or `gtimeout` was
# found and an EMPTY STRING otherwise, on the reasoning that we would then "fall
# through to gh's own HTTP timeout". Stock macOS ships NEITHER binary, this
# fleet's primary machine is a Mac, and `gh` has no whole-operation deadline —
# so on the box these guards were written for, there was no bound at all. Two of
# the three gh calls were unbounded even where `timeout` exists.
#
# It stopped being theoretical today: `wrap-gate.sh` — a SessionStart hook, so
# the BOOT PATH — ran past two minutes on a gh call and had to be killed by hand.
# Replaced with a bash-native watchdog (background, kill on expiry) that needs no
# coreutils, applied to all three gh calls and to the hook's own outer bound.
#
# Same species as the v0.1.23 `_mtime` bug: a portability assumption that made
# part of the mechanism silently absent on a real platform. Worse in one respect
# — there a CHECK could not run and reported nothing; here a GUARD could not run,
# and an absent guard produces no output at all until something hangs.
#
# v0.1.26 (SESSION-093, 2026-08-16): NEW `doc-version` category — the fleet
# gated code-vs-substrate drift and nothing gated code-vs-its-own-documentation.
#
# That gap has now cost the same thing twice. v0.1.19's own entry records the
# first: "the banner on line 2 of sweep.sh ... had read v0.1.15 through four
# releases, which is the same defect in miniature." The second was found hours
# ago, one file over: SKILL.md read "v0.1.21 (current)" through four releases
# while describing a one-token substitution rule (two since v0.1.24) and a plain
# COPY as always-a-warn (fails in the template since v0.1.25). It surfaced only
# because Wy asked whether anything else needed adjusting.
#
# A stale doc is worse than no doc. An agent reads SKILL.md to learn what the
# gate does, and a confidently wrong answer gets acted on.
#
# Checks ONLY version strings that claim currency — a `(current)` marker or one
# in a section heading. A changelog of historical entries is the doc working
# correctly and is never flagged; that false positive is what would make the
# category ignorable. Verified against the real historical state (the actual
# stale SKILL.md and the actual sweep.sh at 7b195a0), not a synthetic one.
#
# v0.1.25 (SESSION-093, 2026-08-16): the ladder REQUIRES template form in the
# template, and wrap-continuity stops asking the template a question it has no
# way to answer honestly.
#
# v0.1.24 made the template's copy correct. Two consequences of that were left
# open and are closed here:
#
#   1. The ladder PERMITTED `SUBST` but still PASSED a plain `COPY`. A plain copy
#      is precisely the shape that shipped the v0.1.24 defect — literal `{{AI}}ai`
#      in a file handed to someone whose AI is not named Chloe. In the template
#      that is not "in sync, merely unlinked", it is the bug. hook-canonical and
#      skill-canonical now fail it there and say how to regenerate. Elsewhere a
#      COPY stays a WARN, because elsewhere the invariant is a symlink.
#
#   2. `wrap-continuity` went red on the template the moment it could see it —
#      correctly, by its own rule, and meaninglessly. Both template carriers are
#      frozen SPECIMENS documenting the format; the template's real session
#      record lives in the workspace HANDOFF_LOG. The only way to satisfy the
#      check was to re-stamp a specimen to reset a counter. Documented exemption
#      instead, keyed to a condition that cannot survive seeding.
#
# Both hang off a new IS_TEMPLATE discriminator that requires TWO conditions,
# because init-project.sh's self-delete is a prompt defaulting to NO.
#
# v0.1.24 (SESSION-092-FOLLOWON, 2026-08-15): `template_form()` — ONE implementation
# of the canonical→template rule, and the rule now covers BOTH name tokens.
#
# templateRepo_EXAMPLE's sweep.sh was a PLAIN COPY carrying 45 literal `.{{AI}}ai`,
# so a repo seeded under a different AI name got a drift-sweep hunting for another
# AI's files: it would find nothing and report CLEAN. Silent-pass class, shipped to
# third parties. The old convention ("plain copy, because its {{AI}} strings are
# literal substitution logic") conflated *contains the placeholder as data* with
# *must not be genericized* — two different claims. Protecting 2 data sites by
# refusing 45 substitutions is what shipped the defect.
#
# Two things were wrong and both are fixed here:
#   1. The SUBST rule only substituted the AI token, never the HUMAN one, so a
#      template copy could satisfy the gate while hardcoding `hey{{HUMAN}}`. A gate that
#      checks one of two tokens passes files it should fail.
#   2. The gate and the re-sync were SEPARATE implementations. Caught mid-fix: a
#      plain `sed` over every line was the gate, while the re-sync skipped
#      substitution-rule lines, so a correctly-synced file read as DIVERGED. They
#      are now one function — the generator and the verifier cannot disagree.
#
# v0.1.23 (SESSION-092, 2026-08-15): portable `_mtime`. THE BACKSTOP'S FIRST GREEN
# CREDENTIAL IMMEDIATELY PAID FOR ITSELF.
#
# Minutes after the fleet token was finally accepted, the first real run failed six
# times across the fleet with `line 1022: File: unbound variable`. Cause: `stat -f %m`
# is BSD syntax; to GNU stat `-f` is FILESYSTEM mode, so `%m` is read as a filename.
# GNU stats the real file anyway, prints its filesystem block (`  File: "..."`) to
# stdout, and exits non-zero for the bad operand — so the `||` fallback ALSO runs and
# command substitution concatenates both. See the note on `_mtime` for the full chain.
#
# THE POINT IS NOT THE FLAG. The substrate-vs-code freshness category has been
# incapable of running on Linux since it was written, and no surface in this fleet
# could say so, because the only thing that runs it on Linux is the nightly CI that
# had never once authenticated. A category that cannot execute reports nothing, and
# nothing reads identically to clean. That is the same shape as the 17-day "skipping"
# capability gate, the zero-match owns glob, and the backstop's own silent death —
# and it was caught within the hour by the machine finally being allowed to look.
#
# v0.1.22 (SESSION-092, 2026-08-15): `--backstop-only` — the v0.1.21 probe, reachable
# from a boot.
#
# v0.1.21 built the backstop check and put it behind `--maintenance`. Five days later
# the backstop had failed FIFTEEN consecutive nights and still nobody had seen it,
# because nothing ever ran the check: the charter invokes the boot sweep only when the
# working tree is DIRTY, and its `--fail-on` list does not include maintenance. On
# 2026-08-14 the tree was clean, so the sweep did not run at all — the dead backstop
# surfaced only because a session went looking by hand.
#
# THE LESSON IS NOT ABOUT CI. Building the check and leaving it on a manual path
# reproduced, one release later, the very failure the check was written to catch: a
# mechanism that exists but is not wired to an edge anyone actually crosses. This flag
# emits just the backstop lines so the SessionStart wrap-gate — which runs
# unconditionally at EVERY boot, clean tree or not — can carry it.
#
# The hook calls this rather than carrying its own copy, and that is deliberate: see
# the note at the --backstop-only dispatch below.
#
# v0.1.21 (SESSION-091, 2026-08-10): `--maintenance` now reports BACKSTOP HEALTH.
#
# The nightly fleet-sweep workflow failed 10 times out of 10 between 2026-08-06 and
# 2026-08-10 — every run since it shipped — and nothing anywhere said so. The fleet
# read 0 FAIL / 0 WARN the whole time while its server-side backstop had never once
# executed a sweep. The credential was dead on arrival: a well-formed 40-char classic
# PAT rejected 401 within 34 seconds of being stored, the third to do exactly that.
#
# SAME failure class as the capability gate's 17-day "skipping", the four dead
# validation: fields and the zero-match owns glob — with one inversion that made it
# worse. Those rendered a broken state as a WRONG state, which is at least visible to
# anyone reading the output. This one rendered it as NO state: the only surface that
# knew was GitHub's web UI, and nothing in the fleet reads that. An unwatched check is
# indistinguishable from an absent one.
#
# Deliberately in --maintenance rather than as a gated category: this is the one probe
# in the script that leaves the machine, and a network call has no business in a
# pre-commit gate. Fenced hard — owning repo only, gh required AND authenticated,
# timeout where the platform offers one, and every failure path prints "could not
# check" rather than staying quiet. Reporting the inability to check IS the point; a
# silent skip would rebuild the exact hole this closes.
#
# v0.1.20 (SESSION-090, 2026-08-09): NEW VERSIONED_BACKUP_ALLOWLIST conf knob.
# The versioned-backup heuristic assumes a version in a filename means "stale copy".
# Sometimes the version IS the meaning. TFNerd pins SDK_INVENTORY_v1230_2026_05_19.md
# as the only surviving record of the PortalSDK v1.2.3.0 export surface — PortalSDK/ is
# gitignored and overwritten in place, five files cite the snapshot, and renaming it to
# satisfy the heuristic would destroy the version it exists to record. Same shape as the
# existing ORPHAN_EXPORT_ALLOWLIST: the repo DECLARES its exception instead of the check
# guessing, and the default ("^$") exempts nothing, so no repo's behavior changes until
# it opts in. Verified narrow: the declared regex exempts only dated SDK_INVENTORY
# snapshots under ai_context/audits/ and still warns on src/foo_v2.ts,
# ai_context/audits/NOTES_v2.md, and the same filename in another directory.
#
# (This banner read v0.1.15 through four releases while the changelog below moved on —
# corrected at v0.1.19. A version string that nothing checks is its own small instance
# of the failure this release exists to catch.)
#
# v0.1.19 (SESSION-090, 2026-08-09): NEW validation-liveness category (REPORT-ONLY).
# validation-age says how long since a card's validation: passed; it cannot say whether
# that command was ever CAPABLE of failing. Five fleet cards were not.
#
# Planitaria src/model carried `npx tsc --noEmit 2>&1 | grep … | head -5; echo done` —
# the status of `a; b` is b's, and echo always succeeds, so it returned 0 no matter what
# tsc found, for months, next to a real verified_at that made the card look maintained.
# Four PocketLink cards used `make build 2>&1 | tail -5`: a pipeline's status is its LAST
# stage, so tail masked make entirely — and there is no `build` target anyway, just a
# build/ DIRECTORY that make reports "up to date". Doubly dead.
#
# Same species as the capability gate that printed "skipping" for 17 days: a check whose
# failure path renders as success. STATIC ONLY — this reads shell grammar, it never
# executes a validation command (that would need every toolchain present and would have
# side effects). `grep` is deliberately absent from the filter list: grep exits 1 on
# no-match, so a terminal `| grep -q x` is a real assertion, not a mask.
# Report-only on purpose, matching how ownership-coverage and boot-source-size landed:
# collect real data first, set the gate from it later. Verified on a 13-case harness
# (6 dead / 7 live) and across all 57 fleet cards — 4 flagged, 0 false positives.
#
# v0.1.18 (SESSION-089, 2026-08-09): NEW skill-canonical category + `--maintenance`
# — the wy/chloe split.
#
# hook-canonical (v0.1.16) works because hooks have ONE right answer: be the
# canonical. Skills do not. templateRepo_EXAMPLE holds two real skill copies that
# look identical in kind and are opposites in intent: drift-sweep is a plain
# tracking copy (re-sync it; a zero-diff against the canonical of its era proved
# nothing would be lost), while validate-substrate is a DELIBERATE fork — fully
# genericized, with a filename resolver so the template self-validates both before
# and after init substitution. Copying canonical over that destroys real work.
#
# No inspection distinguishes them, so the repo DECLARES intent via
# CANONICAL_FORK_SKILLS in .claude/drift-sweep.conf. Undeclared divergence
# soft_fails, which forces exactly one question: re-sync, or declare a fork?
#
# `--maintenance` renders the outstanding upkeep BY DECISION-OWNER rather than by
# file — CHLOE for restoring a known invariant (relink, or re-sync the template's
# tracked copies, command printed), WY for a declared fork that has fallen behind
# and needs a hand merge. That distinction is the expensive one: mistaking a fork
# for a stale copy is how you silently delete engineering, and mistaking a stale
# copy for a fork is how the fleet lost its capability gate for 17 days.
# Read-only; always exits 0. Combine with --fleet.
#
# v0.1.17 (SESSION-089, 2026-08-09): probe-journal-in-diff exempts .claude/skills/
# — canonical tool headers carry a curated changelog, not iteration noise, and the
# check only ever fired on the template's sync path. See the exemption comment inline.
#
# v0.1.16 (SESSION-089, 2026-08-09): NEW hook-canonical category — nothing was
# watching the hooks.
#
# handoff-gate.sh was found forked in ALL ELEVEN repos, in three distinct stale
# versions, none of which had followed THR-020/ADR-012's 2026-07-23 rename of
# recommended_model= to recommended_capability=. The charter's B3 capability
# STOP-THE-LINE was therefore dead fleet-wide for ~17 days. It was invisible because
# the stale hook reported "no recommended_model= — skipping", and a skip is
# indistinguishable from a pass unless you go read the script.
#
# THE ASYMMETRY THAT EXPLAINS IT. Two artifacts live in .claude/. Skills are
# SYMLINKS to the workspace canonical and have never drifted. Hooks were COPIES and
# drifted into three versions. Same directory, same authors, same fleet — the only
# difference was the invariant. Hooks are now symlinked too; this check is the
# backstop for what a symlink cannot cover: a repo that de-symlinks, and
# templateRepo_EXAMPLE, which must hold real files because it ships {{AI}}
# placeholders substituted at seed time.
#
# Ladder: linked to canonical (-ef) → pass; byte-identical after {{AI}} substitution
# → pass (template); byte-identical unlinked COPY → WARN, because that is exactly the
# state the fleet was in before it rotted; anything else → soft_fail. Graceful pass
# when no canonical is reachable, same dangle posture as the symlinked skill.
#
# v0.1.15 (SESSION-087, 2026-08-07): BRANCH VISIBILITY + boot-source deliverability.
#
# THE BRANCH GAP. Twice in one session a commit landed on an unexpected branch —
# substrate onto OperationFarmstock's assembly-viewer branch, card curation onto
# PocketLink's m14 branch — both because the session checked `git status` and never
# `git branch`. Status cannot surface this: it reports a clean tree on the WRONG
# branch exactly as happily as on the right one. Flagging it in a handoff did not
# prevent the second occurrence, which makes it a mechanism gap rather than an
# attention problem. Two layers: (1) the sweep header now always prints BRANCH, and
# marks it when it is not the default — this survives --quiet, so it appears at every
# pre-commit in every repo, at the moment the mistake is made rather than at boot;
# (2) a `branch-context` WARN when repo-GOVERNING files (lefthook.yml, .claude/**,
# CLAUDE.md, AGENTS.md, STARTUP_AI) are staged off the default branch, where they stay
# inert until merge. Deliberately not a blanket "you are on a branch" warning (fires on
# every feature commit, tuned out in a day) and deliberately excluding _waystone cards
# (freshness REQUIRES them to move with owned code on feature branches — warning on
# them would punish behaviour another gate mandates).
#
# BOOT-SOURCE DELIVERABILITY. Which declared boot sources are physically too large to
# ever arrive whole? The packet allocates max_chars // max_files per entry, so a file
# above that ceiling is ALWAYS truncated — and a truncated file reads exactly like a
# complete one unless the caller checks the warning. Neither existing size check can
# see this: tier1-bloat warns at 25 KB while the per-entry share is 4,096 (they
# disagree by 6x, so a 17 KB always-loaded doc passes tier1-bloat while delivering 23%
# of itself forever — PocketLink's CURRENT_MISSION.md, found exactly this way), and
# seam-coverage does not look at sizes at all. REPORT-ONLY: over-cap is not always
# wrong, since some files are essential AND big, and the fix there is to shrink the
# FILE rather than stop declaring it.
#
# v0.1.14 (SESSION-087, 2026-08-07): NEW FILES ARE NO LONGER COUNTED AS CHURN, and
# NEW ownership-coverage category (REPORT-ONLY).
#
# THE CHURN FIX. `working-tree` targets ITERATIVE accumulation — one file edited over
# and over uncommitted, where the record of each iteration is what is lost. But
# `git diff --shortstat HEAD` counts a new file's ENTIRE BODY as insertions, so ADDING
# read identically to CHURNING. That made the gate unsatisfiable rather than strict:
# a single 1,149-line stylesheet cannot be split, so the smallest commit containing it
# was already over threshold and --no-verify was STRUCTURALLY REQUIRED for honest work.
# The gate was manufacturing the bypass habit it exists to prevent (DEC-103). Added
# files are now excluded from the threshold and reported on their own line — the same
# treatment lockfiles already had. Verified both directions: a new 1,149-line file
# passes; churning that same file by 1,149 lines still FAILS at 2,298.
#
# OWNERSHIP COVERAGE. Ratifies seam-coverage-definition.{{AI}}ai §4. `seam-coverage`
# compares two hand-maintained lists and reports their agreement — it cannot see a
# folder nobody declared. This measures what share of tracked source falls under SOME
# card's `owns`, derived from the cards plus git with no hand-maintained input. Fleet
# baseline at adoption: 23% (OperationFarmstock 0 of 54, Planitaria 5%, PocketLink 6%,
# planTheBeast 49%, TFNerd 94%) against the old metric's 100%. REPORT-ONLY, per §5.
#
# v0.1.13 (SESSION-087, 2026-08-07): SPLIT the overloaded verified_at, and two new
# REPORT-ONLY categories.
#
# THE SPLIT. `verified_at` meant two different things at once — "the validation:
# command passed" and "a human re-read this folder and confirms owns still describes
# it" — and only the second is what the freshness gate reports. That overload is why
# auto-stamping kept looking attractive: it would have killed the re-stamp tax
# (OperationFarmstock burned five commits doing nothing else) by quietly downgrading
# what the stamp CERTIFIES, leaving a gate that says "a human checked" when a script
# ran. Now: `reviewed_at` is the human stamp and the gate prefers it, falling back to
# `verified_at`, which is permanently supported — NO card needs migrating, and every
# existing card keeps working untouched. `validated_at` is the machine stamp, safe to
# auto-stamp because it claims only that a script exited 0, and the freshness gate
# never reads it. Verified all three paths on a scratch repo before shipping:
# reviewed_at preferred, verified_at fallback, neither -> FAIL + exit 1.
#
# NEW continuity-age category, REPORT-ONLY.
# `continuity:` is the prose that tells the next agent what a folder's story is, and
# nothing ever timestamped it — `verified_at` certifies the OWNS globs were reconciled
# with the code, which is a different claim, and the two drift apart in both directions.
# Emits `pass` lines only: no warn, no fail, no --fail-on token, no threshold, and
# nothing at all under --quiet (so no lefthook gets noisier). Deliberately inert while
# ages accumulate across the fleet — a guessed threshold produces a gate that fires
# wrong, and one that fires wrong gets ignored. Arm it from data, not from a number
# that felt right. Same rollout discipline as seam-coverage-definition.{{AI}}ai §5.
#
# v0.1.12 (SESSION-085, 2026-08-06): waystone-validity also checks the hey{{HUMAN}} DOORWAY.
# A root card with a `hey{{HUMAN}}:` inscription is written for a human; ./_waystone.hey{{HUMAN}}
# is how it gets read. The workspace root carried an inscription and no doorway for
# weeks and nothing noticed. Folded into waystone-validity rather than given its own
# category so it inherits an already-armed gate — validate-substrate runs in NO
# lefthook fleet-wide, so a check there would have been inert.
#
# v0.1.11 (SESSION-085, 2026-08-06): NEW waystone-validity category — does the
# card actually PARSE? Every other WISL gate is a grep/awk extractor and presumes
# the card loads. OperationFarmstock's root waystone was unparseable for four days
# and thirteen commits (literal inch marks inside a double-quoted YAML scalar);
# the registry silently dropped it, that repo had no WISL route and no hey{{HUMAN}}
# doorway, five of those commits existed only to re-stamp verified_at on it, and
# every gate stayed green the whole time. Replicates parse_waystone() exactly.
# Optional layered parser (python3+PyYAML, then ruby/psych — verified to agree on
# all 41 fleet cards); WARNs rather than fails when neither exists, so no other
# category gains a YAML dependency. Hard fail(): an unparseable card is broken,
# not a matter of taste.
#
# v0.1.10 (Wy-authorized 2026-07-05): the working-tree churn measure now
# EXCLUDES machine-generated lockfiles (CHURN_EXCLUDE_LOCKFILES, overridable in
# drift-sweep.conf). Lockfiles rewrite in bulk on any dependency change — a
# semver-major upgrade rewrites ~2000 lines nobody hand-reviews line-by-line —
# so they systematically false-positived DIFF_FAIL_THRESHOLD (found: Planitaria
# vite8/vitest4 upgrade, SESSION-064). The gate now measures human-authored
# churn only; lockfiles still count as dirty files and pass every other gate.
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
#                              orphans, mission-freshness, claude-md, waystone-validity,
#                              waystone-freshness, up-sync, wrap-continuity, wisl-graph,
#                              seam-coverage
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
#   VERSIONED_BACKUP_ALLOWLIST — regex of PATHS exempt from the versioned-backup warn
#                               (default "^$"). For files whose version IS the meaning —
#                               a pinned snapshot of an external surface — not a stale copy.
#   BACKSTOP_WORKFLOW         — CI workflow whose health --maintenance reports (default
#                               "fleet-sweep.yml"). Only checked in the repo that
#                               actually contains .github/workflows/<it>.
#   BACKSTOP_STALE_DAYS       — age of the newest run past which the backstop is called
#                               stale even if it succeeded (default 2; the schedule is
#                               nightly, and GitHub silently disables cron on inactive
#                               repos, which is itself a way for this to die quietly)
#   BACKSTOP_CHECK            — set 0 to skip the one network probe entirely (default 1)
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

SELF="${BASH_SOURCE[0]}"
FLEET_MODE=0
MAINTENANCE_MODE=0
BACKSTOP_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON_OUTPUT=1; shift ;;
    --quiet) QUIET_OUTPUT=1; shift ;;
    --fleet) FLEET_MODE=1; shift ;;
    --maintenance) MAINTENANCE_MODE=1; shift ;;
    --backstop-only) BACKSTOP_ONLY=1; shift ;;
    --fail-on=*) FAIL_ON_CATEGORIES="${1#--fail-on=}"; shift ;;
    -*) echo "Unknown flag: $1" >&2; exit 1 ;;
    *) REPO="$1"; shift ;;
  esac
done

# ── Fleet mode ────────────────────────────────────────────────
# Explicit opt-in to iterate a workspace root, sweeping each child repo in its
# OWN root — the only context where that repo's card paths resolve.
if [ "$FLEET_MODE" = "1" ]; then
  cd "$REPO" || { echo "Cannot enter $REPO" >&2; exit 2; }
  _fleet_rc=0
  _pass=""
  [ "$JSON_OUTPUT" = "1" ] && _pass="$_pass --json"
  [ "$QUIET_OUTPUT" = "1" ] && _pass="$_pass --quiet"
  [ -n "$FAIL_ON_CATEGORIES" ] && _pass="$_pass --fail-on=$FAIL_ON_CATEGORIES"
  [ "$MAINTENANCE_MODE" = "1" ] && _pass="$_pass --maintenance"
  for _d in */; do
    _r="${_d%/}"
    [ -d "$_r/.git" ] || continue
    echo "════════ $_r ════════"
    # shellcheck disable=SC2086
    SWEEP_FLEET_CHILD=1 bash "$SELF" $_pass "$_r" || _fleet_rc=1
    echo
  done

  # THE CONTROL PLANE IS NOT A CHILD OF THE WORKSPACE ROOT. It lives at
  # ~/repoManager, deliberately outside the fleet root (and outside iCloud), and is
  # reached only through symlinks — so the `for _d in */` loop above can never see it.
  # That was nearly a repeat of the bug this release fixes: v0.1.21's backstop check
  # only runs in the repo that OWNS the workflow, and that repo is the one the fleet
  # pass structurally cannot reach. The mechanism would have existed, reported
  # correctly when invoked by hand, and fired for nobody. Resolve it from the
  # canonical skills dir and include it explicitly.
  #
  # MAINTENANCE ONLY, on purpose: pulling it into the gated sweep would change
  # fleet-wide failure counts that CI and the boot banner key off, which is a
  # different decision and not this one.
  if [ "$MAINTENANCE_MODE" = "1" ] && [ -d .claude/skills ]; then
    _sub=$(cd .claude/skills 2>/dev/null && pwd -P) || _sub=""
    _sub="${_sub%/.claude/skills}"
    _here=$(pwd -P)
    case "$_sub" in
      "$_here"|"$_here"/*) _sub="" ;;   # already covered by the loop above
    esac
    if [ -n "$_sub" ] && [ -d "$_sub/.git" ]; then
      echo "════════ $(basename "$_sub") (control plane — outside the workspace root) ════════"
      # shellcheck disable=SC2086
      SWEEP_FLEET_CHILD=1 bash "$SELF" $_pass "$_sub" || _fleet_rc=1
      echo
    fi
  fi
  exit "$_fleet_rc"
fi

cd "$REPO" || { echo "Cannot enter $REPO" >&2; exit 2; }

# ── Container guard ───────────────────────────────────────────
# This is a PER-REPO tool. Aimed at a directory that is not itself a git repo
# but CONTAINS git repos (the ~/GitHub workspace root), the wisl-graph walker
# finds every child repo's cards and resolves their repo-RELATIVE `depends_on:`
# / `boot_path:` edges against the CONTAINER — reporting hundreds of "dangling
# edge" warnings for edges that resolve perfectly well in their own repo.
# (Measured 2026-07-31: 334 such warnings from the workspace root, all bogus.)
# Refuse rather than emit a confident wrong answer.
#
# Discriminator: not a git repo, yet holding git children. drift-sweep
# legitimately runs on genuine non-git folders (it degrades per-category), and
# those have no git children, so this fires only on the container mistake.
if [ ! -d .git ] && [ "${SWEEP_FLEET_CHILD:-0}" != "1" ]; then
  _child_repos=0
  for _d in */; do
    [ -d "${_d}.git" ] && _child_repos=$((_child_repos + 1))
  done
  if [ "$_child_repos" -ge 2 ]; then
    echo "REFUSING: $(pwd)" >&2
    echo "  is not a git repo, but contains $_child_repos git repos." >&2
    echo "  drift-sweep is a PER-REPO tool: run it inside a repo," >&2
    echo "  or use '--fleet' to iterate each child repo in its own root." >&2
    echo "  (Results from here would be path-confusion artifacts, not drift.)" >&2
    exit 2
  fi
fi

# ── Defaults + optional config ────────────────────────────────
CONFIG=".claude/drift-sweep.conf"
[ -f "$CONFIG" ] && source "$CONFIG"

CODE_ROOTS="${CODE_ROOTS:-src lib}"
EXCLUDE_FILES="${EXCLUDE_FILES:-}"
DIFF_FAIL_THRESHOLD="${DIFF_FAIL_THRESHOLD:-1000}"
CHURN_EXCLUDE_LOCKFILES="${CHURN_EXCLUDE_LOCKFILES:-package-lock.json yarn.lock pnpm-lock.yaml bun.lock bun.lockb Cargo.lock poetry.lock uv.lock Gemfile.lock composer.lock Package.resolved}"
DIRTY_FILES_WARN="${DIRTY_FILES_WARN:-10}"
JOURNAL_DIFF_LINES_FAIL="${JOURNAL_DIFF_LINES_FAIL:-3}"
JOURNAL_HEADER_SCAN="${JOURNAL_HEADER_SCAN:-80}"
JOURNAL_HEADER_FAIL="${JOURNAL_HEADER_FAIL:-5}"
MISSION_STALE_DAYS="${MISSION_STALE_DAYS:-14}"
# Skills under .claude/skills/ that are DELIBERATE forks of the workspace
# canonical rather than copies expected to track it. A fork is never a drift
# failure and is never auto-synced — it surfaces as a WY decision. Everything
# not listed here is expected to track the canonical. See the skill-canonical
# category and `--maintenance`.
CANONICAL_FORK_SKILLS="${CANONICAL_FORK_SKILLS:-}"
ORPHAN_EXPORT_ALLOWLIST="${ORPHAN_EXPORT_ALLOWLIST:-^$}"
VERSIONED_BACKUP_ALLOWLIST="${VERSIONED_BACKUP_ALLOWLIST:-^$}"
BACKSTOP_WORKFLOW="${BACKSTOP_WORKFLOW:-fleet-sweep.yml}"
BACKSTOP_STALE_DAYS="${BACKSTOP_STALE_DAYS:-2}"
BACKSTOP_CHECK="${BACKSTOP_CHECK:-1}"
SOURCE_EXTENSIONS="${SOURCE_EXTENSIONS:-ts tsx js py rs go swift}"
TIER1_FILES="${TIER1_FILES:-readme_AI.{{AI}}ai CLAUDE.md ai_context/ai_rules.{{AI}}ai ai_context/glossary.{{AI}}ai ai_context/CURRENT_MISSION.md ai_context/START_HERE.md}"
TIER1_BLOAT_WARN_KB="${TIER1_BLOAT_WARN_KB:-25}"
WRAP_CARRIER="${WRAP_CARRIER:-}"
WRAP_LAG_WARN="${WRAP_LAG_WARN:-10}"

# ── Is THIS repo the template? (v0.1.25) ──────────────────────
# templateRepo_EXAMPLE is not a project; it is the blueprint projects are cut
# from. Two categories have to answer differently here, and both were answering
# wrong until 2026-08-16 (see hook-canonical / skill-canonical and
# wrap-continuity below for what each one does with this).
#
# TWO CONDITIONS, not one. init-project.sh's self-delete is a PROMPT DEFAULTING
# TO NO, so its mere presence does not mean "template" — a real seeded repo
# whose owner pressed Enter still has it. The second condition cannot survive
# seeding: init renames every `*.{{AI}}ai` and `*.hey{{HUMAN}}` file
# unconditionally, no prompt. Relaxing a gate on a repo that needs the strict
# version is the silent-pass class, so the discriminator has to be the one that
# a seeded repo cannot accidentally satisfy.
IS_TEMPLATE=0
if [ -f init-project.sh ]; then
  if compgen -G '*.{{AI}}ai' >/dev/null 2>&1 || compgen -G '*.hey{{HUMAN}}' >/dev/null 2>&1; then
    IS_TEMPLATE=1
  fi
fi

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

# ── Canonical-tracking helpers (v0.1.18) ──────────────────────
# Shared by hook-canonical, skill-canonical, and --maintenance so the three can
# never disagree about what "matches the canonical" means.

# canonical_dir <hooks|skills> — echo the workspace canonical dir; rc=1 if unreachable.
canonical_dir() {
  local kind="$1" top cand
  top=$(git rev-parse --show-toplevel 2>/dev/null || true)
  for cand in "${top:+${top}/../.claude/${kind}}" "${HOME}/GitHub/.claude/${kind}"; do
    [ -n "$cand" ] && [ -d "$cand" ] && { printf '%s' "$cand"; return 0; }
  done
  return 1
}

# canonical_state <local_file> <canonical_file> — echo one of:
#   LINKED   symlink/hardlink to canonical — the intended state in a real repo
#   SUBST    byte-identical after BOTH name substitutions — the sanctioned template form:
#            chloeai -> {{AI}}ai AND heywy -> hey{{HUMAN}}. The second half was added
#            2026-08-15 (SESSION-092-FOLLOWON). The rule had only ever covered the AI
#            token, so a template copy could satisfy it while still hardcoding the HUMAN
#            one — and templateRepo's sweep.sh did exactly that, carrying 18 literal
#            human-token refs. A gate that checks one of two tokens passes files it
#            should fail.
#   COPY     byte-identical unlinked copy
#   DIVERGED differs in a way substitution does not explain
#   NOCANON  no canonical counterpart (repo-local file)
# Render a canonical file into the sanctioned TEMPLATE form.
#
# THE ONE IMPLEMENTATION OF THE RULE. Whoever re-syncs the template must produce
# exactly this, and the SUBST check below verifies against exactly this — one
# function, so the generator and the gate cannot disagree. They did disagree while
# this was being written: a plain `sed` over every line was the gate, while the
# re-sync skipped rule lines, so a correctly-synced file read as DIVERGED.
#
# WHY SOME LINES ARE SKIPPED. A line mentioning BOTH a literal token and its
# placeholder is a substitution rule, or prose describing one. Rewriting it turns
# `s/chloeai/{{AI}}ai/g` into `s/{{AI}}ai/{{AI}}ai/g` — a no-op that silently
# disables the template's own canonicality gate. The exception is small and exact:
# it is not "leave the file alone", which is the reasoning that shipped a template
# sweep.sh hunting for another AI's files.
template_form() {
  awk '
    ($0 ~ /{{AI}}ai/ && $0 ~ /\{\{AI\}\}ai/) ||
    ($0 ~ /hey{{HUMAN}}/   && $0 ~ /hey\{\{HUMAN\}\}/) { print; next }
    { gsub(/chloeai/, "{{AI}}ai"); gsub(/heywy/, "hey{{HUMAN}}"); print }
  ' "$1"
}

canonical_state() {
  local lf="$1" cf="$2"
  [ -f "$cf" ] || { echo NOCANON; return; }
  [ -e "$lf" ] || { echo DIVERGED; return; }
  [ "$lf" -ef "$cf" ] && { echo LINKED; return; }
  diff -q <(template_form "$cf") "$lf" >/dev/null 2>&1 && { echo SUBST; return; }
  diff -q "$cf" "$lf" >/dev/null 2>&1 && { echo COPY; return; }
  echo DIVERGED
}

# is_declared_fork <skill-name> — true when this repo declares the skill a
# DELIBERATE fork of the canonical (CANONICAL_FORK_SKILLS in drift-sweep.conf).
is_declared_fork() {
  local n="$1" s
  for s in ${CANONICAL_FORK_SKILLS:-}; do [ "$s" = "$n" ] && return 0; done
  return 1
}

# ── Maintenance mode (v0.1.18) ────────────────────────────────
# `--maintenance` answers one question the normal sweep deliberately does not:
# of the substrate upkeep outstanding here, WHICH PART CAN CHLOE JUST DO, and
# which part needs Wy?
#
# That split is not cosmetic. SESSION-089 spent a session on canonical drift and
# the single most expensive judgement in it was telling a stale COPY (re-sync,
# mechanical, no information lost) apart from a deliberate FORK (hand merge; a
# copy destroys real work). Getting that wrong silently is how the fleet lost its
# capability gate for 17 days. So the report sorts by decision-owner, not by file:
#
#   CHLOE — restoring a KNOWN invariant: relink a hook or skill where a symlink
#           is intended, or re-sync the seed template's tracked copies. The exact
#           command is printed. Nothing here needs a human to think.
#   WY    — a DECLARED FORK has fallen behind canonical. There is no safe
#           mechanical answer: a copy would destroy the fork's own work, so it
#           needs a hand merge. This column is kept scarce on purpose — if
#           everything lands in it, the split has stopped meaning anything.
#
# Read-only and always exits 0 — it reports, it never mutates. Combine with
# --fleet to sweep every child repo.
# Health of the server-side CI backstop. Returns lines on stdout, never fails.
#
# WHY IT REPORTS "COULD NOT CHECK" INSTEAD OF SKIPPING QUIETLY: this whole category
# exists because absence of signal got read as health for four days. If gh is missing,
# logged out, or the network is down, that is a DIFFERENT state from "green" and must
# not print like it. The one thing this must never do is stay silent.
# _bounded <seconds> <command...> — run a command with a hard wall-clock bound.
#
# THE GUARD THAT WASN'T THERE (v0.1.27, 2026-08-16). This used to be
# `to="timeout 15"` when `timeout` or `gtimeout` was found, and an EMPTY STRING
# otherwise — with a comment saying we then "fall through to gh's own HTTP
# timeout". Stock macOS has neither binary, and this fleet's primary machine is
# a Mac: on the box this was written for, the bound was simply absent. It stopped
# being theoretical today, when `wrap-gate.sh` — a SessionStart hook, so this is
# the BOOT PATH — ran past two minutes on a `gh` call and had to be killed by
# hand. `gh`'s own timeout did not save it, because `gh` has no default deadline
# for the whole operation.
#
# Same species as the `_mtime` bug in v0.1.23: a portability assumption that made
# a piece of the mechanism silently absent on a real platform. Worse in one way —
# there, a CHECK could not run and reported nothing; here a GUARD could not run,
# and an absent guard has no output at all until something hangs.
#
# The fallback POLLS rather than spawning a sleeping killer. The obvious
# `( sleep N; kill $pid ) &` watchdog works, but when the probe finishes fast —
# the normal case — that sleeper LINGERS for the rest of its N seconds. In a
# SessionStart hook that is a stray process left behind on every single boot,
# still holding whatever descriptors it inherited. Polling costs a 1-second
# granularity nobody here can perceive and leaves nothing running.
_bounded() {
  local secs="$1"; shift
  if command -v timeout >/dev/null 2>&1; then timeout "$secs" "$@"; return $?; fi
  if command -v gtimeout >/dev/null 2>&1; then gtimeout "$secs" "$@"; return $?; fi
  "$@" &
  local pid=$! waited=0
  while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt "$secs" ]; do
    sleep 1; waited=$((waited + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill -TERM "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    return 124                      # same convention GNU timeout uses
  fi
  wait "$pid" 2>/dev/null
  return $?
}

backstop_report() {
  local wf="${BACKSTOP_WORKFLOW}"
  [ "${BACKSTOP_CHECK}" = "1" ] || return 0
  [ -f ".github/workflows/${wf}" ] || return 0   # not the repo that owns the backstop

  if ! command -v gh >/dev/null 2>&1; then
    printf '    backstop %s: COULD NOT CHECK — gh not installed\n' "$wf"; return 0
  fi
  if ! _bounded 10 gh auth status >/dev/null 2>&1; then
    printf '    backstop %s: COULD NOT CHECK — gh not authenticated (gh auth login)\n' "$wf"; return 0
  fi

  local slug runs
  slug=$(_bounded 15 gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null) || slug=""
  [ -n "$slug" ] || { printf '    backstop %s: COULD NOT CHECK — no GitHub remote resolved\n' "$wf"; return 0; }

  # ONE call, and gh's OWN --jq does the aggregation — no external jq dependency and
  # no second round-trip. Emitting a single tab-separated line keeps the shell side to
  # a plain read: a captured JSON blob cannot be re-filtered by gh afterwards.
  local errf; errf=$(mktemp 2>/dev/null || echo /tmp/ds_backstop.$$)
  runs=$(_bounded 15 gh run list --repo "$slug" --workflow="$wf" --limit 20 \
           --json conclusion,createdAt,databaseId \
           --jq '"\(.[0].conclusion // "in_progress")\t\(.[0].createdAt)\t\(.[0].databaseId)\t\([.[]|select(.conclusion!="success")]|length)\t\([.[]|select(.conclusion=="success")]|length)\t\(length)"' \
           2>"$errf") || runs=""
  local errtxt; errtxt=$(head -c 300 "$errf" 2>/dev/null); rm -f "$errf"

  if [ -z "$runs" ]; then
    # A 404 is a DIFFERENT diagnosis from a network failure and points at a specific
    # cause: gh resolves workflows by the DEFAULT BRANCH, so a workflow committed but
    # not pushed, or living only on a feature branch, reads as absent. Saying "could
    # not check" there would send someone hunting a network problem they do not have.
    case "$errtxt" in
      *404*|*"not found"*)
        printf '    backstop %s: NOT FOUND on GitHub — gh resolves workflows on the DEFAULT BRANCH, so this is unpushed, on another branch, or renamed\n' "$wf" ;;
      *)
        printf '    backstop %s: COULD NOT CHECK — gh run list failed%s\n' "$wf" "${errtxt:+ (${errtxt%%$'\n'*})}" ;;
    esac
    return 0
  fi

  local last_c last_at last_id nfail nsucc ntot age_d
  IFS=$'\t' read -r last_c last_at last_id nfail nsucc ntot <<EOF
$runs
EOF

  # Known to GitHub but zero runs. For a SCHEDULED workflow this is its own failure
  # mode — cron that never fired — and it is invisible precisely because there is no
  # red run to notice.
  if [ "${ntot:-0}" = "0" ]; then
    printf '    backstop %s: has NEVER RUN — the workflow exists on GitHub but no run has ever started\n' "$wf"
    return 0
  fi

  age_d=$(_days_since_iso "$last_at")

  if [ "$last_c" = "success" ]; then
    if [ -n "$age_d" ] && [ "$age_d" -gt "${BACKSTOP_STALE_DAYS}" ]; then
      printf '    backstop %s: last run PASSED but %sd ago (> %sd) — the nightly schedule may have stopped firing\n' \
        "$wf" "$age_d" "${BACKSTOP_STALE_DAYS}"
    fi
    return 0                                    # green and current — say nothing
  fi

  # Red. Distinguish "broke recently" from "never worked": different problems, and
  # the second is the one that hides, because there is no green run to have lost.
  if [ "$nsucc" = "0" ]; then
    printf '    backstop %s: RED — last run %s %sd ago; %s of the last %s runs failed, with NO success on record.\n' \
      "$wf" "$last_c" "${age_d:-?}" "$nfail" "$ntot"
    printf '      A backstop that has never once succeeded is not protecting anything.  gh run view %s --log-failed\n' "$last_id"
  else
    printf '    backstop %s: RED — last run %s %sd ago (%s of last %s failed).  gh run view %s --log-failed\n' \
      "$wf" "$last_c" "${age_d:-?}" "$nfail" "$ntot" "$last_id"
  fi
}

# Modification time of a file as a unix epoch integer, on BSD and GNU alike.
#
# WHY THIS IS A FUNCTION AND NOT THE ONE-LINER IT REPLACED. The old idiom was
#   mt=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)
# which is correct ONLY on BSD. `-f` means "format" to BSD stat but "filesystem
# mode" to GNU stat, so on Linux `%m` is read as a FILENAME operand: GNU stats the
# real file anyway, prints its filesystem block — which begins `  File: "..."` — to
# STDOUT, and exits non-zero because the `%m` operand does not exist. The `||` then
# fires too, and command substitution concatenates BOTH outputs. The caller gets
# `File: "..."` glued to a number, and `$((newest_code - sub_mt))` dies on the
# bareword: `line 1022: File: unbound variable`.
#
# FOUND BY THE BACKSTOP'S FIRST-EVER SUCCESSFUL RUN (2026-08-15). It fired six times
# across the fleet. The whole substrate-vs-code freshness category has been incapable
# of running on Linux since it was written, and nothing could report that, because
# the only thing that executes this on Linux is the nightly CI that had never once
# authenticated. Exactly the class this backstop exists to catch, caught the hour it
# started working.
#
# The load-bearing fix is the NUMERIC VALIDATION, not the flag order: a fallback
# chain that accepts whatever lands on stdout is unsafe no matter which form runs
# first, because a failing stat can print AND fail. Each candidate must look like an
# integer before it is believed.
_mtime() {
  local m
  m=$(stat -c %Y "$1" 2>/dev/null) || m=""
  case "$m" in ''|*[!0-9]*) m="" ;; esac
  if [ -z "$m" ]; then
    m=$(stat -f %m "$1" 2>/dev/null) || m=""
    case "$m" in ''|*[!0-9]*) m="" ;; esac
  fi
  printf '%s' "${m:-0}"
}

# Whole days between an ISO-8601 UTC timestamp and now. BSD and GNU date take
# incompatible parse flags, so try both and print nothing if neither works —
# callers treat empty as "unknown age" rather than as zero.
_days_since_iso() {
  local iso="$1" then now
  then=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s 2>/dev/null) \
    || then=$(date -u -d "$iso" +%s 2>/dev/null) || return 0
  now=$(date -u +%s)
  echo $(( (now - then) / 86400 ))
}

# ── --backstop-only ───────────────────────────────────────────
# Emit JUST the backstop health lines and exit 0. Exists so the SessionStart
# wrap-gate can surface a dead backstop at EVERY boot without running a full sweep
# and without carrying its own copy of the probe.
#
# WHY A FLAG AND NOT A COPY IN THE HOOK: this is the SESSION-089 lesson applied
# before it can bite again. Skills are symlinks to one canonical file and have never
# drifted; hooks were copies and rotted into three versions across eleven repos while
# reporting "skipping", which reads as a pass. A second implementation of this probe
# living in wrap-gate.sh would be a new copy with no invariant holding it to this one.
#
# Prints nothing at all when the backstop is green and current, when this is not the
# repo that owns the workflow, or when BACKSTOP_CHECK=0 — the caller treats empty
# output as "nothing to say" and stays silent too.
if [ "$BACKSTOP_ONLY" = "1" ]; then
  cd "$REPO" 2>/dev/null || exit 0
  backstop_report
  exit 0
fi

maintenance_report() {
  local repo_label; repo_label=$(basename "$(pwd)")
  local chloe_lines="" wy_lines=""
  local backstop_lines; backstop_lines=$(backstop_report)

  local ch; ch=$(canonical_dir hooks) || ch=""
  if [ -n "$ch" ] && [ -d .claude/hooks ]; then
    local hf hb st
    for hf in .claude/hooks/*.sh; do
      [ -e "$hf" ] || continue
      hb=$(basename "$hf"); st=$(canonical_state "$hf" "$ch/$hb")
      # The RESTORE differs by repo kind, so the renderer has to branch the same
      # way the gate does. In the template the answer is never "symlink it" —
      # the template must hold real files — it is "regenerate in template form".
      # A renderer that prescribed a symlink here would hand Chloe an action that
      # breaks the very thing the gate is protecting.
      case "$st" in
        DIVERGED)
          if [ "$IS_TEMPLATE" -eq 1 ]; then
            chloe_lines="${chloe_lines}    hook ${hb} DIVERGED -> regenerate from ${ch}/${hb} in template form"$'\n'
          else
            chloe_lines="${chloe_lines}    hook ${hb} DIVERGED -> ln -sf ../../../.claude/hooks/${hb} ${hf}"$'\n'
          fi ;;
        COPY)
          if [ "$IS_TEMPLATE" -eq 1 ]; then
            chloe_lines="${chloe_lines}    hook ${hb} is a PLAIN COPY (literal {{AI}}ai/hey{{HUMAN}}) -> regenerate from ${ch}/${hb} in template form"$'\n'
          else
            chloe_lines="${chloe_lines}    hook ${hb} unlinked copy (in sync) -> ln -sf ../../../.claude/hooks/${hb} ${hf}"$'\n'
          fi ;;
        NOCANON)  wy_lines="${wy_lines}    hook ${hb} has NO canonical counterpart — repo-local hook, or the canonical lost it"$'\n' ;;
      esac
    done
  fi

  local cs; cs=$(canonical_dir skills) || cs=""
  if [ -n "$cs" ] && [ -d .claude/skills ]; then
    local sd sn cf cb behind drift
    for sd in .claude/skills/*; do
      [ -e "$sd" ] || continue
      sn=$(basename "$sd"); [ -d "$cs/$sn" ] || continue
      if is_declared_fork "$sn"; then
        behind=0
        for cf in "$cs/$sn"/*; do
          [ -f "$cf" ] || continue
          [ "$(canonical_state "$sd/$(basename "$cf")" "$cf")" = "DIVERGED" ] && behind=1
        done
        [ "$behind" = "1" ] && wy_lines="${wy_lines}    skill ${sn} is a DECLARED FORK behind canonical — hand merge, never a sync"$'\n'
        continue
      fi
      [ -L "$sd" ] && [ "$sd" -ef "$cs/$sn" ] && continue
      drift=""
      for cf in "$cs/$sn"/*; do
        [ -f "$cf" ] || continue
        cb=$(basename "$cf")
        case "$(canonical_state "$sd/$cb" "$cf")" in
          LINKED|SUBST) : ;;
          # Mirrors the gate: a plain COPY is fine in a real repo, and is drift
          # in the template. The renderer and the gate must agree about what
          # needs doing — they disagreed once already (v0.1.24) and it cost a
          # false DIVERGED.
          COPY) [ "$IS_TEMPLATE" -eq 1 ] && drift="${drift} ${cb}" ;;
          *) drift="${drift} ${cb}" ;;
        esac
      done
      if [ -n "$drift" ]; then
        # A TRACKED skill that drifted is mechanical, not a decision — the only
        # question is which restore applies. The seed template is the one
        # sanctioned copy-holder (it ships {{AI}} placeholders that init
        # substitutes), so there the restore is a re-sync; everywhere else the
        # invariant is a symlink and the restore is a relink.
        if [ "$IS_TEMPLATE" -eq 1 ]; then
          chloe_lines="${chloe_lines}    skill ${sn} behind canonical (${drift# }) -> re-sync from ${cs}/${sn}, applying chloeai -> {{AI}}ai AND heywy -> hey{{HUMAN}}, EXCEPT on lines carrying or describing a substitution rule"$'\n'
        else
          chloe_lines="${chloe_lines}    skill ${sn} unlinked and DIVERGED (${drift# }) -> ln -sf ../../../.claude/skills/${sn} ${sd}"$'\n'
        fi
      fi
    done
  fi

  echo
  echo "══ MAINTENANCE — ${repo_label} ══"
  # Printed FIRST and in its own band. A dead backstop is not one item among several
  # — it is the reason every other line in every other repo's report should be trusted
  # less, because nothing has been re-checking them server-side.
  if [ -n "$backstop_lines" ]; then
    echo "  BACKSTOP (server-side CI — this is what catches a bypassed local gate):"
    printf '%s\n' "$backstop_lines"
  fi
  if [ -z "$chloe_lines" ] && [ -z "$wy_lines" ]; then
    if [ -z "$backstop_lines" ]; then
      echo "  ✓ nothing outstanding — hooks and skills reconciled with the workspace canonical"
    else
      echo "  ✓ hooks and skills reconciled with the workspace canonical"
    fi
    return 0
  fi
  if [ -n "$chloe_lines" ]; then
    echo "  CHLOE (mechanical — safe to apply, nothing to decide):"
    printf '%s' "$chloe_lines"
  fi
  if [ -n "$wy_lines" ]; then
    echo "  WY (needs a decision — do NOT auto-sync):"
    printf '%s' "$wy_lines"
  fi
  return 0
}

if [ "$MAINTENANCE_MODE" -eq 1 ]; then
  maintenance_report
  exit 0
fi

if [ "$JSON_OUTPUT" -eq 0 ]; then
  echo "Drift-sweep in: $(pwd)"
  # BRANCH IS PART OF "WHERE YOU ARE" (v0.1.15). Twice in one session a commit landed
  # on an unexpected branch because the session checked `git status` and never
  # `git branch` — and status reports a clean tree on the WRONG branch exactly as
  # happily as on the right one, so it can never surface this. Printed here rather
  # than in a SessionStart banner because the mistake is made when you cd into a repo
  # mid-session and commit, not at boot; this line appears at every pre-commit, in
  # every repo, and survives --quiet.
  if [ -d .git ]; then
    _br=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    # origin/HEAD is the real answer where it exists; fall back rather than assume.
    _def=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
    [ -z "$_def" ] && _def=$(git config --get init.defaultBranch 2>/dev/null)
    [ -z "$_def" ] && _def="main"
    if [ -n "$_br" ] && [ "$_br" != "$_def" ]; then
      echo "  BRANCH: ${_br}   <-- NOT the default (${_def})"
    else
      echo "  BRANCH: ${_br}"
    fi
  fi
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
  # Churn measures human-authored lines: machine-generated lockfiles are
  # excluded (they rewrite in bulk on dependency changes) but remain visible
  # to the dirty-file count and every other gate.
  churn_pathspec=(".")
  for lockfile in $CHURN_EXCLUDE_LOCKFILES; do
    churn_pathspec+=(":(exclude)${lockfile}" ":(exclude,glob)**/${lockfile}")
  done
  # NEW FILES ARE NOT CHURN (v0.1.14). This rule targets ITERATIVE accumulation —
  # the same file edited over and over without a commit, where the record of each
  # iteration is what gets lost. But `git diff --shortstat HEAD` counts a brand-new
  # file's ENTIRE BODY as insertions, so ADDING a file read identically to CHURNING
  # one. That made the gate unsatisfiable rather than merely strict: a single
  # 1,149-line stylesheet cannot be split, so the smallest possible commit
  # containing it was already over threshold and `--no-verify` was STRUCTURALLY
  # REQUIRED to commit legitimate work (SESSION-087, OperationFarmstock
  # assembly_viewer). A gate that forces a bypass for honest work trains exactly the
  # bypass habit that produced DEC-103 — the gate was manufacturing the behaviour it
  # exists to prevent.
  #
  # Same treatment lockfiles already get: excluded from the THRESHOLD, still fully
  # visible to the dirty-file count and reported on their own line below. Committing
  # new work stays easy, which is the point — DEC-044 nearly lost an entire 3D model
  # because untracked work sat in a working tree.
  added_files=0
  while IFS= read -r _added; do
    [ -z "$_added" ] && continue
    churn_pathspec+=(":(exclude)${_added}")
    added_files=$((added_files+1))
  done < <(git diff --name-only --diff-filter=A HEAD 2>/dev/null)
  shortstat=$(git diff --shortstat HEAD -- "${churn_pathspec[@]}" 2>/dev/null || true)
  insertions=0
  deletions=0
  if [ -n "$shortstat" ]; then
    insertions=$(echo "$shortstat" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || true)
    deletions=$(echo "$shortstat" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || true)
  fi
  total=$((insertions + deletions))
  dirty_count=$(git diff --name-only HEAD 2>/dev/null | wc -l | tr -d ' ')

  # Annotates whichever branch fires — it must not REPLACE the dirty-file warning,
  # which is a different signal and still owed to the caller.
  added_note=""
  [ "$added_files" -gt 0 ] && added_note=" [+${added_files} new file(s), not counted as churn]"

  if [ "$total" -gt "$DIFF_FAIL_THRESHOLD" ]; then
    fail "uncommitted churn: ${total} lines across ${dirty_count} files (threshold ${DIFF_FAIL_THRESHOLD}) — EDITS to existing files only${added_note}"
  elif [ "$dirty_count" -gt "$DIRTY_FILES_WARN" ]; then
    warn "${dirty_count} files dirty in working tree (threshold ${DIRTY_FILES_WARN})${added_note}"
  else
    pass "working tree healthy (${total} lines, ${dirty_count} files)${added_note}"
  fi

  # Probe-journal accumulation in any single file's diff.
  #
  # EXEMPTION (v0.1.17): files under .claude/skills/ are canonical TOOL sources
  # whose headers carry a deliberate, curated changelog — sweep.sh's own header is
  # the authoritative version history this repo points to. That is categorically
  # different from the probe-iteration journaling this check exists to catch.
  # In real repos those files are SYMLINKS and never appear in a diff at all, so
  # the only place this ever fired was templateRepo_EXAMPLE, which must hold real
  # copies — i.e. it fired exactly once per canonical sync and never on the thing
  # it was designed to catch. Exempting the path removes that friction from the
  # sync path without weakening the check anywhere it does real work.
  journal_diff_hits=0
  while IFS= read -r f; do
    [ -z "$f" ] || [ ! -f "$f" ] && continue
    case "$f" in .claude/skills/*) continue ;; esac
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
    | grep -iE '(audit|findings|mission|handoff|decisions|charter|rules).*\.(md|{{AI}}ai)$' \
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
      [ -z "$f" ] && continue
      # VERSIONED_BACKUP_ALLOWLIST (v0.1.20) — the version in the FILENAME is sometimes the
      # meaning, not a stale copy. TFNerd pins SDK_INVENTORY_v1230_2026_05_19.md as the only
      # record of the PortalSDK v1.2.3.0 export surface, because PortalSDK/ itself is
      # gitignored and gets overwritten in place; five files cite it, and renaming it would
      # destroy the version it exists to record. Same shape as ORPHAN_EXPORT_ALLOWLIST:
      # a repo declares its exception rather than the check guessing.
      if echo "$f" | grep -qE "$VERSIONED_BACKUP_ALLOWLIST"; then continue; fi
      warn "versioned-backup file: ${f}"
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
    mt=$(_mtime "$f")
    [ "$mt" -gt "$newest_code" ] && newest_code=$mt
  done < <(list_source_files)

  stale_seconds=$((MISSION_STALE_DAYS * 86400))
  for sub in ai_context/CURRENT_MISSION.md readme_AI.{{AI}}ai; do
    if [ -f "$sub" ]; then
      sub_mt=$(_mtime "$sub")
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

# ── 9. WISL waystone VALIDITY (v0.1.11) ───────────────────────
# Can the runtime actually READ this card? Every other WISL category — freshness,
# graph, seam-coverage — presumes the card loads, and all of them are grep/awk
# extractors that cannot tell a parseable card from a broken one.
#
# WHY THIS EXISTS (SESSION-085, 2026-08-06): OperationFarmstock's root waystone was
# unparseable for FOUR DAYS across THIRTEEN commits. `continuity:` was a
# double-quoted YAML scalar and a new narrative added literal inch marks
# (8'-6" to 15'-6"), which close the string early and destroy the whole frontmatter
# document. chloe's parse_waystone() returns None on YAMLError, so the registry
# silently DROPPED the card: that repo had no WISL route at all and its hey{{HUMAN}}
# doorway rendered nothing. FIVE of those thirteen commits existed only to re-stamp
# verified_at on that very card, and the repo's own lefthook reported 0 FAIL /
# 0 WARN throughout. A freshness stamp certifies WHEN a card was last reconciled,
# never THAT it can be read — and nothing anywhere checked the latter.
#
# GENERALIZES: any file a runtime PARSES but a gate only GREPS can rot silently
# while every check stays green.
#
# This is the one category that takes a YAML parser, because it is the only one
# that cannot be answered without one. The dependency is OPTIONAL and layered
# (python3+PyYAML, then ruby/psych — verified to agree on all 41 fleet cards); with
# neither available it WARNs that validity is unchecked rather than failing, so the
# "no YAML dep on the gate path" property still holds for every other category and
# for any environment lacking both.
#
# Replicates parse_waystone() EXACTLY — split on '---', take the second segment,
# require a mapping — so a pass here means the runtime loads the card, not merely
# that some YAML somewhere is well-formed. hard fail(): an unparseable card is a
# broken card, not a judgement call.
CURRENT_CATEGORY="waystone-validity"
section "WISL waystone validity"
WS_YAML_PARSER=""
if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' >/dev/null 2>&1; then
  WS_YAML_PARSER="python3"
elif command -v ruby >/dev/null 2>&1 && ruby -ryaml -e '' >/dev/null 2>&1; then
  WS_YAML_PARSER="ruby"
fi

ws_validate_card() {  # $1 = card path → prints "OK" or "BAD:<reason>"
  case "$WS_YAML_PARSER" in
    python3)
      python3 -c '
import sys, yaml
t = open(sys.argv[1], encoding="utf-8", errors="ignore").read()
p = t.split("---")
if len(p) < 3:
    print("BAD:fewer than 3 \"---\" segments (no frontmatter block)"); sys.exit(0)
try:
    d = yaml.safe_load(p[1])
except yaml.YAMLError as e:
    m = getattr(e, "problem_mark", None)
    where = ("file line %d" % (m.line + 2)) if m is not None else "unknown line"
    what = (getattr(e, "problem", "") or "invalid YAML").replace("\n", " ")
    print("BAD:YAML error at %s: %s" % (where, what)); sys.exit(0)
print("OK" if isinstance(d, dict) else "BAD:frontmatter is not a mapping")
' "$1" 2>/dev/null || echo "BAD:parser crashed"
      ;;
    ruby)
      ruby -ryaml -e '
t = File.read(ARGV[0], encoding: "UTF-8")
p_ = t.split("---")
if p_.length < 3
  puts "BAD:fewer than 3 \"---\" segments (no frontmatter block)"
else
  begin
    d = YAML.safe_load(p_[1])
    puts d.is_a?(Hash) ? "OK" : "BAD:frontmatter is not a mapping"
  rescue Exception => e
    # Deliberately NO line number here. Psych exposes only the CONTEXT position
    # (where the mapping started — line 2 for every one of these cards), never the
    # problem position; PyYAML alone reports the real defect line. Reporting the
    # Psych number would point at line 3 when the defect is at line 30. A missing
    # line is honest; a confidently wrong one sends the reader to the wrong place.
    # (No apostrophes in this block: it is a single-quoted bash string.)
    what = e.respond_to?(:problem) && e.problem ? e.problem : e.message.lines.first.to_s.strip
    puts "BAD:YAML error: #{what} (this parser does not report the defect line)"
  end
end
' "$1" 2>/dev/null || echo "BAD:parser crashed"
      ;;
    *) echo "SKIP" ;;
  esac
}

# Heuristic locator for the ONE failure class that has actually bitten this fleet:
# a single-line double-quoted scalar whose value contains unescaped interior quotes
# (OFS's `8'-6" to 15'-6"` inch marks). A valid one-line `key: "…"` holds exactly two
# unescaped quotes; more means the string closed early. Only ever an added HINT — the
# parser's verdict is the finding. Conservative by design: it ignores counts below 3,
# so a legitimately multi-line double-quoted scalar is never flagged.
ws_quote_hint() {  # $1 = card path → prints " · likely: …" or nothing
  awk '
    /^[A-Za-z_][A-Za-z0-9_]*:[ \t]*"/ {
      v = $0; sub(/^[A-Za-z_][A-Za-z0-9_]*:[ \t]*/, "", v)
      gsub(/\\"/, "", v)                       # drop escaped quotes; they are legal
      n = gsub(/"/, "\"", v)                   # count what remains
      if (n > 2) { print NR; exit }
    }
  ' "$1" 2>/dev/null | head -1
}

if [ -z "$WS_YAML_PARSER" ]; then
  # Count in bash rather than via `grep -c`: a failing counter would yield an empty
  # string, collapse to 0, and report "no waystones present" for a repo that HAS
  # them — a false clean, which is the precise failure class this category exists
  # to remove. Only find + sed, matching every other loop in this file.
  wv_n=0
  while IFS= read -r wf; do
    { [ -z "$wf" ] || [ ! -f "$wf" ]; } && continue
    wv_n=$((wv_n+1))
  done < <(find . -type f -name '_waystone.{{AI}}ai' -not -path './.git/*' 2>/dev/null | sed 's|^\./||')
  if [ "$wv_n" -gt 0 ]; then
    warn "waystone validity UNCHECKED: no YAML parser available (need python3 with PyYAML, or ruby). ${wv_n} card(s) not verified."
  else
    pass "no waystones present (WISL not adopted in this repo)"
  fi
else
  wv_found=0; wv_bad=0
  while IFS= read -r wf; do
    [ -z "$wf" ] || [ ! -f "$wf" ] && continue
    wv_found=1
    wv_res=$(ws_validate_card "$wf")
    case "$wv_res" in
      OK) pass "waystone parses: ${wf}" ;;
      BAD:*) wv_bad=$((wv_bad+1))
             wv_hint=""
             case "$wv_res" in
               *"file line"*) : ;;  # parser already pinpointed it
               *) wv_line=$(ws_quote_hint "$wf")
                  [ -n "$wv_line" ] && wv_hint=" · likely line ${wv_line}: a double-quoted value with unescaped quotes inside it (use a >- block scalar)" ;;
             esac
             fail "waystone UNPARSEABLE: ${wf} — ${wv_res#BAD:}${wv_hint} · the runtime silently DROPS this card, so this folder has no WISL route" ;;
      *)  warn "waystone validity indeterminate: ${wf}" ;;
    esac
  done < <(find . -type f -name '_waystone.{{AI}}ai' -not -path './.git/*' 2>/dev/null | sed 's|^\./||')
  [ "$wv_found" -eq 0 ] && pass "no waystones present (WISL not adopted in this repo)"
fi

# ── 9a. hey{{HUMAN}} doorway presence (v0.1.12) ──────────────────────
# A root card carrying a `hey{{HUMAN}}:` inscription is written for a HUMAN to read, and
# the way it gets read is `./_waystone.hey{{HUMAN}}`. If that doorway is missing the
# inscription is unreachable from where the reader stands.
#
# WHY (SESSION-085): the workspace root card had a full hey{{HUMAN}} block written for Wy
# since ADR-015 and NO doorway — he went to ~/GitHub to read it and found nothing.
# All 11 repos had one; the one place he actually stands to see the whole fleet did
# not. Nothing anywhere checked, which is why it survived. Folded into
# waystone-validity rather than given its own category so it inherits an ALREADY
# ARMED gate — validate-substrate would have been the tidier home but runs in no
# lefthook at all, so a check there would have been inert. Same lesson as the rest
# of this file: a gate nothing triggers is not a gate.
if [ -f _waystone.{{AI}}ai ] && grep -qE '^hey{{HUMAN}}:' _waystone.{{AI}}ai 2>/dev/null; then
  # The template ships a tokenized name (_waystone.hey{{HUMAN}}) until init substitutes it.
  if ls _waystone.hey{{HUMAN}} >/dev/null 2>&1 || ls _waystone.hey*'}' >/dev/null 2>&1; then
    if [ -e _waystone.hey{{HUMAN}} ] || ls _waystone.hey*'}' >/dev/null 2>&1; then
      pass "hey{{HUMAN}} doorway present (the inscription is reachable)"
    else
      fail "hey{{HUMAN}} doorway DANGLES: _waystone.hey{{HUMAN}} exists but resolves to nothing — the inscription is unreadable"
    fi
  else
    fail "hey{{HUMAN}} doorway MISSING: this root card carries a hey{{HUMAN}}: inscription written for a human, but no ./_waystone.hey{{HUMAN}} exists to read it through"
  fi
fi

# ── 9b. WISL waystone freshness (v0.1.8: recency-based, staged-aware, lag-free) ──
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
    # The HUMAN reconciliation stamp — quote-tolerant (schema friction #6: quoted to
    # survive YAML int-parse). `reviewed_at` is the clearer name and wins where present;
    # `verified_at` is its permanently-supported predecessor, so no card needs migrating.
    #
    # v0.1.13 SPLIT: this field means A HUMAN RE-READ THIS FOLDER. It is deliberately
    # NOT the place a machine records that the `validation:` command passed — that is
    # `validated_at`, reported separately below and never read by this gate. The two
    # were one overloaded field, which is why auto-stamping kept looking attractive:
    # it would have killed the re-stamp tax by quietly downgrading what the stamp
    # CERTIFIES, leaving a gate that says "a human checked" when a script ran.
    ws_field="reviewed_at"
    sha=$(grep -oE '^reviewed_at:[[:space:]]*"?[0-9a-f]{7,40}"?' "$wf" | grep -oE '[0-9a-f]{7,40}' | head -1)
    if [ -z "$sha" ]; then
      ws_field="verified_at"
      sha=$(grep -oE '^verified_at:[[:space:]]*"?[0-9a-f]{7,40}"?' "$wf" | grep -oE '[0-9a-f]{7,40}' | head -1)
    fi
    if [ -z "$sha" ]; then
      fail "waystone ${wf}: no parseable reviewed_at or verified_at (schema: 7–40 hex, quoted)"
      continue
    fi
    if ! git cat-file -e "${sha}^{commit}" 2>/dev/null; then
      fail "waystone ${wf}: ${ws_field} ${sha} not in git history (dangling sha)"
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
        fail "waystone STALE: ${wf} — ${n} owned file(s) staged without re-stamping the waystone; re-read the folder, re-stamp ${ws_field}, and stage it in this commit"
      fi
    elif [ "$ws_staged" -eq 1 ]; then
      pass "waystone fresh (re-stamp staged): ${wf}"
    else
      # Nothing staged → committed-recency comparison (CI clean-checkout path).
      owned_last=$(git log -1 --format=%ct -- $globs ':(exclude)**/_waystone.{{AI}}ai' 2>/dev/null)
      ws_last=$(git log -1 --format=%ct -- "$wf" 2>/dev/null)
      if [ -n "$owned_last" ] && { [ -z "$ws_last" ] || [ "$owned_last" -gt "$ws_last" ]; }; then
        fail "waystone STALE: ${wf} — owned file(s) committed more recently than the waystone (${ws_field} ${sha}); re-read the folder + re-stamp ${ws_field}"
      else
        pass "waystone fresh: ${wf} (${ws_field} ${sha})"
      fi
    fi
  done < <(find . -type f -name '_waystone.{{AI}}ai' -not -path './.git/*' 2>/dev/null | sed 's|^\./||')
  [ "$ws_found" -eq 0 ] && pass "no waystones present (WISL not adopted in this repo)"
fi

# ── 9b. WISL continuity age (v0.1.13, REPORT-ONLY) ────────────
# `continuity:` is the prose paragraph that tells the next agent what this folder's
# story currently is. Nothing has ever timestamped it. `verified_at` certifies that
# the OWNS globs were reconciled with the code — a different claim entirely, and the
# two genuinely drift apart: code can sit still while the story about it goes stale,
# and vice versa.
#
# DELIBERATELY REPORT-ONLY. This emits `pass` lines and nothing else: no warn, no
# fail, no --fail-on token, no threshold. Under --quiet (how every lefthook invokes
# this) it prints nothing at all, so it cannot make a commit noisy. The point is to
# ACCUMULATE AGES across the fleet first and set a threshold from data — a guessed
# number produces a gate that fires wrong, and a gate that fires wrong gets ignored.
# See seam-coverage-definition.{{AI}}ai §5 for the same rollout discipline.
#
# The field is a QUOTED git sha, matching verified_at, not a hand-typed date: a sha
# resolves to a real commit time and cannot be typo'd into a plausible-looking lie.
# ── 8b. Branch context for gate/contract files (v0.1.15) ──────
# The header above states the branch unconditionally. This is the targeted half: a
# WARN when files that govern the WHOLE repo — the commit gates, the agent contracts,
# the hooks — are being committed somewhere other than the default branch.
#
# Deliberately NOT a blanket "you are on a branch" warning, which would fire on every
# feature commit and be tuned out within a day. And deliberately NOT including
# _waystone.{{AI}}ai: the freshness gate REQUIRES a card to be re-stamped alongside the
# owned code it describes, so cards legitimately move on feature branches constantly —
# warning on them would punish the behaviour another gate mandates.
#
# soft_fail, so it stays a WARN: substrate on a branch is sometimes exactly right
# (held-for-review work belongs on a branch, not in an untracked working tree). The
# point is that it should be a DECISION, not something noticed three commits later.
CURRENT_CATEGORY="branch-context"
section "Branch context"
if [ ! -d .git ]; then
  pass "branch-context: not a git repo — skipping"
else
  bc_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  bc_default=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
  [ -z "$bc_default" ] && bc_default=$(git config --get init.defaultBranch 2>/dev/null)
  [ -z "$bc_default" ] && bc_default="main"
  if [ -z "$bc_branch" ] || [ "$bc_branch" = "$bc_default" ] || [ "$bc_branch" = "HEAD" ]; then
    pass "branch-context: on ${bc_branch:-detached} (default ${bc_default})"
  else
    bc_gov=$(git diff --cached --name-only 2>/dev/null \
      | grep -E '^(lefthook\.yml|CLAUDE\.md|AGENTS\.md|STARTUP_AI\.{{AI}}ai|\.claude/)' || true)
    if [ -n "$bc_gov" ]; then
      bc_n=$(printf '%s\n' "$bc_gov" | grep -c .)
      soft_fail "branch-context: ${bc_n} repo-governing file(s) staged on '${bc_branch}', not the default '${bc_default}' — these set the rules for EVERY commit here, so on a branch they stay inert until merge: $(printf '%s' "$bc_gov" | tr '\n' ' ')"
    else
      pass "branch-context: on '${bc_branch}' (default '${bc_default}'), no repo-governing files staged"
    fi
  fi
fi

# ── 9c. WISL ownership coverage (v0.1.14, REPORT-ONLY) ────────
# What share of tracked source falls under SOME card's `owns` globs. Derived from the
# cards plus git ls-files — NO hand-maintained input, which is the whole point and the
# difference from `seam-coverage`. That category reads a hand-written tsv and asks
# whether each declared folder still has a card: a deletion detector whose denominator
# is editable by forgetting, structurally blind to a folder nobody ever declared. It
# reported 100% for a fleet measured here at 23%. Both numbers are correct; only one
# is called coverage. Full argument + the rejected alternatives:
# .repo-manager/standards/WISL/seam-coverage-definition.{{AI}}ai (ACCEPTED §4).
#
# REPORT-ONLY per §5. A low ratio is not automatically a defect — `owns` scopes the
# FRESHNESS gate, not orientation, and the repoManager root card deliberately excludes
# high-churn session state. Accumulate real numbers before deciding whether a floor
# means anything, and expect the answer to be a per-repo expected value rather than a
# fleet threshold.
CURRENT_CATEGORY="ownership-coverage"
section "WISL ownership coverage (report-only)"
if [ ! -d .git ]; then
  pass "ownership-coverage: not a git repo — skipping"
else
  oc_globs=$(find . -type f -name '_waystone.{{AI}}ai' -not -path './.git/*' 2>/dev/null \
    | xargs -I{} awk '/^owns:/{f=1;next} f&&/^[[:space:]]+-[[:space:]]/{sub(/^[[:space:]]+-[[:space:]]/,"");gsub(/"/,"");print;next} f&&/^[^[:space:]]/{f=0}' {} 2>/dev/null \
    | sort -u)
  if [ -z "$oc_globs" ]; then
    pass "ownership-coverage: no waystones with owns globs (WISL not adopted here)"
  else
    # Same source definition drift-sweep uses elsewhere, minus vendored trees.
    oc_src=$(git ls-files 2>/dev/null | grep -E "\.($(echo "$SOURCE_EXTENSIONS" | tr ' ' '|'))$" \
             | grep -vE '(^|/)(node_modules|\.venv|dist|build|vendor|\.generated)/' || true)
    oc_total=$(printf '%s\n' "$oc_src" | grep -c . || true)
    if [ "$oc_total" -eq 0 ]; then
      pass "ownership-coverage: no tracked source files to score"
    else
      # Both lists go through FILES, never `awk -v`: -v runs escape processing and
      # cannot carry embedded newlines, which silently collapses a multi-line list to
      # one record. Same trap already documented in .repo-manager/upsync-status.sh —
      # and duly walked into again here before the empty result gave it away.
      # FILENAME (not the NR==FNR idiom) selects the pass: NR==FNR is true for the
      # first record of the SECOND file whenever the first file is empty.
      oc_gf=$(mktemp); oc_sf=$(mktemp)
      printf '%s\n' "$oc_globs" > "$oc_gf"
      printf '%s\n' "$oc_src"   > "$oc_sf"
      # `**` spans separators, `*` does not — the schema's documented glob intent.
      oc_covered=$(awk -v gf="$oc_gf" '
        FILENAME == gf {
          if ($0 == "") next
          pat = $0
          gsub(/\./, "\\.", pat)
          gsub(/\*\*/, "\002", pat)
          gsub(/\*/, "[^/]*", pat)
          gsub(/\002/, ".*", pat)
          pats[++p] = "^" pat "$"
          next
        }
        $0 != "" { for (j = 1; j <= p; j++) if ($0 ~ pats[j]) { hit++; break } }
        END { print hit + 0 }' "$oc_gf" "$oc_sf")
      rm -f "$oc_gf" "$oc_sf"
      pass "ownership-coverage: ${oc_covered}/${oc_total} tracked source file(s) claimed by some card's owns ($(( oc_covered * 100 / oc_total ))%)"
    fi
  fi
fi

# ── 9d. Boot-source deliverability (v0.1.15, REPORT-ONLY) ─────
# Which declared boot sources are physically too large to ever arrive whole?
#
# The context packet allocates max_chars // max_files per entry, so there is a hard
# per-entry ceiling and a file above it is ALWAYS truncated — not on a bad day, not
# under load, always. That is worth naming because a truncated file reads exactly like
# a complete one unless the caller checks the warning, which makes an oversized Tier-1
# doc a permanent source of false premises.
#
# The two existing size checks cannot see this. tier1-bloat warns at 25 KB, but the
# per-entry share is 4,096 — they disagree by 6x, so a 17 KB always-loaded file passes
# tier1-bloat while delivering 24% of itself forever. seam-coverage does not look at
# sizes at all.
#
# REPORT-ONLY, because over-cap is not automatically wrong: some files are essential
# AND big (a 27 KB charter), and the fix there is to shrink the FILE — rotate the log,
# page the history — not to stop declaring it. This says which ones, and how little of
# each actually lands.
CURRENT_CATEGORY="boot-source-size"
section "Boot-source deliverability (report-only)"
if [ ! -d .git ]; then
  pass "boot-source-size: not a git repo — skipping"
else
  bs_flagged=0
  bs_cards=0
  while IFS= read -r wf; do
    [ -z "$wf" ] || [ ! -f "$wf" ] && continue
    bs_entries=$(awk '/^boot_path:/{f=1;next} f&&/^[[:space:]]*-[[:space:]]/{sub(/^[[:space:]]*-[[:space:]]*/,"");sub(/[[:space:]]*#.*/,"");print;next} f&&/^[^[:space:]#]/{f=0}' "$wf")
    [ -z "$bs_entries" ] && continue
    bs_cards=$((bs_cards+1))
    # Mirrors default_budget: an all-waystone boot_path is an INDEX card and gets 8
    # slots (breadth); anything else is a code seam and gets 4 (depth).
    bs_total=$(printf '%s\n' "$bs_entries" | grep -c .)
    bs_stones=$(printf '%s\n' "$bs_entries" | grep -c '_waystone\.{{AI}}ai$' || true)
    if [ "$bs_total" -eq "$bs_stones" ]; then bs_files=8; else bs_files=4; fi
    bs_cap=$((16384 / bs_files))
    bs_dir=$(dirname "$wf")
    while IFS= read -r e; do
      [ -z "$e" ] && continue
      bs_path="$e"; [ -f "$bs_path" ] || bs_path="${bs_dir}/${e}"
      [ -f "$bs_path" ] || continue
      bs_size=$(wc -c < "$bs_path" | tr -d ' ')
      if [ "$bs_size" -gt "$bs_cap" ]; then
        pass "boot-source-size: ${e} is ${bs_size} chars vs a ${bs_cap} cap — $(( bs_cap * 100 / bs_size ))% of it can EVER be delivered (declared by ${wf})"
        bs_flagged=$((bs_flagged+1))
      fi
    done < <(printf '%s\n' "$bs_entries")
  done < <(find . -type f -name '_waystone.{{AI}}ai' -not -path './.git/*' 2>/dev/null | sed 's|^\./||')
  if [ "$bs_cards" -eq 0 ]; then
    pass "boot-source-size: no cards with a boot_path"
  elif [ "$bs_flagged" -eq 0 ]; then
    pass "boot-source-size: every declared boot source fits its per-entry cap (${bs_cards} card(s))"
  else
    pass "boot-source-size: ${bs_flagged} declared source(s) across ${bs_cards} card(s) can never arrive whole"
  fi
fi

CURRENT_CATEGORY="validation-age"
section "WISL validation age (report-only)"
if [ ! -d .git ]; then
  pass "validation-age: not a git repo — skipping"
else
  va_seen=0
  while IFS= read -r wf; do
    [ -z "$wf" ] && continue
    va_sha=$(grep -oE '^validated_at:[[:space:]]*"?[0-9a-f]{7,40}"?' "$wf" 2>/dev/null \
             | grep -oE '[0-9a-f]{7,40}' | head -1)
    [ -z "$va_sha" ] && continue
    va_seen=$((va_seen+1))
    va_time=$(git log -1 --format=%ct "$va_sha" 2>/dev/null)
    if [ -z "$va_time" ]; then
      pass "validation-age: ${wf} — validated_at ${va_sha} does not resolve in git history"
      continue
    fi
    pass "validation-age: ${wf} — $(( ( $(date +%s) - va_time ) / 86400 ))d since the validation: command last passed (${va_sha})"
  done < <(find . -type f -name '_waystone.{{AI}}ai' -not -path './.git/*' 2>/dev/null | sed 's|^\./||')
  [ "$va_seen" -eq 0 ] && pass "validation-age: no cards carry validated_at (field not yet adopted)"
fi

# ── 9f. Validation liveness (v0.1.19, REPORT-ONLY) ────────────
# validation-age answers "how long since this card's validation: passed." It cannot
# answer the prior question: COULD that command ever have failed?
#
# Planitaria's src/model card carried
#     npx tsc --noEmit 2>&1 | grep 'ai-control' | head -5; echo 'type-check done'
# for months. The exit status of `a; b` is b's, and `echo` always succeeds — so the
# command returned 0 unconditionally, no matter what tsc found. It sat next to a real
# verified_at, so the card LOOKED maintained. Four PocketLink cards had the same defect
# via a different route: `make build 2>&1 | tail -5` (status of a pipeline is its LAST
# stage, and `tail` does not care that make failed) — compounded by there being no
# `build` target at all, only a build/ DIRECTORY, which make reports as "up to date".
#
# This is the same species as the capability gate that printed "skipping" for 17 days:
# a check whose failure path renders as success. The question worth asking is not
# "did it pass" but "could it ever have failed".
#
# STATIC ONLY — nothing here executes a validation command. Executing them would need
# every toolchain present (GBDK, venvs, npm) and would have side effects; this reads the
# shell grammar and reports commands whose final exit status is structurally pinned to 0.
# `grep` is deliberately NOT in the filter list: grep exits 1 on no-match, so a terminal
# `| grep -q x` is a meaningful assertion, not a mask.
CURRENT_CATEGORY="validation-liveness"
section "WISL validation liveness (report-only)"
vl_seen=0
vl_dead=0
while IFS= read -r wf; do
  [ -z "$wf" ] && continue
  vl_cmd=$(grep -m1 '^validation:' "$wf" 2>/dev/null | sed 's/^validation:[[:space:]]*//')
  [ -z "$vl_cmd" ] && continue
  vl_seen=$((vl_seen+1))
  vl_verdict=$(printf '%s\n' "$vl_cmd" | awk '
    {
      s = $0
      sub(/^"/, "", s); sub(/"[[:space:]]*$/, "", s)
      sub(/^\047/, "", s); sub(/\047[[:space:]]*$/, "", s)
      sub(/[[:space:]]+#.*$/, "", s)
      if (s ~ /\|\|[[:space:]]*(true|:)[[:space:]]*$/) {
        print "ends in `|| true` — cannot return non-zero"; exit
      }
      gsub(/\|\|/, "\002", s)              # protect || from the pipeline split
      n = split(s, a, ";"); seg = a[n]     # `a; b` takes b'\''s status
      m = split(seg, b, "|"); last = b[m]  # `a | b` takes b'\''s status
      gsub(/\002/, "||", last)
      gsub(/^[[:space:]]+/, "", last); gsub(/[[:space:]]+$/, "", last)
      split(last, w, " "); c = w[1]; sub(/.*\//, "", c)
      if (c == "echo" || c == "printf" || c == "true" || c == ":")
        print "final command is `" c "` — always exits 0, so this can never fail"
      else if (c == "tail" || c == "head" || c == "cat" || c == "wc" || c == "tee" || c == "sort" || c == "tr")
        print "output piped into `" c "`, which discards the real exit status"
    }')
  if [ -n "$vl_verdict" ]; then
    pass "validation-liveness: ${wf} — ${vl_verdict}"
    vl_dead=$((vl_dead+1))
  fi
done < <(find . -type f -name '_waystone.{{AI}}ai' -not -path './.git/*' 2>/dev/null | sed 's|^\./||')
if [ "$vl_seen" -eq 0 ]; then
  pass "validation-liveness: no cards carry a validation: field"
elif [ "$vl_dead" -eq 0 ]; then
  pass "validation-liveness: all ${vl_seen} validation: command(s) can return non-zero"
else
  pass "validation-liveness: ${vl_dead} of ${vl_seen} validation: command(s) cannot fail — they report success unconditionally"
fi

CURRENT_CATEGORY="continuity-age"
section "WISL continuity age (report-only)"
if [ ! -d .git ]; then
  pass "continuity-age: not a git repo — skipping"
else
  ca_found=0
  ca_stamped=0
  while IFS= read -r wf; do
    [ -z "$wf" ] && continue
    grep -qE '^continuity:' "$wf" 2>/dev/null || continue
    ca_found=$((ca_found+1))
    ca_sha=$(grep -oE '^continuity_updated:[[:space:]]*"?[0-9a-f]{7,40}"?' "$wf" 2>/dev/null \
             | grep -oE '[0-9a-f]{7,40}' | head -1)
    if [ -z "$ca_sha" ]; then
      pass "continuity-age: ${wf} — carries continuity: but no continuity_updated: (field not yet adopted)"
      continue
    fi
    ca_time=$(git log -1 --format=%ct "$ca_sha" 2>/dev/null)
    if [ -z "$ca_time" ]; then
      # Same dangling-sha condition verified_at treats as a hard FAIL, but this
      # category does not fail by design; say so plainly instead.
      pass "continuity-age: ${wf} — continuity_updated ${ca_sha} does not resolve in git history"
      continue
    fi
    ca_stamped=$((ca_stamped+1))
    ca_days=$(( ( $(date +%s) - ca_time ) / 86400 ))
    pass "continuity-age: ${wf} — ${ca_days}d since continuity_updated (${ca_sha})"
  done < <(find . -type f -name '_waystone.{{AI}}ai' -not -path './.git/*' 2>/dev/null | sed 's|^\./||')
  if [ "$ca_found" -eq 0 ]; then
    pass "continuity-age: no cards carry a continuity: field"
  else
    pass "continuity-age: ${ca_stamped} of ${ca_found} card(s) with continuity: are stamped"
  fi
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
elif [ "$IS_TEMPLATE" -eq 1 ]; then
  # TEMPLATE EXEMPTION (v0.1.25, 2026-08-16) — documented, not silent.
  #
  # This category asks "did a session here end without wrapping?" The template
  # has no sessions to wrap. Its `readme_AI.{{AI}}ai` HANDOFF block is a frozen
  # SPECIMEN (SESSION-001, dated 2026-04-29, placeholder threads) and so is
  # `AI_HANDOFF.{{AI}}ai` — 1,339 bytes, untouched since 2026-05-28, still just
  # the entry-format header. They are documentation OF the format, not a record
  # of work. Work on the template is done from the workspace lane, and its
  # session record lives in repoManager's HANDOFF_LOG.{{AI}}ai.
  #
  # So the only way to satisfy the check here is to re-stamp a specimen every
  # ten commits purely to reset a counter. That is green-by-ritual: it teaches
  # the reflex of editing continuity files to silence a gate, on the one repo
  # whose whole job is to teach the right reflexes to strangers.
  #
  # WHY THIS IS SAFE. The exemption is keyed to IS_TEMPLATE, which requires
  # placeholder-named substrate — a condition init destroys unconditionally at
  # seed time. A repo cut from this template gets the check at full strength on
  # its first commit; the exemption cannot travel with it.
  #
  # WHY IT WAS INVISIBLE UNTIL NOW. The template's own copy of this file was a
  # plain COPY looking for a literal `readme_AI.{{AI}}ai`, which does not exist
  # in a repo whose carrier is `readme_AI.{{AI}}ai`. No carrier found meant
  # "not adopted here" — a vacuous pass for months. Fixing the copy (v0.1.24)
  # is what surfaced the question this comment answers.
  pass "wrap-continuity: template repo — carrier is a frozen specimen, not a session record; exempt by design (real continuity lives in the workspace HANDOFF_LOG)"
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

# ── 14. Hook canonicality ─────────────────────────────────────
# Every .claude/hooks/*.sh must still BE the workspace canonical. Added 2026-08-09
# after handoff-gate.sh was found forked in all eleven repos, in three distinct
# stale versions, none of which had followed THR-020/ADR-012's rename of
# recommended_model= to recommended_capability=. The charter's B3 capability
# STOP-THE-LINE was dead fleet-wide for ~17 days and announced itself as a skip,
# which reads like a pass. Nothing was watching the copies.
#
# The primary fix is structural: hooks are now symlinks to the canonical, the same
# way .claude/skills/ has been since Phase H — which is exactly why the skills never
# drifted. This check is the BACKSTOP for what a symlink cannot cover: a repo that
# de-symlinks, and templateRepo_EXAMPLE, which must hold real files because it ships
# {{AI}} placeholders that are substituted at seed time.
#
# Ladder, strictest first:
#   symlink/hardlink to canonical (-ef)          → pass  (the intended state)
#   byte-identical after {{AI}} substitution      → pass  (sanctioned template form)
#   byte-identical copy                           → WARN  (in sync, but unlinked —
#                                                   this is precisely how the drift
#                                                   began: a correct copy that later
#                                                   stopped being correct)
#   anything else                                 → soft_fail (diverged)
#
# Graceful pass when no canonical dir is reachable (repo cloned outside the fleet,
# single-repo CI checkout) — same dangle posture as the symlinked skill itself.
# soft_fail: WARN by default, FAIL via --fail-on=hook-canonical.
CURRENT_CATEGORY="hook-canonical"
section "Hook canonicality"
if [ ! -d .claude/hooks ]; then
  pass "hook-canonical: no .claude/hooks — skipping"
else
  _top=$(git rev-parse --show-toplevel 2>/dev/null)
  canon_hooks=""
  for cand in \
    "${_top:+${_top}/../.claude/hooks}" \
    "${HOME}/GitHub/.claude/hooks"; do
    [ -n "$cand" ] && [ -d "$cand" ] && { canon_hooks="$cand"; break; }
  done
  if [ -z "$canon_hooks" ]; then
    pass "hook-canonical: workspace canonical hooks dir not reachable — skipping"
  else
    hc_checked=0; hc_bad=0
    for hf in .claude/hooks/*.sh; do
      [ -e "$hf" ] || continue
      hb=$(basename "$hf"); cf="$canon_hooks/$hb"
      hc_checked=$((hc_checked+1))
      if [ ! -f "$cf" ]; then
        soft_fail "hook-canonical: ${hb} has no counterpart in the workspace canonical — either it is repo-local (move it out of .claude/hooks) or the canonical lost it"
        hc_bad=$((hc_bad+1))
      elif [ "$hf" -ef "$cf" ]; then
        :  # linked to canonical — the intended state
      elif diff -q <(template_form "$cf") "$hf" >/dev/null 2>&1; then
        :  # sanctioned template form: canonical + placeholder substitution
      elif diff -q "$cf" "$hf" >/dev/null 2>&1; then
        if [ "$IS_TEMPLATE" -eq 1 ]; then
          # In the TEMPLATE, a plain byte-identical copy is not "in sync, just
          # unlinked" — it is the defect. It means the file carries literal
          # `{{AI}}ai`/`hey{{HUMAN}}`, so a repo seeded under any other duo's names gets
          # substrate pointed at files that do not exist there. That is exactly
          # what shipped: templateRepo's sweep.sh was a plain COPY with 45
          # literal `.{{AI}}ai`, and it reported CLEAN because it was looking for
          # another AI's files. The ladder PERMITTED SUBST here; it has to
          # REQUIRE it. (Note this can only fire on a file that actually differs
          # from its template form — canonical_state returns SUBST first, so a
          # file containing neither token still passes.)
          soft_fail "hook-canonical: ${hb} is a PLAIN COPY in the template — it must be in template form (chloeai -> {{AI}}ai, heywy -> hey{{HUMAN}}). Regenerate with drift-sweep's own template_form()"
          hc_bad=$((hc_bad+1))
        else
          warn "hook-canonical: ${hb} is an unlinked COPY that currently matches the canonical — symlink it (ln -sf ../../../.claude/hooks/${hb}) before it drifts like handoff-gate.sh did"
        fi
      else
        soft_fail "hook-canonical: ${hb} has DIVERGED from the workspace canonical — diff it against ${cf} and relink"
        hc_bad=$((hc_bad+1))
      fi
    done
    if [ "$hc_checked" -eq 0 ]; then
      pass "hook-canonical: no *.sh in .claude/hooks"
    elif [ "$hc_bad" -eq 0 ]; then
      pass "hook-canonical: all ${hc_checked} hook(s) match the workspace canonical"
    fi
  fi
fi

# ── 15. Skill canonicality ────────────────────────────────────
# Same question as hook-canonical, one directory over — but it CANNOT be the same
# mechanical answer, and that is the whole point of this category.
#
# SESSION-089 found two skills in templateRepo_EXAMPLE that looked equally stale:
# drift-sweep was a plain snapshot three versions behind (safe to re-sync, proven
# by a zero-diff against the canonical of its era), while validate-substrate was
# a DELIBERATE fork — fully genericized, carrying a purpose-built filename
# resolver so the template self-validates before AND after init substitution.
# Blanket-syncing "the template's skills" would have destroyed real engineering.
#
# No checker can tell those two apart by inspection, so the repo DECLARES intent:
#   CANONICAL_FORK_SKILLS="validate-substrate"   (in .claude/drift-sweep.conf)
# Everything else under .claude/skills/ is expected to track the canonical.
#
# The split is deliberately by DECISION-OWNER, which is what --maintenance renders:
#   tracked + drifted  -> mechanical, safe to re-sync        (CHLOE can act)
#   declared fork      -> merge by hand, never a copy        (WY decides)
# A declared fork NEVER fails; it reports whether it has fallen behind so the
# decision surfaces without nagging. An UNDECLARED divergence soft_fails, which
# forces exactly one question: re-sync it, or declare it a fork?
CURRENT_CATEGORY="skill-canonical"
section "Skill canonicality"
if [ ! -d .claude/skills ]; then
  pass "skill-canonical: no .claude/skills — skipping"
else
  csk=$(canonical_dir skills) || csk=""
  if [ -z "$csk" ]; then
    pass "skill-canonical: workspace canonical skills dir not reachable — skipping"
  else
    sk_checked=0; sk_bad=0; sk_fork=0
    for sd in .claude/skills/*; do
      [ -e "$sd" ] || continue
      sname=$(basename "$sd")
      [ -d "$csk/$sname" ] || continue        # repo-local skill — nothing to track
      sk_checked=$((sk_checked+1))

      if is_declared_fork "$sname"; then
        sk_fork=$((sk_fork+1))
        fork_behind=0
        for cf in "$csk/$sname"/*; do
          [ -f "$cf" ] || continue
          [ "$(canonical_state "$sd/$(basename "$cf")" "$cf")" = "DIVERGED" ] && fork_behind=1
        done
        if [ "$fork_behind" -eq 1 ]; then
          pass "skill-canonical: ${sname} is a DECLARED FORK and differs from canonical — WY decision (hand merge, never a sync)"
        else
          pass "skill-canonical: ${sname} is a DECLARED FORK, currently level with canonical"
        fi
        continue
      fi

      if [ -L "$sd" ] && [ "$sd" -ef "$csk/$sname" ]; then
        continue                              # symlinked — the intended state
      fi
      sk_drift=""; sk_copy=""
      for cf in "$csk/$sname"/*; do
        [ -f "$cf" ] || continue
        cb=$(basename "$cf")
        case "$(canonical_state "$sd/$cb" "$cf")" in
          LINKED|SUBST) : ;;
          # A plain COPY is acceptable in a real repo (in sync, merely unlinked)
          # and is NOT acceptable in the template, where it means literal
          # `{{AI}}ai`/`hey{{HUMAN}}` shipped to someone whose files are named otherwise.
          # See the matching hook-canonical branch for the full reasoning.
          COPY) [ "$IS_TEMPLATE" -eq 1 ] && sk_copy="${sk_copy} ${cb}" ;;
          *) sk_drift="${sk_drift} ${cb}" ;;
        esac
      done
      if [ -n "$sk_drift" ]; then
        soft_fail "skill-canonical: ${sname} tracks the canonical but has drifted:${sk_drift} — re-sync it, or declare it in CANONICAL_FORK_SKILLS if the divergence is deliberate"
        sk_bad=$((sk_bad+1))
      fi
      if [ -n "$sk_copy" ]; then
        soft_fail "skill-canonical: ${sname} ships PLAIN COPIES in the template:${sk_copy} — must be template form (chloeai -> {{AI}}ai, heywy -> hey{{HUMAN}}). Regenerate with drift-sweep's own template_form()"
        sk_bad=$((sk_bad+1))
      fi
    done
    if [ "$sk_checked" -eq 0 ]; then
      pass "skill-canonical: no skills with a workspace canonical counterpart"
    elif [ "$sk_bad" -eq 0 ]; then
      pass "skill-canonical: ${sk_checked} skill(s) reconciled (${sk_fork} declared fork(s))"
    fi
  fi
fi

# ── 16. Skill doc version consistency (v0.1.26) ───────────────
# The fleet gates code-vs-substrate drift and had NOTHING gating
# code-vs-its-own-documentation. Twice now that has cost the same thing:
#
#   v0.1.19 — "The banner on line 2 of sweep.sh was also corrected; it had read
#             v0.1.15 through four releases, which is the same defect in
#             miniature."
#   2026-08-16 — SKILL.md read "v0.1.21 (current)" through four releases, while
#             documenting a one-token substitution rule (two since v0.1.24) and
#             a plain COPY as always-a-warn (fails in the template since
#             v0.1.25). Found only because someone asked "anything else?"
#
# A stale doc is worse than no doc: an agent reads SKILL.md to learn what the
# gate does, and a confidently wrong answer is acted on.
#
# WHAT IT COMPARES, AND WHAT IT DELIBERATELY DOES NOT. Only version strings
# that CLAIM CURRENCY are checked — a `(current)` marker, or one in a section
# heading. A changelog full of historical `- **v0.1.20** — …` entries is the
# doc working correctly and must never be flagged; that is precisely the
# false-positive that would get this category ignored. No currency claim
# anywhere → graceful pass: the doc is not asserting a version, so there is
# nothing to be wrong about.
#
# Symlinked skill dirs are skipped — those are the workspace canonical seen
# from a consuming repo, and checking the same two files eleven times to say
# the same thing eleven times is how a report becomes wallpaper. They are
# checked in the repo that physically holds them.
#
# soft_fail: WARN by default, FAIL via --fail-on=doc-version. Advisory-first,
# the same rollout every other soft_fail category here got.
CURRENT_CATEGORY="doc-version"
section "Skill doc version consistency"
if [ ! -d .claude/skills ]; then
  pass "doc-version: no .claude/skills — skipping"
else
  dv_checked=0; dv_bad=0
  for sd in .claude/skills/*; do
    [ -d "$sd" ] || continue
    [ -L "$sd" ] && continue
    doc="$sd/SKILL.md"
    [ -f "$doc" ] || continue

    # The script's own banner: first `vX.Y[.Z]` in a comment in the first 5 lines.
    code_ver=""; code_file=""
    for _s in "$sd"/*.sh; do
      [ -f "$_s" ] || continue
      _v=$(head -5 "$_s" | sed -n 's/^#.*[[:space:]]\(v[0-9][0-9.]*\).*/\1/p' | head -1)
      [ -n "$_v" ] && { code_ver="$_v"; code_file="$_s"; break; }
    done
    [ -n "$code_ver" ] || continue          # no banner to compare against

    # Currency claims in the doc: `(vX)` in a heading, or a changelog entry
    # whose line BEGINS `- **vX (current)**`.
    #
    # BOTH PATTERNS ARE LINE-ANCHORED, and that is not incidental. The first
    # version of this used an unanchored `(current)` alternative, and its very
    # first real run flagged this file — because the entry documenting the
    # v0.1.21 defect *quotes the string* `v0.1.21 (current)` while narrating it.
    # Prose that DESCRIBES a stale claim is not making one. That is the identical
    # mention-vs-use defect fixed in validate-substrate hours earlier the same
    # day, rebuilt from scratch in a different check by the same hands, which is
    # a fair measure of how natural the mistake is. A claim occupies the start of
    # its line; a mention sits inside a sentence.
    claims=$( { grep -oE '^#+[[:space:]][^(]*\(v[0-9][0-9.]*\)' "$doc";
                grep -oE '^([-*][[:space:]]+)?\*{0,2}v[0-9][0-9.]*[[:space:]]*\(current\)' "$doc"; } \
              | grep -oE 'v[0-9][0-9.]*' | sort -u)
    [ -n "$claims" ] || continue            # doc asserts no version — nothing to check

    dv_checked=$((dv_checked+1))
    stale=""
    while IFS= read -r c; do
      [ -n "$c" ] || continue
      [ "$c" = "$code_ver" ] || stale="${stale} ${c}"
    done <<< "$claims"

    if [ -n "$stale" ]; then
      soft_fail "doc-version: $(basename "$sd")/SKILL.md claims${stale} as current, but $(basename "$code_file") is ${code_ver} — the doc is describing a release the code has moved past"
      dv_bad=$((dv_bad+1))
    fi
  done
  if [ "$dv_checked" -eq 0 ]; then
    pass "doc-version: no skill here pairs a versioned script with a version-claiming SKILL.md"
  elif [ "$dv_bad" -eq 0 ]; then
    pass "doc-version: ${dv_checked} skill doc(s) match their script's version"
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
