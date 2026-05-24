---
name: validate-substrate
description: Validate that a repo's AI substrate is consistent with the templateRepo_EXAMPLE conventions. Runs structural checks on required files, expected directory layout, and substrate freshness. Use when onboarding a new repo, after a substrate migration, or to audit repos for drift.
---

# /validate-substrate

Validates a repo against the two-tier load model conventions defined in templateRepo_EXAMPLE.

## What it checks

### Template mode detection
The script detects "template mode" by the presence of `init-project.sh`. In template mode, two checks are softened because they describe state that only becomes valid post-bootstrap: leftover `{{TOKEN}}` placeholders are skipped entirely, and an unresolved `EXTENDS` path downgrades from FAIL to WARN.

### Tier 1 (always-loaded) files — must exist:
- `CLAUDE.md` — path-routing table
- `STARTUP_AI.ai` — boot file (READ_ORDER source of truth)
- `readme_AI.ai` — active threads + latest handoff
- `ai_context/ai_rules.ai` — hard constraints
- `ai_context/glossary.ai` — terminology
- `ai_context/START_HERE.md` — file map and conventions

### ai_modules/ — must exist:
- `ai_modules/` directory
- `ai_modules/hi_mode.ai` — HI Mode shim

### EXTENDS path resolution:
- Reads `EXTENDS=` line from `ai_modules/hi_mode.ai`
- Expands `~` to `$HOME` and confirms the target file exists
- FAIL in normal mode, WARN in template mode

### Path-scoped rules — must exist if referenced from CLAUDE.md:
- `.claude/rules/code.ai`
- `.claude/rules/tests.ai`
- `.claude/rules/ai-context.ai`
- `.claude/rules/docs.ai`

### Hygiene checks:
- `.gitignore` present
- `AI_HANDOFF.ai` present
- `WORKSHEET.human` present
- `SIDEQUESTS.ai` present

### Tracked junk:
- No tracked `.DS_Store` files
- No tracked `.env`, `.env.local`, `.env.production` files
- No tracked `*.local.json` files

### Leftover placeholder tokens:
- No `{{TOKEN}}` placeholders left unfilled (skipped in template mode)

### Freshness checks (90-day threshold):
- `ai_context/current_state.md` modified within 90 days
- `AI_HANDOFF.ai` modified within 90 days
- `readme_AI.ai` modified within 90 days

### Size sanity:
- `AI_HANDOFF.ai` ≤ 200 KB (warn above — rotate older entries to archive)
- `ai_context/current_state.md` ≤ 50 KB (warn above — rotate older deltas to readme_AI_archive.ai)

## How to invoke

When this skill is invoked via `/validate-substrate` (or directly): run the bundled validator script from the repo root.

```bash
bash .claude/skills/validate-substrate/validate.sh
```

You can also pass an explicit repo path:

```bash
bash .claude/skills/validate-substrate/validate.sh /path/to/other/repo
```

## Output

- ✓ PASS lines for checks that succeed
- ⚠ WARN for issues that don't block (freshness, soft conventions, template-mode softens)
- ✗ FAIL for hard issues (missing required files, tracked secrets, unresolved EXTENDS in non-template mode)

Exit code: 0 if no failures, 1 if any FAIL.

## When to invoke

- After running `init-project.sh` on a new repo (sanity check the bootstrap)
- After a substrate migration (drift check)
- Before committing a significant substrate change
- As part of a periodic cross-repo audit
