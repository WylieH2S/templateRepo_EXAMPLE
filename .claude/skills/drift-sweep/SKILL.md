---
name: drift-sweep
description: Detect code/substrate drift in a repo — orphaned exports, file-header probe journals, uncommitted iteration churn, untracked audit docs, known-cruft directories, stale CURRENT_MISSION vs code. Companion to validate-substrate. Use before each commit on iterative work, at session start when working tree is dirty, or as part of cross-repo periodic audits.
---

# /drift-sweep

Detects **code/substrate consistency drift** in a repo. Companion to `validate-substrate`:

- `validate-substrate` = STRUCTURAL substrate compliance (Tier 1 files exist, size thresholds, tracked junk)
- `drift-sweep` = CODE/SUBSTRATE CONSISTENCY (orphaned exports, journal-in-code, stale mission vs code, iteration accumulation)

## What it catches

The recurring pattern this skill exists to catch: a probe / iteration cycle adds defensive code while surrounding modules go unmaintained — config constants, helper functions, and state fields from stripped subsystems accumulate as dead exports; file-header comments grow into version-history journals; `CURRENT_MISSION.md` describes the system one way while the code does another; uncommitted state accumulates across multiple iterations until a single mistake erases all of it.

## Checks (v0.1.2)

1. **Working-tree health** — total uncommitted insertions+deletions (FAIL if > `DIFF_FAIL_THRESHOLD`, default 1000); dirty file count (WARN if > `DIRTY_FILES_WARN`, default 10); count of `+// vX.Y.Z` comment lines added in a single file's diff (FAIL if > `JOURNAL_DIFF_LINES_FAIL`, default 3).
2. **Untracked important docs** — any file under `git ls-files --others --exclude-standard` whose name contains `audit`/`findings`/`mission`/`handoff`/`decisions`/`charter`/`rules` and ends in `.md` or `.chloeai`. These should never be untracked.
3. **Known-cruft directories + versioned backups** — tracked files under `*/old/`, `*/testing/`, `*_backup*/`, `*_TEMP*/`; files matching `*_v[0-9]+(_[0-9]+)*.{ts,py,etc}` outside `tests/` or `spec/`.
4. **File-header probe journals** — for each source file under `CODE_ROOTS`, count version-bump comment lines (`// vX.Y.Z`) in the first `JOURNAL_HEADER_SCAN` (default 80) lines. FAIL if > `JOURNAL_HEADER_FAIL` (default 5).
5. **Orphaned exports** — for each `export function|const|class|let|var|enum NAME` under `CODE_ROOTS`, count `\bNAME\b` references in other source files. Zero hits = FAIL. Skips `index.*` and `mod.d.ts` files; honors `ORPHAN_EXPORT_ALLOWLIST` regex. **`export type` and `export interface` are excluded** — they are structural TS API surface and cross-file absence is not meaningful drift.
6. **Substrate vs. code freshness** — newest source file mtime vs. mtime of `ai_context/CURRENT_MISSION.md` and `readme_AI.chloeai`. FAIL if code is more than `MISSION_STALE_DAYS` (default 14) newer.
7. **CLAUDE.md path-rules table sanity** — verifies `CLAUDE.md` exists and contains a path-scoped rules table header (`| Glob | ...`). Accepts any column count after `Glob`.

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
- **As part of periodic cross-repo audits** (run with `--json` flag once available in v1.0 for pipeable output)

## Versions

- **v0.1.2 (current)** — DO-016: skip `type`/`interface` exports in orphan check (structural TS API surface, not runtime drift). DO-017: CLAUDE.md path-rules table regex accepts any column count after `Glob` (2-col or 3-col format).
- **v0.1.1** — orphan check strips comment-leader lines before counting refs, eliminating false positives from stale inline comments.
- **v0.1** — initial implementation; check categories above.
- **v1.0 (planned)** — `--json` output, `--quiet` mode, `--fail-on=<categories>` flag for pre-commit subset, template-mode self-test, comment-claim mismatch with sane heuristics.
