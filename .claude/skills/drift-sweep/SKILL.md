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
bash sweep.sh [--quiet] [--json] [--fleet] [--maintenance] [--fail-on=<categories>] [<repo-path>]
```

| Flag | Effect |
|------|--------|
| `--quiet` | Suppress PASS lines; show only WARN and FAIL |
| `--json` | Emit JSON to stdout (suppresses human-readable output) |
| `--fleet` | Iterate every child repo of a workspace root, sweeping each in its OWN root |
| `--maintenance` | Report outstanding canonical-tracking upkeep split by decision-owner (CHLOE / WY), plus **backstop health** (v0.1.21). Read-only, always exits 0. The **only** mode that makes a network call |
| `--fail-on=<cats>` | Comma-separated list of categories that affect exit code; all categories still run and report |

**Categories for `--fail-on`:** `working-tree`, `untracked-docs`, `cruft`, `file-journals`, `orphans`, `mission-freshness`, `claude-md`, `waystone-validity`, `waystone-freshness`, `up-sync`, `wrap-continuity`, `wisl-graph`, `seam-coverage`, `hook-canonical`, `skill-canonical`, `doc-version`

> `tier1-bloat` is **advisory** (warn-only) — it always runs and reports, but never counts toward the exit code, so listing it in `--fail-on` has no effect.
> `up-sync`, `wrap-continuity`, `wisl-graph`, `seam-coverage`, `hook-canonical`, `skill-canonical`, and `doc-version` are **soft_fail** categories: WARN by default, hard-FAIL only when explicitly named in `--fail-on` (the "advisory-first, then arm" rollout).

**Pre-commit use case** — run drift-sweep in lefthook without blocking on orphans (which need manual triage):
```bash
bash .claude/skills/drift-sweep/sweep.sh --quiet --fail-on=working-tree,untracked-docs,file-journals,wrap-continuity
```

**CI/automation use case** — parseable output:
```bash
bash .claude/skills/drift-sweep/sweep.sh --json --fail-on=working-tree,file-journals | jq '.exit_failures'
```

## Checks (v0.1.33)

1. **Working-tree health** — total uncommitted insertions+deletions (FAIL if > `DIFF_FAIL_THRESHOLD`, default 1000); dirty file count (WARN if > `DIRTY_FILES_WARN`, default 10); count of `+// vX.Y.Z` comment lines added in a single file's diff (FAIL if > `JOURNAL_DIFF_LINES_FAIL`, default 3).  **Gate:** `working-tree`
2. **Untracked important docs** — any file under `git ls-files --others --exclude-standard` whose name contains `audit`/`findings`/`mission`/`handoff`/`decisions`/`charter`/`rules` and ends in `.md` or `.chloeai`. These should never be untracked.  **Gate:** `untracked-docs`
3. **Known-cruft directories + versioned backups** — tracked files under `*/old/`, `*/testing/`, `*_backup*/`, `*_TEMP*/`; files matching `*_v[0-9]+(_[0-9]+)*.{ts,py,etc}` outside `tests/` or `spec/`. Honors `VERSIONED_BACKUP_ALLOWLIST` (v0.1.20), a path regex for files whose version **is the meaning** — a pinned snapshot of an external surface rather than a stale copy.  **Gate:** `cruft`
4. **File-header probe journals** — for each source file under `CODE_ROOTS`, count version-bump comment lines (`// vX.Y.Z`) in the first `JOURNAL_HEADER_SCAN` (default 80) lines. FAIL if > `JOURNAL_HEADER_FAIL` (default 5).  **Gate:** `file-journals`
5. **Orphaned exports** — for each `export function|const|class|let|var|enum NAME` under `CODE_ROOTS`, count `\bNAME\b` references in other source files. Zero hits = FAIL. Skips `index.*` and `mod.d.ts` files; honors `ORPHAN_EXPORT_ALLOWLIST` regex. **`export type` and `export interface` are excluded** — they are structural TS API surface and cross-file absence is not meaningful drift.  **Gate:** `orphans`
6. **Substrate vs. code freshness** — newest source file mtime vs. mtime of `ai_context/CURRENT_MISSION.md` and `readme_AI.chloeai`. FAIL if code is more than `MISSION_STALE_DAYS` (default 14) newer.  **Gate:** `mission-freshness`
7. **CLAUDE.md path-rules table sanity** — verifies `CLAUDE.md` exists and contains a path-scoped rules table header (`| Glob | ...`). Accepts any column count after `Glob`.  **Gate:** `claude-md`
8. **Always-loaded substrate bloat** (advisory, warn-only) — for each always-loaded Tier-1 file in `TIER1_FILES` (default: `readme_AI.chloeai CLAUDE.md ai_context/ai_rules.chloeai ai_context/glossary.chloeai ai_context/CURRENT_MISSION.md ai_context/START_HERE.md`), WARN if its size exceeds `TIER1_BLOAT_WARN_KB` (default 25). Enforces the ADR-004 paging discipline: files loaded on every boot must stay lean; session/decision history pages out to on-demand archives. This is the charter-127KB pattern made self-policing. Never gates (warn-only).  **Gate:** `tier1-bloat`
9. **WISL waystone freshness** — for each `_waystone.chloeai` in the repo: parse `verified_at` (quote-tolerant) and `owns` globs; FAIL if `verified_at` is unparseable or dangling, or if any owned file changed since `verified_at` — **excluding the waystone file itself** (so re-stamping the waystone doesn't self-trip the gate, WISL pilot friction #1). No `_waystone.chloeai` present → graceful PASS (WISL not adopted in this repo). Gateable via `--fail-on=waystone-freshness`. Implements the WISL-STANDARD §Enforcement `owns`↔`verified_at` binding — the up-sync "teeth" that turn "touched a folder → must re-stamp its waystone" into a CI failure.  **Gate:** `waystone-validity`, `waystone-freshness`
10. **Up-sync hint freshness** — opt-in by `ai_context/upsync.chloeai` presence. Where a repo publishes workspace-relevant deltas upward, FAIL (via the new `soft_fail` helper) if `readme_AI.chloeai`'s last commit is newer than the hint ledger's last commit — i.e. headline state moved without an up-sync block. Git-history-based (committer dates), so it's deterministic on a CI clean checkout (no working-tree mtime). **WARN by default; hard-FAILs only via `--fail-on=up-sync`** — the Hybrid teeth wired at boot-when-dirty / lefthook pre-commit / CI. No `ai_context/upsync.chloeai` present → silent PASS, so this fleet-canonical change is inert until a repo adopts the up-sync loop. Distinct from `waystone-freshness` (which binds folder edits to a waystone re-stamp): this binds repo-level state to an up-sync hint for the workspace to consume. Staged-aware since v0.1.8.  **Gate:** `up-sync`
11. **Wrap continuity** (Agent Boot Contract W1, ADR-BOOT-001) — the git-native session-wrap floor: fires for ANY committing agent (Claude, Codex, …), closing the gap where wrap discipline lived only in Claude's SessionStart hooks. Carrier auto-detects `readme_AI.chloeai` (in-repo) or the workspace HANDOFF log (substrate repo); override via `WRAP_CARRIER`. A commit that stages the carrier passes as the wrap in flight; otherwise the carrier must not lag HEAD by more than `WRAP_LAG_WARN` commits (default 10). File-touch is the deliberate proxy for "gained a HANDOFF block" (content parsing stays in the Claude-native gates). No carrier → graceful pass. **soft_fail**: WARN by default, gate via `--fail-on=wrap-continuity`. **Exempt in the template (v0.1.25)** — both of templateRepo's carriers are frozen specimens documenting the format, not records of work (its real session record lives in the workspace HANDOFF log), so the only way to satisfy the check there was re-stamping a specimen every ten commits to reset a counter. The exemption is keyed to `IS_TEMPLATE`, which requires placeholder-named substrate and therefore cannot travel into a seeded repo.  **Gate:** `wrap-continuity`
12. **WISL waystone graph connectivity** — every `depends_on` / `boot_path` edge in each waystone's frontmatter must resolve on disk (dangling edges strand the next agent on a card pointing at a moved path). Frontmatter-only parse. No waystones → graceful pass. **soft_fail** via `--fail-on=wisl-graph`.  **Gate:** `wisl-graph`
13. **WISL seam coverage** — folders the workspace seam map declares `needed`/`live` must carry a `_waystone.chloeai` (catches MISSING cards; waystone-freshness only catches stale ones). Graceful where the workspace seam map is unreachable (single-repo CI checkout). **soft_fail** via `--fail-on=seam-coverage`.  **Gate:** `seam-coverage`
14. **Hook canonicality** — every `.claude/hooks/*.sh` must still BE the workspace canonical. In a **consuming repo** that means a symlink/hardlink, and a byte-identical unlinked **copy** is a WARN: that is exactly the state the fleet was in before `handoff-gate.sh` rotted into three stale versions across eleven repos, so "correct today" is not the property worth asserting. In the **template** the intended state is the opposite — a real, byte-identical copy (v0.1.30), because the template is meant to be cloned away from this machine, where a symlink into the workspace dangles. There `DIVERGED` prescribes a re-copy rather than a relink. A file in the **retired template form** (`SUBST`, the substituted shape v0.1.29 abolished) soft-fails with the command that supersedes it; `COPY` is tested first so a token-free file cannot tie into that branch. Anything else diverged → **soft_fail** via `--fail-on=hook-canonical`. Graceful pass where the workspace canonical is unreachable (repo cloned outside the fleet, single-repo CI checkout).  **Gate:** `hook-canonical`

15. **Skill canonicality** — the same question as `hook-canonical`, one directory over, but it cannot have the same mechanical answer. A skill copy may be a **tracking copy** (re-sync it) or a **deliberate fork** (a copy would destroy its own work), and nothing distinguishes those by inspection — so the repo declares intent with `CANONICAL_FORK_SKILLS` in `.claude/drift-sweep.conf`. A declared fork never fails; it reports whether it has fallen behind so the decision surfaces without nagging. Undeclared divergence **soft_fails** via `--fail-on=skill-canonical`, forcing exactly one question: re-sync, or declare it a fork? Skills with no canonical counterpart are repo-local and ignored. As with `hook-canonical`, a plain unlinked **copy** is tolerated everywhere and is the *intended* state in the template (v0.1.30), where `DIVERGED` prescribes a re-copy; the **retired template form** soft-fails there with the command that supersedes it. The declared-fork machinery still exists, but the fleet's only fork — the template's `validate-substrate` — was retired in v0.1.29 once the canonical could do the job it was forked to do.  **Gate:** `skill-canonical`

16. **Skill doc version consistency** (v0.1.26) — the version a skill's `SKILL.md` *claims* must equal the version its script's banner declares. The fleet gated code-vs-substrate drift and had nothing gating code-vs-**its own documentation**, and that gap cost the same thing twice: v0.1.19's entry below records `sweep.sh`'s banner reading `v0.1.15` through four releases, and on 2026-08-16 this file read `v0.1.21 (current)` through four releases while describing rules the code no longer had. A stale doc is worse than no doc — an agent reads `SKILL.md` to learn what the gate does, and a confidently wrong answer gets acted on. Only version strings that **claim currency** are compared — a `(current)` marker or a section heading, **both line-anchored**; a changelog of historical entries is the doc working correctly and is never flagged, since that false positive is exactly what would make the category ignorable. No currency claim → graceful pass. The anchoring was earned: the first version used an unanchored match and flagged this very file, because the entry documenting the v0.1.21 defect *quotes the string* `v0.1.21 (current)` while narrating it. Prose describing a stale claim is not making one — a claim occupies the start of its line, a mention sits inside a sentence. Symlinked skill dirs are skipped — they are the workspace canonical seen from a consuming repo, and saying the same thing eleven times is how a report becomes wallpaper. **soft_fail** via `--fail-on=doc-version`.  **Gate:** `doc-version`

17. **AGENTS.md parity** (2026-08-16) — Claude Code auto-reads `CLAUDE.md`; every *other* agent reads `AGENTS.md` first, so drift between them lets a non-Claude agent resume from a stale picture and silently undo work (OperationFarmstock DEC-044, where an untracked 3D model was nearly lost). Two parts, mirroring `up-sync`: `CLAUDE.md` **staged without** `AGENTS.md` catches drift at the commit that creates it, and a **last-commit lag** past `AGENTS_LAG_WARN_DAYS` (default 30) catches the backlog that predates the gate. A missing `AGENTS.md` is its own failure — the repo has no cross-AI entry point at all. **It does not compare line counts**, deliberately: planTheBeast's 18-line file is a complete boot instruction while a 42-line one elsewhere only delegates, so length is the wrong property and gating it would train people to pad files. **soft_fail** via `--fail-on=agents-parity`.  **Gate:** `agents-parity`

18. **Branch context** — surfaces which branch substrate edits are landing on, so a session does not
quietly commit fleet-wide substrate to a feature branch where nobody will find it. **soft_fail**.
  **Gate:** `branch-context`

19. **The report-only WISL family** — five checks that measure rather than judge: `ownership-coverage`
(waystones whose `owns` globs match nothing), `boot-source-size` (declared boot sources too large to
arrive within their packet ceiling), `validation-age` and `validation-liveness` (whether a card's
`validation:` command is stale or no longer runs), and `continuity-age` (how long since a card's
`continuity:` was rewritten). They print findings and never fail.
  **Gate:** `ownership-coverage`, `boot-source-size`, `validation-age`, `validation-liveness`, `continuity-age`

> **Report-only is a holding pattern, not a destination.** A check nobody can fail is a check people
> stop reading — `boot-source-size` has been quietly reporting that ~half of all declared boot
> sources cannot arrive whole, and nothing has ever acted on it. Each of these five owes a decision:
> promote to `soft_fail`, or delete.

20. **Skill doc category coverage** — every category a skill's script defines must be **named, in
backticks, somewhere in its `SKILL.md`**. `doc-version` (check 16) compares the version a doc
*claims* against the version its script declares, which catches a stale doc and cannot catch an
absent one. Measured 2026-08-16: the doc numbered 16 checks while the code ran 24 categories, and
**20 of those 24 never told the reader their `--fail-on` handle** — including `waystone-validity`,
a hard-FAIL category that owns the heywy doorway test. A gate you cannot name is a gate you cannot
arm. The rule is deliberately *not* one-numbered-check-per-category, because some checks honestly
own several (WISL validity and freshness are one story); it only requires that no category is
invisible. Symlinked skill dirs are skipped, same as `doc-version`. **soft_fail**.
  **Gate:** `doc-coverage`

### Maintenance mode — the wy/chloe split

```bash
bash .claude/skills/drift-sweep/sweep.sh --maintenance          # this repo
bash .claude/skills/drift-sweep/sweep.sh --fleet --maintenance ~/GitHub   # every repo
```

Reports outstanding substrate upkeep **by decision-owner** instead of by file:

- **CHLOE** — restoring a known invariant: relink a hook or skill where a symlink is intended, or re-sync the seed template's tracking copies. The exact command is printed; nothing here needs a human to think.
- **WY** — a declared fork has fallen behind canonical. No safe mechanical answer exists, so it needs a hand merge.

The WY column is kept scarce on purpose. If everything lands in it, the split has stopped meaning anything. Read-only, always exits 0 — it reports, it never mutates.

### Report-only categories

These always run, always report, and **never** affect the exit code — naming them in `--fail-on` has no effect. They exist to collect real data before a threshold gets set from a guess.

| Category | Question it answers | Added |
|----------|--------------------|-------|
| `branch-context` | Are repo-governing files being staged on a non-default branch, where they stay inert until merge? | v0.1.13 |
| `ownership-coverage` | What share of tracked source files is claimed by some card's `owns`? (The honest counterpart to `seam-coverage`, which only detects *deleted* cards.) | v0.1.14 |
| `boot-source-size` | Which declared boot sources exceed the per-entry cap (`16384/max_files`) and so can never arrive whole? | v0.1.15 |
| `validation-age` | How long since each card's `validation:` command last passed (`validated_at`)? | v0.1.13 |
| `continuity-age` | How long since each card's `continuity:` prose was reconciled (`continuity_updated`)? | v0.1.13 |
| `validation-liveness` | Could each card's `validation:` command **ever have failed**? | v0.1.19 |

`validation-liveness` is the newest and the least obvious. `validation-age` reports how long since a command passed; it cannot notice that the command was incapable of doing anything else. Five fleet cards were:

```bash
npx tsc --noEmit 2>&1 | grep 'ai-control' | head -5; echo 'type-check done'   # `a; b` takes b's status; echo always succeeds
make build 2>&1 | tail -5                                                      # a pipeline's status is its LAST stage
```

Both returned 0 unconditionally, for months, next to a real `verified_at` — so the cards looked maintained. The check is **static**: it reads shell grammar and never executes a validation command (doing so would need every toolchain present and would have side effects). It flags a trailing `echo`/`printf`/`true`/`:`, a trailing `|| true`, and a terminal pipe into `tail`/`head`/`cat`/`wc`/`tee`/`sort`/`tr`. **`grep` is deliberately excluded** — grep exits 1 on no-match, so a terminal `| grep -q x` is a real assertion, not a mask.

> **Known gap:** the numbered list above covers the *gateable* categories; the report-only ones are tabled here as of v0.1.19. This file's version history below still has a gap between v0.1.9 and v0.1.16 — `sweep.sh`'s own header remains the authoritative changelog. Reconciling that remainder is tracked, not done.

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
VERSIONED_BACKUP_ALLOWLIST="^docs/snapshots/API_v[0-9]+\.md$"   # version IS the meaning, not a stale copy
BACKSTOP_WORKFLOW="fleet-sweep.yml"   # --maintenance only; checked solely in the repo that HAS this file
BACKSTOP_STALE_DAYS=2                 # a green-but-old backstop is still a broken backstop
BACKSTOP_CHECK=1                      # 0 disables the one network probe entirely
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

- **v0.1.33 (current)** — **New `doc-coverage` category, and the doc it forced.** `doc-version` (v0.1.26) compares the version a `SKILL.md` *claims* against the version its script declares. That catches a **stale** doc and is structurally blind to an **absent** one. Measured 2026-08-16: this doc numbered **16 checks while the code ran 24 categories**, and **20 of those 24 never named their `--fail-on` handle anywhere** — including `waystone-validity`, a hard-FAIL category that owns the heywy doorway test. A gate you cannot name is a gate you cannot arm, so the most actionable fact about each check was the one the doc omitted.

  The rule is deliberately **not** one-numbered-check-per-category. Some checks honestly own several — WISL validity and freshness are one story — so requiring 1:1 would force fake structure. It requires only that every category name appears in backticks somewhere in the doc, which is exactly the property that makes `--fail-on` discoverable.

  Bringing the doc into compliance added the missing entries for `branch-context`, `waystone-validity`, and the five report-only WISL checks, and put an explicit **Gate:** handle on all twenty. Symlinked skill dirs are skipped (same rule as `doc-version`): they are the workspace canonical seen from a consumer, and saying it eleven times is how a report becomes wallpaper. **soft_fail** via `--fail-on=doc-coverage`.

  It caught its own release — the first run flagged `doc-coverage` itself as undocumented, the third time this session a new check has done that. Negative test kept: renaming a category in a scratch copy is caught by name, and the unmodified repo passes.

- **v0.1.32** — **New `agents-parity` category.** Claude Code auto-reads `CLAUDE.md`; every *other* agent reads `AGENTS.md` first. When the two drift, a non-Claude agent resumes from a stale picture of the repo and can silently undo what the Claude side just did — which is not hypothetical, it is the near-loss recorded as OperationFarmstock DEC-044, where an untracked 3D model was almost lost. The rule was written down, and **nothing enforced it**: three repos had drifted 41–77 days.

  **It deliberately does not compare line counts.** The obvious implementation is "AGENTS.md should be about as long as CLAUDE.md", and measurement kills it: planTheBeast's 18-line `AGENTS.md` is a complete, coherent boot instruction, while a 42-line one elsewhere merely delegates back to `CLAUDE.md`. Length is not the property, and a gate on the wrong property trains people to pad files. What matters is whether `AGENTS.md` was **revisited when `CLAUDE.md` moved**, and git answers that exactly.

  Same two-part shape as `up-sync`, for the same reason: catch it at the commit that *creates* the drift (`CLAUDE.md` staged without `AGENTS.md`), and catch the backlog that predates the gate (last-commit lag past `AGENTS_LAG_WARN_DAYS`, default 30). A lag threshold rather than up-sync's zero tolerance, because plenty of `CLAUDE.md` edits — a Tier 2 row, a typo — genuinely change nothing another agent needs. A missing `AGENTS.md` is its own failure: the repo has no cross-AI entry point at all. **soft_fail** via `--fail-on=agents-parity`.

  It caught its own release: the template showed 80 days because v0.1.31 edited its `CLAUDE.md` Tier 1 table without mirroring it. Negative tests kept for all four states — missing, staged-alone, staged-together, and lagging — plus a passing control.

- **v0.1.31** — **`tier1-bloat` gains the aggregate budget, and "Tier 1" finally means one thing.** The charter's LOAD ECONOMICS claimed *"≤200 lines total across all Tier 1 files"*; the only mechanism was a **per-file** 25 KB check, so every repo in the fleet ran **313–796 lines** and every one of them passed. A budget with no mechanism is decoration.

  Fixing it required fixing something underneath first: **three definitions of Tier 1 existed and none matched** — the charter listed one set, `templateRepo_EXAMPLE/CLAUDE.md` a second, `TIER1_FILES` a third. An aggregate over a set nobody agrees on measures nothing. All three are now the **union**, and the consequential addition is **`STARTUP_AI`** — the boot capsule `BOOT-CONTRACT` R1 makes mandatory, the most reliably always-loaded file in any repo, and it was in *none* of the three lists. The single heaviest boot cost in the fleet was exempt from the check whose whole purpose is measuring boot cost.

  Budget is **750 lines**, calibrated from the measured distribution rather than aspiration (Planitaria 796, planTheBeast 749, TFNerd 591, PocketLink 588, OperationFarmstock 557, r1Intern 495, ADTNode 489, HomeImprovement 467, Task-Force-Nerd-LLC 456, MechaComet 399). That makes exactly one repo a real failure and turns the gate into a ratchet against creep for the rest. `soft_fail` — WARN by default, FAIL via `--fail-on=tier1-bloat` — because arming a brand-new threshold straight to FAIL would break Planitaria's next pre-commit over a budget invented that morning. The per-file 25 KB check is unchanged and stays advisory.

  **If this number is ever raised to make a failure go away, that is the defect and not the fix.** Page the content to Tier 2 instead.

  Verified: output byte-identical old-vs-new across all 11 repos except Planitaria gaining exactly the intended warning; `--fail-on=tier1-bloat` exits 1 there and 0 in a repo under budget.

- **v0.1.30** — **The template holds real copies again — a correction to v0.1.29, not a reversal of it.** v0.1.29 symlinked `templateRepo_EXAMPLE`'s skills and hooks to the workspace canonical. That is right for the ten *consuming* repos and wrong for the template, whose README opens with *"Use this template → Create a new repository, then clone it locally"*: it is built to leave this machine, and a relative symlink into `~/GitHub` dangles the instant it does. Verified against a real clone — four dangling links, both gates `rc=127`.

  The template can hold **plain** copies safely now, which it never could before, because the scripts resolve the carrier at runtime. What made the old copies corrupt was the **substitution**, not the copying. So: byte-identical copies, no substitution, and `init-project.sh` now excludes `.claude/skills/` and `.claude/hooks/` from token rewriting — without that it would rewrite the `'{{AI}}ai'` literal in the `IS_TEMPLATE` discriminator (making template mode, which *softens* checks, fire on seeded repos) and no-op `template_form()`'s own rule.

  **Ladder: `COPY` is tested before `SUBST`.** A file carrying no carrier token is byte-identical to its own template form, so the two rungs tie — and `handoff-gate.sh` reached zero tokens in v0.1.29, so a perfectly correct plain copy of it was reported as "retired template form", the gate inventing work out of a tie. Ties go to `COPY`, the weaker claim. In the template, `COPY` is the intended state and `DIVERGED` prescribes a re-copy; everywhere else `LINKED` is intended and the fix is a relink. Gate and `--maintenance` renderer branch together.

  `validate-substrate`'s leftover-placeholder check now mirrors init's exclusions — both **paths** (`stacks/`, `workspace/`, `init-project.sh`, `.claude/skills/`, `.claude/hooks/`) and **file types** (`*.md`, `*.sh`, `*.<ai>`, `*.hey<human>`). The check asks "did init finish?", so it must only look where init acts; a `{{TOKEN}}` anywhere else was never going to be filled. This took a false-positive count on a freshly seeded repo from **58 → 0**. It is the mention-vs-use distinction for the third and fourth time in this fleet, in two new forms: a script that names the token it substitutes, and a config comment documenting the convention. The last one was a comment written earlier the same day — the tempting fix was to reword it, which is precisely how a check stops describing reality.

  Verified end-to-end: a clone with **no workspace above it** runs both gates at 0 failures (canonical checks skip gracefully rather than failing); `init-project.sh` seeded a project under a **different duo** (`nova`/`sam`), left the tooling scripts byte-identical, and the seeded repo validates 0/0 after the one documented charter copy — which init now prints, with the exact command, only when it is actually missing. Fleet 11/11 unaffected.

- **v0.1.29** — **The carrier extension is resolved, not hardcoded.** `chloeai`/`heywy` were literals in 151 places across `sweep.sh`, `validate.sh`, `handoff-gate.sh` and `wrap-gate.sh`. They are now detected from the repo's own substrate, so `templateRepo_EXAMPLE` (whose files are named `_waystone.{{AI}}ai`, `readme_AI.{{AI}}ai`) and a seeded project run the SAME code path instead of two.

  This was queued as maintenance toil. It was not. The hand-regenerated "template form" copies it retires had silently produced **wrong code**, twice — and both were found by looking, not by a gate:

  1. **`heywy` names two different things.** As a filename suffix it is templated (`hey{{HUMAN}}`); as the waystone card's **inscription key** it is a fixed protocol name init never touches — the template's own card reads `heywy:`. A blind rewrite cannot tell them apart, so the template's copy grepped for `^hey{{HUMAN}}:` against a card saying `heywy:`. It never matched, and the doorway check lives *inside* that `if`, so it emitted no pass and no fail. Dead, and silent about being dead.
  2. **The rule corrupted its own guard.** `template_form()`'s double-substitution guard reads `($0 ~ /heywy/ && $0 ~ /hey\{\{HUMAN\}\}/)`; rendering rewrote the first half to `/hey{{HUMAN}}/`.

  The canonical was no better. Run inside the template, the old code printed `no waystones present (WISL not adopted in this repo)` **four times** — four green passes for checks that read nothing, on a repo that has a card. Both paths were blind at once.

  Consequences: the template stopped holding substituted copies (v0.1.30 settled it on **plain** copies — see below, the symlinking this entry originally described was wrong for a repo meant to be cloned away from the workspace); its **declared fork** of `validate-substrate` is retired (the canonical's output there is byte-identical to the fork it replaced); the `SUBST` rung of the canonicality ladder is retired, and a file still in template form now soft-fails with the `ln -sfn` that fixes it. Gate and `--maintenance` renderer share one prescription, so they cannot disagree the way they did in v0.1.24.

  Three defects were introduced and caught *during* this change, each by a test rather than by reading:
  - The ERE-escape helper used `sed 's/[][.{}()*+?^$|\\]/\\&/g'`; inside a bracket expression `[.` opens a POSIX **collating symbol**, so BSD sed rejected the class and returned **empty** — for `chloeai` as much as for the template. An empty suffix pattern matches nothing and passes, i.e. the helper written to prevent a silent pass would have manufactured one. Rewritten with `case` alternation, no bracket expression, plus a guard on its own output.
  - Detection used `[ -e ]`, which is **false for a dangling symlink** — and the human doorway *is* a symlink. A broken doorway made `HUMAN_EXT` undetectable, so the check reported MISSING when the truth was DANGLES. Now `-e || -L`.
  - Anchoring detection on `_waystone.*` alone would have broken **every newly-seeded repo**: `init-project.sh` deletes both root cards at seed time by design. Anchors are ordered now — the card first, then Tier-1 substrate that init renames rather than removes. Verified by actually running `init-project.sh` into a scratch repo and sweeping it.

  Verified behaviour-preserving: `sweep` and `validate` output is byte-identical old-vs-new across all 11 real repos, one deliberately improved message aside; fleet 11/11 at 0 failures / 0 warnings.

- **v0.1.28** — `_bounded` polls instead of spawning a sleeping killer. v0.1.27 shipped the obvious `( sleep N; kill $pid ) &` watchdog, which is correct but leaves the sleeper running for the remainder of its N seconds every time the probe finishes fast — that is, on every normal boot, since this runs from a SessionStart hook: one stray process per boot, still holding whatever descriptors it inherited. Polling costs a 1-second granularity nobody can perceive and leaves nothing behind; expiry returns 124, matching GNU `timeout`. Bumped rather than amended because v0.1.27 was already pushed, and a version number that means two different implementations is a small instance of exactly the drift this release closed. Verified: kills a 30 s sleep at ~3 s with rc 124, passes fast commands through unchanged, and the count of live `sleep` processes is unchanged after a bounded call that returns immediately.
- **v0.1.27** — `_bounded`: the network guard that was never actually there on this fleet's own machine. The backstop probe used `timeout`/`gtimeout` when present and **an empty string otherwise**, reasoning that `gh`'s own HTTP timeout would cover it. Stock macOS ships neither binary, the primary machine here is a Mac, and `gh` has no whole-operation deadline — so on the box these guards were written for there was no bound at all, and two of the three `gh` calls were unbounded even where `timeout` does exist. It stopped being theoretical when `wrap-gate.sh` — a SessionStart hook, so the **boot path** — ran past two minutes on a `gh` call and had to be killed by hand. Replaced with a bash-native watchdog (background the call, kill on expiry) needing no coreutils, applied to all three `gh` calls and to the hook's own outer bound; a probe that does not complete now prints `COULD NOT CHECK` rather than nothing, since silence reads as green. Same species as the v0.1.23 `_mtime` bug — a portability assumption that silently removed part of the mechanism on a real platform — but worse in one respect: there a *check* could not run and reported nothing, here a *guard* could not run, and an absent guard has no output at all until something hangs. Verified: watchdog kills a 30 s sleep at 3 s (rc 143) and passes fast commands through unchanged; wrap-gate 5 s, `--backstop-only` 3 s; the NOT-FOUND and gh-missing reporting paths both still fire after the refactor.
- **v0.1.26** — New `doc-version` category: the version a skill's `SKILL.md` claims must equal the version its script's banner declares (check 16 above). Built because the gap had cost the same thing twice — v0.1.19's entry records `sweep.sh`'s banner reading `v0.1.15` through four releases, and this file read `v0.1.21 (current)` through four releases while documenting a one-token substitution rule and a plain COPY as always-a-warn, neither of which had been true since v0.1.24/v0.1.25. It surfaced only because someone asked whether anything else needed adjusting, which is not a mechanism. Only currency **claims** are compared, never changelog history — that false positive is what would make the category ignorable. Verified against the real historical state (the actual stale `SKILL.md` and the actual `sweep.sh` at `7b195a0`), and it caught its own release twice over: bumping the banner to v0.1.26 turned the check red until this entry was written, and its **first real run flagged this file as a false positive** — the unanchored match read the *quoted* `v0.1.21 (current)` in the prose above as a live claim. That is the identical mention-vs-use defect fixed in `validate-substrate` hours earlier the same day, rebuilt from scratch in a different check by the same hands. Fixed by anchoring, not by rewording the doc; editing content to silence a gate is the reflex this fleet keeps writing entries about. Advisory-first, like every other `soft_fail` category here.
- **v0.1.25** — The canonicality ladder now **requires** template form in the template instead of merely permitting it: a plain byte-identical `COPY` fails there (it is the shape that shipped the v0.1.24 defect) and stays a WARN everywhere else, where the invariant is a symlink. `--maintenance` was corrected in the same change — it had been prescribing `ln -sf` for the template, an action that breaks the property the gate protects, and a renderer disagreeing with its gate is what cost a false `DIVERGED` in v0.1.24. `wrap-continuity` is exempt in the template (see check 11). Both hang off a new `IS_TEMPLATE` discriminator requiring **two** conditions — `init-project.sh` present **and** substrate still placeholder-named — because init-project.sh's self-delete is a prompt defaulting to NO, so its presence alone was true of seeded repos too. `validate-substrate`'s identical single-condition test was tightened at the same time; there it had been silently softening the placeholder check on real repos.
- **v0.1.24** — `template_form()`: ONE implementation of the canonical→template rule, used by both the gate and any re-sync, so the generator and the verifier cannot disagree (they did, mid-fix, producing a false `DIVERGED`). The rule also now covers **both** name tokens; it had only ever substituted the AI one. templateRepo's `sweep.sh` was a plain copy carrying 45 literal `.chloeai`, so a repo seeded under a different AI name got a drift-sweep hunting for another AI's files — it found nothing and reported CLEAN. Silent-pass class, shipped to third parties.
- **v0.1.23** — Portable `_mtime`. Two call sites used BSD `stat -f %m`; on the Linux CI runner GNU `stat` reads `-f` as *filesystem* and `%m` as a filename, printing `File: "..."` to stdout **and** exiting non-zero, so the `||` fallback also ran and the outputs concatenated into `line 1022: File: unbound variable`. The category had been incapable of executing on Linux since it was written — and a category that cannot run reports nothing, which reads identically to clean. Found within an hour of the CI backstop's first green run.
- **v0.1.22** — `--backstop-only`, so the backstop health band can be surfaced by `wrap-gate.sh` at every SessionStart. v0.1.21 built the check but left it behind `--maintenance`, which only runs on a dirty tree; the nightly sweep then failed **15 consecutive times** while the fleet still read 0 FAIL / 0 WARN. Building a check and leaving it on a manual invocation path reproduced, one release later, the exact failure the check was written to catch.
- **v0.1.21** — `--maintenance` now reports **backstop health**: the conclusion, age and failure streak of the server-side CI workflow, in its own band above the CHLOE/WY split. Built because the nightly `fleet-sweep` had failed **10 of 10 runs since it shipped** — every run, four days — while the fleet reported 0 FAIL / 0 WARN and nothing anywhere said the backstop had never once executed a sweep. Same failure class as the 17-day "skipping" capability gate and the four dead `validation:` fields, but inverted and worse: those render a broken state as a *wrong* state, which is at least visible in output; this rendered it as *no* state, because the only surface that knew was GitHub's web UI and nothing in the fleet reads that. Deliberately in `--maintenance` and not a gated category — it is the one probe that leaves the machine, and a network call has no business in a pre-commit hook. Fenced: owning repo only (must contain `.github/workflows/<BACKSTOP_WORKFLOW>`), `gh` required **and** authenticated, `timeout`/`gtimeout` where available. Every failure path prints `COULD NOT CHECK` rather than staying quiet — reporting the inability to check is the point, since a silent skip rebuilds the exact hole this closes. Distinguishes four states that a single "red" would blur: never-succeeded, recently-broken, green-but-stale, and 404 (gh resolves workflows on the **default branch**, so an unpushed or branch-only workflow reads as absent). Verified against all of them, plus the non-owning-repo, opt-out and `gh`-missing paths; normal sweep timing unchanged at 0.85 s with no network.
- **v0.1.20** — Added the `VERSIONED_BACKUP_ALLOWLIST` conf knob. The versioned-backup heuristic assumes a version in a filename means "stale copy"; sometimes the version IS the meaning. TFNerd pins `SDK_INVENTORY_v1230_2026_05_19.md` as the only surviving record of the PortalSDK v1.2.3.0 export surface — `PortalSDK/` is gitignored and overwritten in place, five files cite the snapshot, and renaming it would destroy the version it exists to record. Same shape as `ORPHAN_EXPORT_ALLOWLIST`: the repo declares its exception rather than the check guessing. Default `"^$"` exempts nothing, so no repo changes behavior until it opts in.
- **v0.1.19** — Added the report-only `validation-liveness` category, and documented the report-only set in a table for the first time. `validation-age` could say how long since a card's `validation:` passed but never whether it *could have failed*; five fleet cards could not. Planitaria's `src/model` ran a tsc pipeline ending in `echo`, so it exited 0 unconditionally for months while sitting next to a real `verified_at`. Four PocketLink cards ran `make build 2>&1 | tail -5` — `tail` masks the status, and there is no `build` target anyway, only a `build/` **directory** that make reports "up to date", so the command compiled nothing and reported success. Same species as the capability gate that printed "skipping" for 17 days: a check whose failure path renders as success. Static analysis only, no execution. Verified on a 13-case harness (6 dead / 7 live) and across all 57 fleet cards — 4 flagged, 0 false positives. The banner on line 2 of `sweep.sh` was also corrected; it had read `v0.1.15` through four releases, which is the same defect in miniature.
- **v0.1.18** — Added the gateable `skill-canonical` category and `--maintenance`, the wy/chloe split. `hook-canonical` works because hooks have one right answer: *be the canonical*. Skills don't — templateRepo_EXAMPLE holds two real skill copies identical in kind and opposite in intent (drift-sweep is a tracking copy; validate-substrate is a deliberate fork whose own engineering a blind copy would delete). Intent is now declared via `CANONICAL_FORK_SKILLS`, and `--maintenance` renders outstanding upkeep by decision-owner rather than by file. Mistaking a fork for a stale copy silently deletes work; mistaking a stale copy for a fork is how the fleet lost its capability gate for 17 days.
- **v0.1.17** — `probe-journal-in-diff` now exempts `.claude/skills/**`. Those are canonical tool sources whose headers carry a deliberate curated changelog (`sweep.sh`'s header is the authoritative version history), which is categorically different from the probe-iteration journaling the check exists to catch. In real repos those files are symlinks and never appear in a diff, so the check only ever fired on templateRepo_EXAMPLE's canonical-sync path — once per sync, never on a real defect. Verified narrow: identical version-bump content still FAILs under `src/` and is exempt only under `.claude/skills/`.
- **v0.1.16** — Added the gateable `hook-canonical` category: nothing was watching the hooks. `handoff-gate.sh` was found forked in **all eleven repos**, in three distinct stale versions, none following THR-020/ADR-012's rename of `recommended_model=` → `recommended_capability=`; the capability STOP-THE-LINE was dead fleet-wide for ~17 days and reported itself as `skipping`, which reads as a pass. Root cause was an asymmetry inside one directory: `.claude/skills/` are **symlinks** to the workspace canonical and never drifted, while `.claude/hooks/` were **copies** and rotted. Hooks are now symlinked too; this category is the backstop for what a symlink cannot cover (a repo that de-symlinks, and the template, which must ship real files for its `{{AI}}` placeholders). The unlinked-but-identical tier is a deliberate WARN.
- **v0.1.10–v0.1.15** — (docs gap; entries not backfilled here.) `sweep.sh`'s own header carries the authoritative changelog for these: added-file threshold exclusion, the `verified_at` → `reviewed_at`/`validated_at` split, branch visibility, boot-source deliverability, ownership coverage, and the report-only age categories.
- **v0.1.9** — Added the gateable `wrap-continuity` category: the Agent Boot Contract W1 WRITE-edge floor (ADR-BOOT-001). Git-native session-wrap gate at the commit edge — carrier lag threshold (`WRAP_LAG_WARN`, default 10) with staged-carrier-passes-as-wrap; carrier auto-detection (`readme_AI.chloeai` / workspace HANDOFF log) with `WRAP_CARRIER` override; graceful where no carrier exists, so the symlinked fleet rollout is advisory-only until a repo arms it. Proven by a 10-case scenario harness. Closes the any-agent wrap gap (wrap discipline previously lived only in Claude-native SessionStart hooks).
- **v0.1.7–v0.1.8** — (docs catch-up; SKILL.md previously stopped at v0.1.6.) v0.1.7: advisory `wisl-graph` (waystone edge connectivity) + `seam-coverage` (seam-map folders must carry waystones) categories. v0.1.8: `up-sync` and `waystone-freshness` became STAGED-AWARE, and waystone-freshness was reframed from a `verified_at` SHA-range diff to commit-time RECENCY — both one-commit committed-history lags closed (SESSION-053c; re-stamp an owned waystone in the SAME commit as its files).
- **v0.1.6** — Added the gateable `up-sync` category + a new `soft_fail()` helper (WARN by default, hard-FAIL only when the category is named in `--fail-on`). Catches up-sync drift: when a repo's `readme_AI.chloeai` moves without a matching `ai_context/upsync.chloeai` block, headline state has changed without propagating upward to the workspace ledgers (ROSTER / fleet / HANDOFF). Opt-in by hint-file presence → inert fleet-wide until a repo adopts it. The deterministic teeth for the SESSION-039 up-sync write-path (paired with the charter PROPAGATE-UP wrap step + the SessionStart model/effort gate).
- **v0.1.5** — Added the gateable `waystone-freshness` category: enforces the WISL `owns`↔`verified_at` freshness binding (WISL-STANDARD §Enforcement) — a waystone whose owned files changed since its `verified_at` FAILs, **excluding the waystone file itself** (pilot friction #1). Inert (graceful pass) where no `_waystone.chloeai` exists, so it ships fleet-wide safely before any waystone merges. Quote-tolerant `verified_at` parse (friction #6).
- **v0.1.4** — Added advisory (warn-only) `tier1-bloat` check: flags always-loaded substrate files over `TIER1_BLOAT_WARN_KB` (default 25). Makes the ADR-004 paging discipline self-policing fleet-wide so the charter-127KB read-path pattern cannot silently recur. New config: `TIER1_FILES`, `TIER1_BLOAT_WARN_KB`.
- **v0.1.3** — DO-007: `--quiet`, `--json`, and `--fail-on=<categories>` flags. `--fail-on` enables selective pre-commit gating without blocking on orphans or freshness.
- **v0.1.2** — DO-016: skip `type`/`interface` exports in orphan check (structural TS API surface, not runtime drift). DO-017: CLAUDE.md path-rules table regex accepts any column count after `Glob` (2-col or 3-col format).
- **v0.1.1** — orphan check strips comment-leader lines before counting refs, eliminating false positives from stale inline comments.
- **v0.1** — initial implementation; check categories above.
- **v1.0 (planned)** — class-method orphan detection (currently only top-level exports are checked; dead class methods are invisible to the script), template-mode self-test, comment-claim mismatch with sane heuristics.
