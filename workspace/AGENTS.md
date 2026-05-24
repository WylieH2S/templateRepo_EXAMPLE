# AGENTS.md — Workspace Root

This is the **parent workspace** for all WORKSPACE_OWNER projects. This folder is not a project itself — each subdirectory is a self-contained git repo.

> Claude Code users: `CLAUDE.md` is also present and carries the same boot sequence in Claude Code-native format.

## Boot sequence (read in order)

1. **Operating charter:** `.claude/skills/hi-mode/SKILL.md` — read the latest `@date|SESSION-N|` HANDOFF block at the bottom. That is the current zoom level, recommended model/effort, task queue, and context.
2. **Repo roster:** `ROSTER.md` — lifecycle status of every repo (ACTIVE / DORMANT / BLOCKED / NEW / HELD / TEMPLATE / MAINTAINED).
3. **Inbox:** `.repo-manager/inbox.md` — between-session notes from prior sessions.
4. **Drift findings:** `.repo-manager/drift_log.chloeai` — fleet drift state and OPEN DUE-OUTS ledger. Read when investigating drift or after a sweep.
5. **Tooling intelligence:** `.claude/skills/hi-mode/ski_lift_log.chloeai` — read at STRATEGIC zoom; skip at OPERATIONAL.

## When working on a specific repo

Enter that subdirectory and follow its own `AGENTS.md`. Each repo has its own substrate, threads, and continuity. Do not carry assumptions across repos without re-reading state.

## Non-negotiables

- This folder is not a git repo. Do not `git init` here.
- Per-repo work happens inside that repo's directory, not here.
- Cross-repo drift findings go in `.repo-manager/drift_log.chloeai` (append-only journal).

## Layout

```
GitHub/
├── AGENTS.md                          (this file — universal AI entry point)
├── CLAUDE.md                          (same boot sequence, Claude Code-native format)
├── ROSTER.md                          (repo lifecycle dashboard)
├── .claude/skills/
│   ├── hi-mode/SKILL.md               (operating charter + HANDOFF LOG)
│   ├── validate-substrate/            (structural compliance check skill)
│   └── drift-sweep/                   (code/substrate consistency check skill)
├── .repo-manager/
│   ├── drift_log.chloeai              (fleet drift findings journal)
│   ├── inbox.md                       (between-session quick capture)
│   └── playbooks/                     (reusable runbooks for cross-repo tasks)
└── [project subdirectories]           (each a self-contained git repo)
```
