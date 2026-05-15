---
name: validate-substrate
description: Validate that a repo's AI substrate is consistent with the templateRepo_EXAMPLE conventions. Runs structural checks on required files, expected directory layout, and substrate freshness. Use when onboarding a new repo, after a substrate migration, or to audit repos for drift.
---

# /validate-substrate

Validates a repo against the two-tier load model conventions defined in templateRepo_EXAMPLE.

## What it checks

### Tier 1 (always-loaded) files — must exist:
- `CLAUDE.md` — path-routing table, must contain Tier 1 and Path-Scoped sections
- `readme_AI.chloeai` — active threads + latest handoff
- `ai_context/ai_rules.chloeai` — hard constraints
- `ai_context/glossary.chloeai` — terminology
- `ai_context/START_HERE.md` — boot sequence

### Path-scoped rules — must exist if referenced from CLAUDE.md:
- `.claude/rules/code.chloeai`
- `.claude/rules/tests.chloeai`
- `.claude/rules/ai-context.chloeai`
- `.claude/rules/docs.chloeai`

### Hygiene checks:
- `.gitignore` present
- `AI_HANDOFF.chloeai` exists and is not empty
- No tracked `.DS_Store` files
- No tracked `.env` or `*.local.json` files
- `WORKSHEET.heywy` present
- `SIDEQUESTS.chloeai` present

### Freshness checks:
- `current_state.md` was updated in the last 90 days (else flag as stale)
- `AI_HANDOFF.chloeai` last entry within 90 days (else stale)
- If `current_state.md` is >50KB → suggest rotating older content to archive

## How to run

From the repo root:

```bash
bash $TEMPLATE_REPO_PATH/.claude/skills/validate-substrate/validate.sh
```

Or invoke via `/validate-substrate` slash command if the skill is registered.

## Output

- ✓ PASS lines for checks that succeed
- ⚠ WARN for issues that don't block (freshness, soft conventions)
- ✗ FAIL for hard issues (missing required files, tracked secrets)

Exit code: 0 if no failures, 1 if any FAIL.

## When to use

- After running `init-project.sh` on a new repo (sanity check the bootstrap)
- After a Phase B-style substrate migration (drift check)
- As part of a periodic audit across all repos
- Before committing a significant substrate change
