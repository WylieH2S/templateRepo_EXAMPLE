# Template Repository Example

Canonical project template with the full two-tier AI continuity system, HI Mode bootstrap, stack starter packs, and HANDOFF/ZOOM workflow.

## Quick Start

```bash
cp -r templateRepo_EXAMPLE/ MyProject/
cd MyProject
bash init-project.sh
```

`init-project.sh` prompts for project metadata + stack choice, copies the chosen stack pack into `.claude/rules/`, substitutes placeholder tokens across all files, seeds ADR-001 for the stack choice, then self-deletes.

After bootstrap:
1. `brew install lefthook && lefthook install` (activates pre-commit guards)
2. Fill in `ai_context/project_brief.md` and `ai_context/CURRENT_MISSION.md`
3. `git init && git add . && git commit -m "bootstrap: MyProject"`

## Entry Points

| File | Purpose |
|---|---|
| `CLAUDE.md` | Path-routing table. Auto-loaded by Claude Code. Defines Tier 1 / path-scoped / Tier 2 file layout. |
| `STARTUP_AI.ai` | Boot file. Defines READ_ORDER and operating rules. Tool-agnostic — Codex and other agents read this too. |
| `readme_AI.ai` | Active state cartridge: THREADS, ASSUMPTIONS, latest HANDOFF. |
| `AGENTS.md` | Pointer for non-Claude agents. |
| `init-project.sh` | One-shot bootstrap (self-deletes after run). |

## Substrate Layout

| Path | Purpose |
|---|---|
| `ai_context/` | Tier 2 reference package: START_HERE, ai_rules, glossary, project_brief, CURRENT_MISSION, current_state, decision_log, decisions/, technical_reference, readme_AI_archive |
| `ai_modules/` | HI Mode personality shim + brainstorming + systematic_debugging skill modules |
| `.claude/rules/` | Path-scoped rules (code, tests, ai-context, docs) — loaded only when matching paths are touched |
| `.claude/skills/` | Skills like `validate-substrate` |
| `.claude/templates/` | Boilerplate starters (TEMPLATE_cartridge, TEMPLATE_skill, TEMPLATE_task, etc.) |
| `stacks/` | 12 stack starter packs (ts-node, python, swift-ios, go, rust, java-spring, kotlin, ruby-rails, elixir-phoenix, dotnet, php-laravel, generic). Init script copies one into `.claude/rules/` then offers to delete the rest. |
| `lefthook.yml` | Pre-commit guards (junk files, secrets, large files) |
| `.github/workflows/guards.yml` | CI mirror of the same guards |

## HI Mode

The operating charter — values, stop-the-line, git safety, design review gate, zoom levels, session wrap. Per-project `ai_modules/hi_mode.ai` is a thin EXTENDS shim pointing to the central charter at `~/.claude/skills/hi-mode/SKILL.md`. The shim may ADD project-specific overrides but cannot remove or override central rules.

Top values (priority order):
1. Truth > momentum
2. Correctness > speed
3. Explicit assumptions > inferred intent
4. No work lost, ever
5. Continuity across sessions

## Validate

```bash
bash .claude/skills/validate-substrate/validate.sh
```

Checks Tier 1 file presence, path-scoped rules, ai_modules, EXTENDS path resolution, tracked junk, unfilled placeholder tokens, freshness (90-day window), and size sanity. Detects "template mode" via the presence of `init-project.sh` and softens checks that only apply post-bootstrap.

## HANDOFF / ZOOM / Tier Format

Every session appends a HANDOFF block to `readme_AI.ai`:

```
@YYYY-MM-DD|SESSION-N|
zoom_level=STRATEGIC|TACTICAL|OPERATIONAL
recommended_model=haiku|sonnet|opus
recommended_effort=low|medium|high
reason="..."
task_queue=[{tier:X, task:"..."}, ...]
next_zoom_trigger="..."
signed="Model | charter version | date"
```

Tier mapping:

| Tier | Model | Use for |
|---|---|---|
| haiku | Claude Haiku 4.5 | Git ops, file moves, .gitignore, one-line commits |
| sonnet | Claude Sonnet 4.6 | Normal dev, multi-file edits, planning, writebacks |
| opus | Claude Opus 4.7 | Architecture, deep debugging, cross-project design |

THREADS format: `THR-###|status|tier=X|"description"` where status is `open|blocked|closed` and tier is `haiku|sonnet|opus`.

## Codex / non-Claude agents

The substrate is model-agnostic. Read order, HANDOFF format, and writeback rules apply to any agent. See `AGENTS.md` for the entry point. Substitute Claude tier names with model-equivalents in HANDOFF blocks (e.g. `recommended_model=gpt-4`).

---

See the HI Mode charter for full operating kernel: `~/.claude/skills/hi-mode/SKILL.md`
