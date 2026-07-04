---
name: drift-sweep
description: Detect code/substrate drift in a repo — orphaned exports, file-header probe journals, uncommitted iteration churn, untracked audit docs, known-cruft directories, stale CURRENT_MISSION vs code, unwrapped session carriers (boot-contract wrap-continuity), WISL waystone freshness/graph/coverage, and up-sync hint lag. Companion to validate-substrate. Use before each commit on iterative work, at session start when working tree is dirty, or as part of cross-repo periodic audits.
---

# /drift-sweep

Detects **code/substrate consistency drift** in a repo. Companion to `validate-substrate`:

- `validate-substrate` = STRUCTURAL substrate compliance (Tier 1 files exist, size thresholds, tracked junk)
- `drift-sweep` = CODE/SUBSTRATE CONSISTENCY (orphaned exports, journal-in-code, stale mission vs code, iteration accumulation)

## What it catches

The recurring pattern this skill exists to catch: a probe / iteration cycle adds defensive code while surrounding modules go unmaintained — config constants, helper functions, and state fields from stripped subsystems accumulate as dead exports; file-header comments grow into version-history journals; `CURRENT_MISSION.md` describes the system one way while the code does another; uncommitted state accumulates across multiple iterations until a single mistake erases all of it.

## Flags

```bash
bash sweep.sh [--quiet] [--json] [--fail-on=<categories>] [<repo-path>]
```

| Flag | Effect |
|------|--------|
| `--quiet` | Suppress PASS lines; show only WARN and FAIL |
| `--json` | Emit JSON to stdout (suppresses human-readable output) |
| `--fail-on=<cats>` | Comma-separated list of categories that affect exit code; all categories still run and report |

**Categories for `--fail-on`:** `working-tree`, `untracked-docs`, `cruft`, `file-journals`, `orphans`, `mission-freshness`, `claude-md`, `waystone-freshness`, `up-sync`, `wrap-continuity`, `wisl-graph`, `seam-coverage`

> `tier1-bloat` is **advisory** (warn-only) — it always runs and reports, but never counts toward the exit code, so listing it in `--fail-on` has no effect.
> `up-sync`, `wrap-continuity`, `wisl-graph`, and `seam-coverage` are **soft_fail** categories: WARN by default, hard-FAIL only when explicitly named in `--fail-on` (the "advisory-first, then arm" rollout).

**Pre-commit use case** — run drift-sweep in lefthook without blocking on orphans (which need manual triage):
```bash
bash .claude/skills/drift-sweep/sweep.sh --quiet --fail-on=working-tree,untracked-docs,file-journals,wrap-continuity
```

**CI/automation use case** — parseable output:
```bash
bash .claude/skills/drift-sweep/sweep.sh --json --fail-on=working-tree,file-journals | jq '.exit_failures'
```

## Checks (v0.1.9)

1. **Working-tree health** — total uncommitted insertions+deletions (FAIL if > `DIFF_FAIL_THRESHOLD`, default 1000); dirty file count (WARN if > `DIRTY_FILES_WARN`, default 10); count of `+// vX.Y.Z` comment lines added in a single file's diff (FAIL if > `JOURNAL_DIFF_LINES_FAIL`, default 3).
2. **Untracked important docs** — any file under `git ls-files --others --exclude-standard` whose name contains `audit`/`findings`/`mission`/`handoff`/`decisions`/`charter`/`rules` and ends in `.md` or `.{{AI}}ai`. These should never be untracked.
3. **Known-cruft directories + versioned backups** — tracked files under `*/old/`, `*/testing/`, `*_backup*/`, `*_TEMP*/`; files matching `*_v[0-9]+(_[0-9]+)*.{ts,py,etc}` outside `tests/` or `spec/`.
4. **File-header probe journals** — for each source file under `CODE_ROOTS`, count version-bump comment lines (`// vX.Y.Z`) in the first `JOURNAL_HEADER_SCAN` (default 80) lines. FAIL if > `JOURNAL_HEADER_FAIL` (default 5).
5. **Orphaned exports** — for each `export function|const|class|let|var|enum NAME` under `CODE_ROOTS`, count `\bNAME\b` references in other source files. Zero hits = FAIL. Skips `index.*` and `mod.d.ts` files; honors `ORPHAN_EXPORT_ALLOWLIST` regex. **`export type` and `export interface` are excluded** — they are structural TS API surface and cross-file absence is not meaningful drift.
6. **Substrate vs. code freshness** — newest source file mtime vs. mtime of `ai_context/CURRENT_MISSION.md` and `readme_AI.{{AI}}ai`. FAIL if code is more than `MISSION_STALE_DAYS` (default 14) newer.
7. **CLAUDE.md path-rules table sanity** — verifies `CLAUDE.md` exists and contains a path-scoped rules table header (`| Glob | ...`). Accepts any column count after `Glob`.
8. **Always-loaded substrate bloat** (advisory, warn-only) — for each always-loaded Tier-1 file in `TIER1_FILES` (default: `readme_AI.{{AI}}ai CLAUDE.md ai_context/ai_rules.{{AI}}ai ai_context/glossary.{{AI}}ai ai_context/CURRENT_MISSION.md ai_context/START_HERE.md`), WARN if its size exceeds `TIER1_BLOAT_WARN_KB` (default 25). Enforces the ADR-004 paging discipline: files loaded on every boot must stay lean; session/decision history pages out to on-demand archives. This is the charter-127KB pattern made self-policing. Never gates (warn-only).
9. **WISL waystone freshness** — for each `_waystone.{{AI}}ai` in the repo: parse `verified_at` (quote-tolerant) and `owns` globs; FAIL if `verified_at` is unparseable or dangling, or if any owned file changed since `verified_at` — **excluding the waystone file itself** (so re-stamping the waystone doesn't self-trip the gate, WISL pilot friction #1). No `_waystone.{{AI}}ai` present → graceful PASS (WISL not adopted in this repo). Gateable via `--fail-on=waystone-freshness`. Implements the WISL-STANDARD §Enforcement `owns`↔`verified_at` binding — the up-sync "teeth" that turn "touched a folder → must re-stamp its waystone" into a CI failure.
10. **Up-sync hint freshness** — opt-in by `ai_context/upsync.{{AI}}ai` presence. Where a repo publishes workspace-relevant deltas upward, FAIL (via the new `soft_fail` helper) if `readme_AI.{{AI}}ai`'s last commit is newer than the hint ledger's last commit — i.e. headline state moved without an up-sync block. Git-history-based (committer dates), so it's deterministic on a CI clean checkout (no working-tree mtime). **WARN by default; hard-FAILs only via `--fail-on=up-sync`** — the Hybrid teeth wired at boot-when-dirty / lefthook pre-commit / CI. No `ai_context/upsync.{{AI}}ai` present → silent PASS, so this fleet-canonical change is inert until a repo adopts the up-sync loop. Distinct from `waystone-freshness` (which binds folder edits to a waystone re-stamp): this binds repo-level state to an up-sync hint for the workspace to consume. Staged-aware since v0.1.8.
11. **Wrap continuity** (Agent Boot Contract W1, ADR-BOOT-001) — the git-native session-wrap floor: fires for ANY committing agent (Claude, Codex, …), closing the gap where wrap discipline lived only in Claude's SessionStart hooks. Carrier auto-detects `readme_AI.{{AI}}ai` (in-repo) or the workspace HANDOFF log (substrate repo); override via `WRAP_CARRIER`. A commit that stages the carrier passes as the wrap in flight; otherwise the carrier must not lag HEAD by more than `WRAP_LAG_WARN` commits (default 10). File-touch is the deliberate proxy for "gained a HANDOFF block" (content parsing stays in the Claude-native gates). No carrier → graceful pass. **soft_fail**: WARN by default, gate via `--fail-on=wrap-continuity`.
12. **WISL waystone graph connectivity** — every `depends_on` / `boot_path` edge in each waystone's frontmatter must resolve on disk (dangling edges strand the next agent on a card pointing at a moved path). Frontmatter-only parse. No waystones → graceful pass. **soft_fail** via `--fail-on=wisl-graph`.
13. **WISL seam coverage** — folders the workspace seam map declares `needed`/`live` must carry a `_waystone.{{AI}}ai` (catches MISSING cards; waystone-freshness only catches stale ones). Graceful where the workspace seam map is unreachable (single-repo CI checkout). **soft_fail** via `--fail-on=seam-coverage`.

## How to invoke

From the repo root:

```bash
bash .claude/skills/drift-sweep/sweep.sh
```

Or explicitly:

```bash
bash .claude/skills/drift-sweep/sweep.sh /path/to/repo
```

## Configuration

All thresholds are configurable via `.claude/drift-sweep.conf` (optional bash file sourced at startup):

```bash
# Example .claude/drift-sweep.conf for a TypeScript project
CODE_ROOTS="src lib"
EXCLUDE_FILES="dist/.*|\.generated\."
DIFF_FAIL_THRESHOLD=1500
JOURNAL_DIFF_LINES_FAIL=3
JOURNAL_HEADER_SCAN=80
JOURNAL_HEADER_FAIL=5
MISSION_STALE_DAYS=14
ORPHAN_EXPORT_ALLOWLIST="^(BALANCED|DEFENSIVE)$"   # exports used only by tests
SOURCE_EXTENSIONS="ts tsx"
```

If `.claude/drift-sweep.conf` doesn't exist, defaults apply.

## Output

- ✓ PASS lines for healthy checks
- ⚠ WARN for non-blocking concerns (file counts near threshold, advisory checks)
- ✗ FAIL for blocking drift (orphaned exports, untracked audits, journal-in-code, stale mission)

Exit code: 0 if no failures, 1 if any FAIL, 2 if cannot enter target repo.

## When to invoke

- **Before each commit** during iterative / probe work (via lefthook pre-commit, ideally)
- **At session start** when working tree is dirty
- **After a probe iteration's live test** lands a result — confirms the result was committed and no defensive code was left behind
- **As part of periodic cross-repo audits** (use `--json` for pipeable output; `--fail-on=working-tree,untracked-docs,file-journals` for a quick no-triage pre-commit gate)
- **Optional — after every Claude Code turn:** add a `Stop` hook to `.claude/settings.json` that reports drift state at session end:
  ```json
  {"hooks": {"Stop": [{"matcher": "", "hooks": [{"type": "command",
    "command": "bash .claude/skills/drift-sweep/sweep.sh --quiet --fail-on=working-tree,untracked-docs,file-journals"}]}]}}
  ```

## Versions

- **v0.1.9 (current)** — Added the gateable `wrap-continuity` category: the Agent Boot Contract W1 WRITE-edge floor (ADR-BOOT-001). Git-native session-wrap gate at the commit edge — carrier lag threshold (`WRAP_LAG_WARN`, default 10) with staged-carrier-passes-as-wrap; carrier auto-detection (`readme_AI.{{AI}}ai` / workspace HANDOFF log) with `WRAP_CARRIER` override; graceful where no carrier exists, so the symlinked fleet rollout is advisory-only until a repo arms it. Proven by a 10-case scenario harness. Closes the any-agent wrap gap (wrap discipline previously lived only in Claude-native SessionStart hooks).
- **v0.1.7–v0.1.8** — (docs catch-up; SKILL.md previously stopped at v0.1.6.) v0.1.7: advisory `wisl-graph` (waystone edge connectivity) + `seam-coverage` (seam-map folders must carry waystones) categories. v0.1.8: `up-sync` and `waystone-freshness` became STAGED-AWARE, and waystone-freshness was reframed from a `verified_at` SHA-range diff to commit-time RECENCY — both one-commit committed-history lags closed (SESSION-053c; re-stamp an owned waystone in the SAME commit as its files).
- **v0.1.6** — Added the gateable `up-sync` category + a new `soft_fail()` helper (WARN by default, hard-FAIL only when the category is named in `--fail-on`). Catches up-sync drift: when a repo's `readme_AI.{{AI}}ai` moves without a matching `ai_context/upsync.{{AI}}ai` block, headline state has changed without propagating upward to the workspace ledgers (ROSTER / fleet / HANDOFF). Opt-in by hint-file presence → inert fleet-wide until a repo adopts it. The deterministic teeth for the SESSION-039 up-sync write-path (paired with the charter PROPAGATE-UP wrap step + the SessionStart model/effort gate).
- **v0.1.5** — Added the gateable `waystone-freshness` category: enforces the WISL `owns`↔`verified_at` freshness binding (WISL-STANDARD §Enforcement) — a waystone whose owned files changed since its `verified_at` FAILs, **excluding the waystone file itself** (pilot friction #1). Inert (graceful pass) where no `_waystone.{{AI}}ai` exists, so it ships fleet-wide safely before any waystone merges. Quote-tolerant `verified_at` parse (friction #6).
- **v0.1.4** — Added advisory (warn-only) `tier1-bloat` check: flags always-loaded substrate files over `TIER1_BLOAT_WARN_KB` (default 25). Makes the ADR-004 paging discipline self-policing fleet-wide so the charter-127KB read-path pattern cannot silently recur. New config: `TIER1_FILES`, `TIER1_BLOAT_WARN_KB`.
- **v0.1.3** — DO-007: `--quiet`, `--json`, and `--fail-on=<categories>` flags. `--fail-on` enables selective pre-commit gating without blocking on orphans or freshness.
- **v0.1.2** — DO-016: skip `type`/`interface` exports in orphan check (structural TS API surface, not runtime drift). DO-017: CLAUDE.md path-rules table regex accepts any column count after `Glob` (2-col or 3-col format).
- **v0.1.1** — orphan check strips comment-leader lines before counting refs, eliminating false positives from stale inline comments.
- **v0.1** — initial implementation; check categories above.
- **v1.0 (planned)** — class-method orphan detection (currently only top-level exports are checked; dead class methods are invisible to the script), template-mode self-test, comment-claim mismatch with sane heuristics.
