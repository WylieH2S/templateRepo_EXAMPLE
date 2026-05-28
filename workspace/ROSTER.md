# Repo Roster

Lifecycle status across all projects in `~/Documents/Projects/GitHub/`.
Update when a repo changes status. The AI repo manager reads this at boot.

**Last updated:** (fill in date)

---

## Status Definitions

| Status | Meaning |
|--------|---------|
| **ACTIVE** | Currently being developed. Expect commits this week. |
| **MAINTAINED** | Stable, occasional updates, no roadmap. |
| **DORMANT** | Project is real but paused. Substrate is up-to-date, no active code work. |
| **HELD** | Explicitly on pause by decision (vs. just inactive). May resume. |
| **BLOCKED** | Cannot progress without external input (decision, hardware, data). |
| **NEW** | Just initialized. Substrate exists, no code yet. |
| **TEMPLATE** | Reference repo, not a project itself. |
| **ARCHIVED** | Frozen. Do not modify. |

---

## Roster

| Repo | Status | Stack | Description | Active Focus |
|------|--------|-------|-------------|--------------|
| **templateRepo_EXAMPLE** | TEMPLATE | n/a | Canonical project template | Source of stack packs, lefthook, GH Actions, validate-substrate |
| *(add your repos here)* | | | | |

---

## Conventions

- All repos use the two-tier load model (CLAUDE.md routing → ai_context/ + .claude/rules/)
- All repos use the AI substrate (readme_AI.{{AI}}ai, AI_HANDOFF.{{AI}}ai, WORKSHEET.hey{{HUMAN}}, SIDEQUESTS.{{AI}}ai)
- All repos are SSH-remoted to `git@github.com:GITHUB_USERNAME/<repo>.git`
- All repos are private unless explicitly marked PUBLIC

## Status Triggers — When to Update This File

- A repo crosses from DORMANT → ACTIVE (real dev work starting)
- A repo crosses from ACTIVE → DORMANT (work paused, no roadmap)
- A repo is archived or sunset
- A new repo is added to the GitHub folder
- A repo's stack changes (e.g., from "TBD" to a concrete choice)
