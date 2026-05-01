# {{PROJECT_NAME}} -- AI Context Package

> You are an AI working on {{PROJECT_NAME}}. This folder is your intro package.
> Read this file first. It tells you what everything is and where to go next.

---

## Boot Sequence

Follow this order every session:

1. **Read this file** -- you're here, good.
2. **Read `project_brief.md`** (this folder) -- what the project IS.
3. **Read `CURRENT_MISSION.md`** (this folder) -- what matters RIGHT NOW, active scope, stop conditions.
4. **Read `technical_reference.md`** (this folder) -- stack rules, build/test commands, known gotchas.
5. **Read `current_state.md`** (this folder) -- version, status, open items, recent changes.
6. **Read `decision_log.md`** (this folder) -- decisions still in effect.
7. **Read `WORKSHEET.heywy`** (repo root) -- {{OWNER_NAME}}'s input channel. Check for new test reports, answered questions, or notes.
8. **Read `AI_HANDOFF.chloeai`** (repo root) -- recent session journal entries. Skim the last 2-3 entries, not the whole file.
9. **Read the operating charter** -- `ai_modules/hi_mode.chloeai`. It defines how we work.

After boot: echo the unlock phrase, list THREADS, list ASSUMPTIONS, restate the current mission in one sentence, check for new human input, and start working.

**Fresh project detection:** If `project_brief.md` and `CURRENT_MISSION.md` still contain `<!-- fill in -->` or placeholder comments, this is a new project with no captured intent yet. Before choosing any work, invoke `ai_modules/brainstorming.chloeai` and run its protocol with `{{OWNER_NAME}}`. The skill defines the question discipline, design presentation, writeback targets, and the hard gate: no implementation until the captured design is approved.

**Mandatory work gate:** Before any code change, fill the task contract from `CURRENT_MISSION.md`. If the contract is fuzzy, stop.

---

## File Map

### This folder (`ai_context/`)
| File | Purpose | Update frequency |
|------|---------|-----------------|
| `START_HERE.md` | This index. Boot order, file map, conventions. | Rarely |
| `project_brief.md` | What this project is. Architecture, glossary. | Rarely |
| `CURRENT_MISSION.md` | Mission-control layer: active priority, scope, out-of-scope, stop conditions, task contract. | Whenever focus or priority changes |
| `technical_reference.md` | Stack rules, build/test commands, known gotchas. | When new facts are confirmed |
| `current_state.md` | Version, status, open items, recent deltas. | Every session that changes code |
| `decision_log.md` | Key decisions that still affect current work. | When decisions are made or superseded |

### Repo root
| File | Purpose | Notes |
|------|---------|-------|
| `readme_AI.chloeai` | Entry point -- points here. | Lean pointer, not the cartridge |
| `STARTUP_AI.chloeai` | Tool-agnostic boot file. | Read by any AI; defines READ_ORDER |
| `WORKSHEET.heywy` | {{OWNER_NAME}}'s input channel. Test reports, answers, notes. | Check every session. Move handled items to HISTORY. |
| `AI_HANDOFF.chloeai` | Shared AI-to-AI session journal. Append-only. | Add an entry when your session materially changes code or direction |
| `SIDEQUESTS.chloeai` | Cross-project parked-idea bank. | Drop ideas that came up but don't belong to this project |
| `CLAUDE.md` | Claude Code auto-read project instructions. | Auto-loaded by Claude Code; other AIs read manually |
| `AGENTS.md` | Pointer for non-Claude agents. | Codex and other tools read this |

### Operating charter
| File | Purpose | Notes |
|------|---------|-------|
| `ai_modules/hi_mode.chloeai` | High-Integrity Mode personality module. | How we work: truth>momentum, stop-the-line, no inferred intent |
| `ai_modules/brainstorming.chloeai` | Intent capture protocol. | Triggers when project_brief.md is empty or owner asks to "plan a feature" |
| `ai_modules/systematic_debugging.chloeai` | 4-phase root-cause protocol. | Triggers when bug reported or 2+ fix attempts have failed |

---

## File Conventions

Two custom file types exist in this project:

- **`.chloeai`** -- AI-facing: memory, state, decisions, experiments. Source of truth for AI continuity.
- **`.heywy`** -- Human-facing: worksheets, test reports, Q&A. {{OWNER_NAME}}'s input channel.

Any AI reading this repo should recognize both file types.

---

## Session Handoff Protocol

When your session materially changes code, continuity, or design direction, append an entry to `AI_HANDOFF.chloeai`:

```
@YYYY-MM-DDTHH:MM-zzzz|SESSION|
ai_name="..."|
model="..."|
focus_mode="..."|
time_range="..."|
summary="1-3 sentence summary of what changed or was concluded."|
changed="Files modified, or 'none'."|
observed="Test results, failures, or repo facts established."|
next="Concrete recommended next step(s)."|
signature="AI name | model | focus mode | timestamp range"
```

Also update `current_state.md` in this folder if the version, status, or open items changed.

---

## Unlock Phrase

"{{UNLOCK_PHRASE}}"

---

## Who is {{OWNER_NAME}}?

The project owner, product manager, and final decision-maker. Sets direction, priorities, constraints, and acceptance criteria. Tests and reports results in `WORKSHEET.heywy`.

Preferences:
<!-- Replace with project-specific preferences. Examples:
     - Long-term fixes over band-aids
     - Version bumped with every edit
     - Visual diagrams when debugging complex logic -->
- (fill in)

---

_Last updated: {{TODAY}}_
