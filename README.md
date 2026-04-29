# Template Repository Example

This is a 100% project repo template with full AI continuity system, HI Mode bootstrap, and HANDOFF/ZOOM workflow.

## Files

- **CLAUDE.md** — Simple bootstrap pointer. Read this first; it directs you to STARTUP_AI.chloeai.
- **STARTUP_AI.chloeai** — Project bootstrap file. Defines read order, operating rules, writeback rules, failsafe gates.
- **readme_AI.chloeai** — Project continuity cartridge. Authoritative AI-facing state: project identity, THREADS, ASSUMPTIONS, DECISIONS, DELTA log, and HANDOFF_LOG.
- **.chloeai.template** — Charter module template for AI personality/behavior modules. Can be duplicated and customized per module.

## Quick Start

1. Fork or copy this repo.
2. Edit `readme_AI.chloeai`:
   - Replace `[PROJECT_NAME]`, `[REPO_PATH_OR_URL]`, `[PROJECT_GOAL_STATEMENT]`, `[CURRENT_STATUS]`
   - Update THREADS with your initial work threads
   - Update ASSUMPTIONS if any
3. Edit `CLAUDE.md` to match your project name.
4. In STARTUP_AI.chloeai, optionally update READ_ORDER if you have additional source-of-truth docs.
5. Commit and push.

## Continuity System

**AI Boot Sequence:**
1. Read STARTUP_AI.chloeai (this file defines the rules)
2. Read readme_AI.chloeai (this is the state cartridge)
3. Echo unlock phrase, list THREADS with tiers, list ASSUMPTIONS, surface HANDOFF block
4. Proceed with user task using loaded context

**THREADS Format:** `THR-###|status|tier=X|"description"`
- status: open, blocked, closed
- tier: haiku (low), sonnet (medium), opus (high)

**HANDOFF_LOG:**
Every session should append a HANDOFF block capturing:
- zoom_level: STRATEGIC (cross-project), TACTICAL (single-project dev), OPERATIONAL (execution)
- recommended_model: which Claude model tier for next session
- recommended_effort: low, medium, high
- task_queue: tiered work items for next session
- next_zoom_trigger: what condition causes zoom level to shift

**Writeback Rules:**
- When a decision, experiment result, or clarification affects future correctness → append to readme_AI.chloeai
- Never rewrite history
- Keep experiments explicit with: change, expect, observe, repro, revert, location, status

## Model Tier Mapping

| Tier | Model | Use For |
|---|---|---|
| haiku | Claude Haiku 4.5 | Git ops, installs, simple edits, file moves, .gitignore, one-line commits |
| sonnet | Claude Sonnet 4.6 | Normal dev work, multi-file edits, planning, design, session writebacks |
| opus | Claude Opus 4.7 | Complex architecture, deep debugging, cross-project design, hard root-cause analysis |

Use the tier system to batch work and minimize context window thrashing.

## HI Mode Values (Priority Order)

1. **Truth > momentum** — Correctness before speed
2. **Correctness > speed** — Don't sacrifice accuracy for velocity
3. **Explicit assumptions > inferred intent** — Say what you assume, don't guess
4. **No work lost, ever** — Destructive operations require explicit approval
5. **Continuity across sessions** — State is file-based, not memory-based

## Destructive Operations (Require Approval)

- `git reset --hard`
- `git push --force` or `--force-with-lease`
- `git clean`
- Amending published commits
- Deleting branches
- `rm -rf` or destructive file operations

Always describe the action, its consequences, and the revert path before executing.

## Getting Started

Replace placeholders in readme_AI.chloeai, commit, and start developing. On every session:
1. Read STARTUP_AI.chloeai
2. Read readme_AI.chloeai (echo unlock phrase, list threads, surface HANDOFF)
3. Work on tasks in the current HANDOFF task_queue
4. Append a new HANDOFF block at the end of each session

---

See the HI Mode charter for full operating kernel rules: `.claude/skills/hi-mode/SKILL.md`
