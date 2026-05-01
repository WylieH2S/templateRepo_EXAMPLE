# {{PROJECT_NAME}}

AI bootstrap: read `STARTUP_AI.chloeai` before any analysis or execution.

## Always-Loaded (Tier 1)

| File | Purpose |
|------|---------|
| `readme_AI.chloeai` | Active threads + latest handoff |
| `ai_context/START_HERE.md` | Boot sequence and file map |
| `ai_context/CURRENT_MISSION.md` | Active scope, stop conditions, task contract |
| `ai_context/ai_rules.chloeai` | Project-wide hard constraints |
| `ai_context/glossary.chloeai` | File-type conventions and terminology |

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

## Operating Charter

`ai_modules/hi_mode.chloeai` — HI Mode personality. Truth > momentum. Stop-the-line is mandatory.
