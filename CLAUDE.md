# {{PROJECT_NAME}}

AI bootstrap: read `STARTUP_AI.chloeai` before any analysis or execution. STARTUP_AI is the authoritative READ_ORDER source; this file is the routing table.

## Always-Loaded (Tier 1)

Budget target: ≤ 200 lines total across all Tier 1 files. Audit periodically to catch creep — drift here directly degrades every session's boot quality.

**Last audited:** {{TODAY}}

| File | Purpose | Lines (audited) |
|------|---------|-----------------|
| `STARTUP_AI.chloeai` | Boot file (READ_ORDER + operating rules) | — |
| `readme_AI.chloeai` | Active threads + latest handoff | — |
| `ai_context/ai_rules.chloeai` | Project-wide hard constraints | — |
| `ai_context/glossary.chloeai` | File-type conventions and terminology | — |
| `ai_context/START_HERE.md` | File map and conventions reference | — |

> Populate the line counts after first real session via:
> `for f in STARTUP_AI.chloeai readme_AI.chloeai ai_context/ai_rules.chloeai ai_context/glossary.chloeai ai_context/START_HERE.md; do wc -l "$f"; done`

## Path-Scoped Rules (load when matching paths are touched)

| Glob | Rules file |
|------|-----------|
| `src/**`, `lib/**` | `.claude/rules/code.chloeai` |
| `tests/**`, `spec/**` | `.claude/rules/tests.chloeai` |
| `ai_context/**`, `ai_modules/**` | `.claude/rules/ai-context.chloeai` |
| `docs/**` | `.claude/rules/docs.chloeai` |

## On-Demand Reference (Tier 2 — read when needed, not every session)

| File | When to read |
|------|-------------|
| `ai_context/decisions/` | Architectural or convention questions |
| `ai_context/readme_AI_archive.chloeai` | Historical threads and handoffs |
| `ai_context/decision_log.md` | Decisions currently in effect |
| `AI_HANDOFF.chloeai` | Cross-session AI journal |
| `ai_context/technical_reference.md` | Stack-specific build commands, tools, gotchas |
| `ai_context/CURRENT_MISSION.md` | Restate active mission before code changes |
| `ai_context/project_brief.md` | Project identity / scope questions |
| `.claude/templates/` | Boilerplate starters — `TEMPLATE_skill` for new skills, `TEMPLATE_task` for new task defs, `TEMPLATE_cartridge` for new .chloeai files |
| `.claude/skills/` | Custom skills available in this repo (e.g. `validate-substrate`) |

## Operating Charter

`ai_modules/hi_mode.chloeai` — HI Mode personality. Truth > momentum. Stop-the-line is mandatory.
