# {{PROJECT_NAME}} -- AI Context Package

> You are an AI working on {{PROJECT_NAME}}. This folder is your intro package.
> Read this file first. It tells you what everything is and where to go next.

---

## Boot Sequence

**You are here because `STARTUP_AI.chloeai` sent you.** `STARTUP_AI.chloeai` is the authoritative READ_ORDER source — follow what it tells you to read, in the order it tells you. This file is the file map and conventions reference, not a competing boot sequence.

The order STARTUP_AI specifies (for context):
1. `readme_AI.chloeai` — active state
2. `ai_context/START_HERE.md` — this file
3. `ai_context/ai_rules.chloeai` — hard constraints
4. `ai_context/glossary.chloeai` — terminology
5. `ai_context/project_brief.md` — what the project IS
6. `ai_context/CURRENT_MISSION.md` — active scope, stop conditions
7. `ai_context/current_state.md` — version, status, open items
8. `WORKSHEET.heywy` — human input channel
9. `AI_HANDOFF.chloeai` — last 2–3 session entries

After boot: echo the unlock phrase, list THREADS, list ASSUMPTIONS, restate the current mission in one sentence, check for new human input.

### Drift Check (mandatory before acting)

Before choosing any work:
- Run `git status` — confirm `current_state.md`'s "Current Branch" matches reality. If they disagree, the state notes are stale; surface via STOP-THE-LINE.
- Check Tier 1 line counts against the audit in `CLAUDE.md`. If a Tier 1 file has grown >25% beyond its audited count, flag as substrate creep — log a CLAR-N and ask the user before proceeding.
- If `current_state.md` references a milestone or branch that no longer exists, do not assume the milestone is incomplete — verify with `git log` and the actual files.

**Fresh project detection:** If `project_brief.md` and `CURRENT_MISSION.md` still contain `<!-- fill in -->` or placeholder comments, this is a new project with no captured intent yet. Before choosing any work, invoke `ai_modules/brainstorming.chloeai` and run its protocol with `{{OWNER_NAME}}`. The skill defines the question discipline, design presentation, writeback targets, and the hard gate: no implementation until the captured design is approved.

**Mandatory work gate:** Before any code change, fill the task contract from `CURRENT_MISSION.md`. If the contract is fuzzy, stop.

---

## File Map

### This folder (`ai_context/`)
| File | Purpose | Update frequency |
|------|---------|-----------------|
| `START_HERE.md` | This index. Boot order, file map, conventions. | Rarely |
| `ai_rules.chloeai` | Project-wide hard constraints. Tier 1. | When new project rules are established |
| `glossary.chloeai` | File-type conventions and terminology. Tier 1. | When new terms are established |
| `project_brief.md` | What this project is. Architecture, glossary. | Rarely |
| `CURRENT_MISSION.md` | Mission-control layer: active priority, scope, out-of-scope, stop conditions, task contract. | Whenever focus or priority changes |
| `technical_reference.md` | Stack rules, build/test commands, known gotchas. | When new facts are confirmed |
| `current_state.md` | Version, status, open items, recent deltas. | Every session that changes code |
| `decision_log.md` | Key decisions that still affect current work. | When decisions are made or superseded |
| `decisions/` | ADR archive. Tier 2 — read on demand for architectural questions. | When architectural decisions are made |
| `readme_AI_archive.chloeai` | Historical threads, decisions, delta, old handoffs. Tier 2. | When readme_AI.chloeai overflows |

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

### Path-scoped rules (`.claude/rules/`)
Loaded on demand when matching paths are touched. Fill in for your project.

| File | Glob | Purpose |
|------|------|---------|
| `.claude/rules/code.chloeai` | `src/**`, `lib/**` | Language, build, style conventions |
| `.claude/rules/tests.chloeai` | `tests/**`, `spec/**` | Test conventions and forbidden patterns |
| `.claude/rules/ai-context.chloeai` | `ai_context/**`, `ai_modules/**` | AI file editing rules and writeback targets |
| `.claude/rules/docs.chloeai` | `docs/**` | Documentation format and ownership rules |

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
