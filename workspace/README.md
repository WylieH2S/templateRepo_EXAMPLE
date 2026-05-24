# GitHub Workspace

Parent folder for WORKSPACE_OWNER projects. Each subdirectory is an independent git repo. This folder itself is **not** a git repo — it holds cross-cutting workspace state for the AI repo manager.

## Quick map

| Path | What |
|------|------|
| `ROSTER.md` | Lifecycle status of every repo (read this first to see what's hot vs. cold) |
| `CLAUDE.md` | AI session entry point — boot sequence (Claude Code) |
| `AGENTS.md` | AI session entry point — universal format for any AI agent |
| `.claude/skills/hi-mode/SKILL.md` | HI Mode charter with append-only HANDOFF LOG |
| `.repo-manager/` | Fleet drift log, playbooks, between-session inbox |
| `<repo>/` | Individual project repos, each self-contained with own substrate |

## Conventions

- All projects use the two-tier load model (`CLAUDE.md` routing → `ai_context/` + `.claude/rules/`)
- All projects use the `.chloeai` continuity substrate (`readme_AI`, `AI_HANDOFF`, `WORKSHEET`, `SIDEQUESTS`)
- All projects are remoted to `git@github.com:GITHUB_USERNAME/<repo>.git`
- All projects are private unless explicitly marked otherwise in `ROSTER.md`

## Workflow

- **Starting an AI session** — read `CLAUDE.md` (Claude Code) or `AGENTS.md` (other AIs) for the boot sequence.
- **Picking a project** — check `ROSTER.md` for status, then `cd` into the chosen repo.
- **Cross-repo work** — operate from this folder; log findings in `.repo-manager/drift_log.chloeai`.
- **Bootstrapping a new project** — clone `templateRepo_EXAMPLE`, run `init-project.sh`, then update `ROSTER.md`.
