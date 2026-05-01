# {{PROJECT_NAME}} -- Project Instructions

## AI Context Package
The full AI intro package lives in `ai_context/`. Start with `ai_context/START_HERE.md` -- it explains every file, the boot sequence, and how to hand off between sessions.

Key entry points:
- `ai_context/START_HERE.md` -- boot sequence and file map
- `ai_context/CURRENT_MISSION.md` -- mandatory mission-control layer: current priority, scope, stop conditions, task contract
- `readme_AI.chloeai` -- lean pointer to the context package
- `WORKSHEET.heywy` -- {{OWNER_NAME}}'s input channel (test reports, answers, notes)
- `AI_HANDOFF.chloeai` -- shared AI-to-AI session journal (append-only)

## Operating Charter
Operate under the project's HI Mode personality module: `ai_modules/hi_mode.chloeai`.
Truth > momentum. Stop-the-line is mandatory. No inferred intent.

## Session Start Checklist
Every session, before doing any work:
1. Read `ai_context/START_HERE.md` -- follow the boot sequence
2. Read `ai_context/CURRENT_MISSION.md` -- restate active scope before choosing work
3. Read `WORKSHEET.heywy` -- check for test reports, answered questions, or notes
4. Skim recent entries in `AI_HANDOFF.chloeai` -- recover latest session context
5. Act on any new input (update state, adjust code, answer back)
6. Move handled test reports to the HISTORY section of the worksheet
7. Update the CURRENT VERSION line in the worksheet if it's stale

## Code Change Gate
Before any code change, fill the task contract from `ai_context/CURRENT_MISSION.md`:

```
Task:
Blocker:
Design intent served:
Subsystem:
Files likely touched:
Explicitly not touching:
Expected result:
Live test:
Revert path:
```

If the contract is fuzzy, stop instead of coding.

## Project-Specific Rules
<!-- Replace with project-specific rules: language version pins, build/test commands,
     framework gotchas, conventions to follow, file conventions to respect. -->
- (none yet)
