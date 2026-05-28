# Repo Manager Workspace

This directory is the operating workspace for the AI repo manager. It is **meta** to the repos themselves — local-only, not committed to any repo.

## Purpose

The AI repo manager handles cross-cutting work that affects multiple repos:

- Substrate consistency audits
- Cross-repo migrations and tooling rollouts
- Repo cleanup (history rewrites, branch pruning, .gitignore hygiene)
- Lifecycle status tracking (see `../ROSTER.md`)

This workspace persists across sessions so the next session can pick up cleanly.

---

## Layout

```
.repo-manager/
├── README.md               This file
├── audits/                 Legacy logs of cross-repo operations (one file per audit)
├── playbooks/              Reusable runbooks for common cross-repo tasks
├── drift_log.{{AI}}ai       Fleet drift findings journal (append-only; preferred over audits/)
└── inbox.md                Quick-capture notes between sessions
```

---

## Conventions

### Drift Log (`drift_log.{{AI}}ai`)

Append-only journal of code/substrate drift findings and OPEN DUE-OUTS across the fleet. Add entries after any cross-repo sweep, cleanup, or tooling rollout. This is the preferred home for new findings — `audits/` is legacy.

### Playbooks (`playbooks/<slug>.md`)

A playbook is a written-down version of a repeatable cross-repo task. Write one the second time you do something, not the first. Examples:
- "Adding a new repo to substrate compliance"
- "Rotating a bloated AI_HANDOFF.{{AI}}ai into an archive"
- "Cleaning git history of a repo that tracked large files"

### Inbox (`inbox.md`)

Single-file scratch for thoughts that don't fit elsewhere. Periodically clean — promote to `drift_log.{{AI}}ai`, playbooks, or ROSTER as appropriate.
