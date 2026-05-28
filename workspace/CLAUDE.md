# GitHub Workspace — Parent Folder

You are at the **parent** of all WORKSPACE_OWNER projects. This folder is the operating workspace for the AI repo manager, not a project itself.

> For non-Claude AI agents: `AGENTS.md` is present and carries the same boot sequence in AI-neutral format.

## What's here

Each subdirectory is its own git repo with its own substrate. This parent holds **cross-cutting** state that spans repos.

## Boot sequence for AI (read in order)

1. **Operating charter (if present):** `.claude/skills/hi-mode/SKILL.md` — read the latest `SESSION-N` HANDOFF block at the bottom for current zoom, model, task queue, and context. See `SETUP.md` step 3 for setup.
2. **ROSTER:** `ROSTER.md` — lifecycle status of every repo (ACTIVE / DORMANT / BLOCKED / NEW / HELD / TEMPLATE / MAINTAINED).
3. **Most recent audit:** `.repo-manager/audits/` (latest by date) — historical markdown audits. Going forward, fleet drift findings live in `drift_log.{{AI}}ai` (see step 5).
4. **Inbox:** `.repo-manager/inbox.md` — between-session notes from prior sessions.
5. **Drift findings journal:** `.repo-manager/drift_log.{{AI}}ai` — fleet code/substrate drift state. Read when investigating drift or after a cross-repo sweep.
6. **Cross-cutting tooling intelligence (if present):** `.claude/skills/hi-mode/ski_lift_log.{{AI}}ai` — read at STRATEGIC zoom; skip at OPERATIONAL.

**Workspace skills** (callable from any repo subdirectory):
- `.claude/skills/validate-substrate/` — structural substrate compliance check
- `.claude/skills/drift-sweep/` — code/substrate consistency check
- `.claude/skills/fleet-status/` — surface latest HANDOFF from every repo (run at STRATEGIC boot; workspace-only, not symlinked into repos)
- Active repos symlink `.claude/skills/{validate-substrate,drift-sweep}` → these workspace canonical copies

## When work is scoped to one repo

`cd` into that subdirectory and follow its own `CLAUDE.md`. Each repo has its own substrate, its own threads, its own continuity.

## Layout

```
~/Documents/Projects/GitHub/
├── AGENTS.md                          (universal AI entry point — any agent reads this)
├── CLAUDE.md                          (this file — same boot sequence, Claude Code-native format)
├── README.md                          (human-facing entry)
├── ROSTER.md                          (repo lifecycle dashboard)
├── .claude/skills/
│   ├── hi-mode/
│   │   ├── SKILL.md                   (HI Mode charter + HANDOFF LOG)
│   │   └── ski_lift_log.{{AI}}ai            (cross-cutting tooling intelligence)
│   ├── validate-substrate/            (canonical — repos symlink here)
│   ├── drift-sweep/                   (canonical — repos symlink here)
│   └── fleet-status/                  (workspace-only — surfaces HANDOFF from all repos)
├── .repo-manager/
│   ├── README.md                      (workspace conventions)
│   ├── audits/                        (historical markdown logs — legacy)
│   ├── drift_log.{{AI}}ai              (fleet drift findings journal)
│   ├── playbooks/                     (reusable runbooks for cross-repo tasks)
│   └── inbox.md                       (between-session quick capture)
└── [project subdirectories]           (each a self-contained git repo)
```

## What does NOT live here

- Per-project context — that lives in each repo's own substrate.
- Code or implementation — this folder has no source code of its own.
- Decisions about project work — those live in each repo's `decision_log.md`.

## What MAY grow here later

- `ai_context/` — if cross-cutting decisions accumulate (e.g., decisions affecting *all* repos)
- `WORKSHEET.hey{{HUMAN}}` — if a cross-repo input channel is needed beyond the HI Mode HANDOFF LOG
- `readme_AI.{{AI}}ai` — if active cross-cutting threads need a dedicated cartridge

## Non-negotiables

- This is not a git repo. Do not `git init` here without explicit approval — subdirectory repos and a parent repo together create confusion (lockfile collisions, nested-status weirdness).
- Per-repo work happens **in** that repo's directory, not here.
- Cross-repo drift work gets logged in `.repo-manager/drift_log.{{AI}}ai` (append-only journal). The legacy `.repo-manager/audits/` markdown logs are historical — do not add new ones.
