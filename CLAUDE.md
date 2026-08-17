# {{PROJECT_NAME}}

AI bootstrap: read `STARTUP_AI.{{AI}}ai` before any analysis or execution. STARTUP_AI is the authoritative READ_ORDER source; this file is the routing table.

## Always-Loaded (Tier 1)

Budget: **≤ 750 lines total** across all Tier 1 files, enforced by drift-sweep's `tier1-bloat` category (`soft_fail` — WARN by default, FAIL via `--fail-on=tier1-bloat`). Drift here directly degrades every session's boot quality.

> The set below is authoritative and must stay identical to the HI Mode charter's LOAD ECONOMICS list and drift-sweep's `TIER1_FILES`. Those three disagreed until 2026-08-16, which is why the old ≤200 budget went unmet by every repo and unnoticed by everything. Do not add a file here without adding it to the other two.

**Last audited:** {{TODAY}}

| File | Purpose | Lines (audited) |
|------|---------|-----------------|
| `STARTUP_AI.{{AI}}ai` | Boot file (READ_ORDER + operating rules) | — |
| `readme_AI.{{AI}}ai` | Active threads + latest handoff | — |
| `CLAUDE.md` | This file — path-to-rule routing table | — |
| `ai_context/ai_rules.{{AI}}ai` | Project-wide hard constraints | — |
| `ai_context/glossary.{{AI}}ai` | File-type conventions and terminology | — |
| `ai_context/CURRENT_MISSION.md` | Active priority, scope, stop conditions | — |
| `ai_context/START_HERE.md` | File map and conventions reference | — |

> Populate the line counts after first real session via:
> `for f in STARTUP_AI.{{AI}}ai readme_AI.{{AI}}ai CLAUDE.md ai_context/ai_rules.{{AI}}ai ai_context/glossary.{{AI}}ai ai_context/CURRENT_MISSION.md ai_context/START_HERE.md; do wc -l "$f"; done`
>
> Or just read the number drift-sweep already computes: `bash .claude/skills/drift-sweep/sweep.sh . | grep "tier1 aggregate"`

## Path-Scoped Rules (load when matching paths are touched)

| Glob | Rules file |
|------|-----------|
| `src/**`, `lib/**` | `.claude/rules/code.{{AI}}ai` |
| `tests/**`, `spec/**` | `.claude/rules/tests.{{AI}}ai` |
| `ai_context/**`, `ai_modules/**` | `.claude/rules/ai-context.{{AI}}ai` |
| `docs/**` | `.claude/rules/docs.{{AI}}ai` |

## On-Demand Reference (Tier 2 — read when needed, not every session)

| File | When to read |
|------|-------------|
| `ai_context/decisions/` | Architectural or convention questions |
| `ai_context/readme_AI_archive.{{AI}}ai` | Historical threads and handoffs |
| `ai_context/decision_log.md` | Decisions currently in effect |
| `AI_HANDOFF.{{AI}}ai` | Cross-session AI journal |
| `ai_context/technical_reference.md` | Stack-specific build commands, tools, gotchas |
| `ai_context/CURRENT_MISSION.md` | Restate active mission before code changes |
| `ai_context/project_brief.md` | Project identity / scope questions |
| `.claude/templates/` | Boilerplate starters — `TEMPLATE_skill` for new skills, `TEMPLATE_task` for new task defs, `TEMPLATE_cartridge` for new .{{AI}}ai files |
| `.claude/skills/` | Custom skills available in this repo (e.g. `validate-substrate`) |

## Operating Charter

`ai_modules/hi_mode.{{AI}}ai` — HI Mode personality. Truth > momentum. Stop-the-line is mandatory.
