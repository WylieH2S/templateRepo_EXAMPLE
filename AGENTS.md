# AGENTS.md

<INSTRUCTIONS>
Use `STARTUP_AI.{{AI}}ai` as the repo bootstrap. Follow its READ_ORDER section in order.

Read `readme_AI.{{AI}}ai` before analysis or execution when repo access exists.

Treat the `ai_context/` package as the evolving project continuity. The lean entry point is `ai_context/START_HERE.md`.

The always-loaded (Tier 1) set is exactly these seven, and it is budget-gated at **≤750 lines total**:
`STARTUP_AI.{{AI}}ai`, `readme_AI.{{AI}}ai`, `CLAUDE.md`, `ai_context/ai_rules.{{AI}}ai`,
`ai_context/glossary.{{AI}}ai`, `ai_context/CURRENT_MISSION.md`, `ai_context/START_HERE.md`.
Everything else is Tier 2 — read it on demand, do not add it to the boot path. Adding a file to
Tier 1 means adding it to `CLAUDE.md`, the HI Mode charter, and drift-sweep's `TIER1_FILES`
together; those three disagreed for months and the budget silently meant nothing.

When decisions, experiments, clarifications, or failures materially affect future correctness:
- append a session entry to `AI_HANDOFF.{{AI}}ai`
- update `ai_context/current_state.md` (version, status, open items)
- log decisions in `ai_context/decision_log.md` if they remain in effect

Prefer deterministic, explicit behavior over inferred intent. If required context is missing or stale, STOP and ask.

Unlock phrase (echo at session start): "{{UNLOCK_PHRASE}}"
</INSTRUCTIONS>
