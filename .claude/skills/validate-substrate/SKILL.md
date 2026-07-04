---
name: validate-substrate
description: Validate that a repo's AI substrate is consistent with the templateRepo_EXAMPLE conventions, including Agent Boot Contract (ADR-BOOT-001) conformance. Runs structural checks on required files, expected directory layout, boot-contract edges, and substrate freshness. Use when onboarding a new repo, after a substrate migration, or to audit repos for drift.
---

# /validate-substrate

Validates a repo against the two-tier load model conventions defined in templateRepo_EXAMPLE.

## What it checks

### Template mode detection
The script detects "template mode" by the presence of `init-project.sh`. In template mode, three accommodations apply because they describe state that only becomes valid post-bootstrap: leftover `{{TOKEN}}` placeholders are skipped entirely, an unresolved `EXTENDS` path downgrades from FAIL to WARN, and substrate filenames match either way because the script's own filename references are the same per-duo placeholder tokens (ADR-009) that `init-project.sh` expands — in template mode the files on disk literally carry the token names, and post-init both the files and this script are substituted in the same pass. That is what lets the template itself validate 0-fails and serve as the boot-contract conformance oracle.

### Tier 1 (always-loaded) files — must exist:
- `CLAUDE.md` — path-routing table
- `STARTUP_AI.{{AI}}ai` — boot file (READ_ORDER source of truth)
- `readme_AI.{{AI}}ai` — active threads + latest handoff
- `ai_context/ai_rules.{{AI}}ai` — hard constraints
- `ai_context/glossary.{{AI}}ai` — terminology
- `ai_context/START_HERE.md` — file map and conventions

### ai_modules/ — must exist:
- `ai_modules/` directory
- `ai_modules/hi_mode.{{AI}}ai` — HI Mode shim

### EXTENDS path resolution:
- Reads `EXTENDS=` line from `ai_modules/hi_mode.{{AI}}ai`
- Expands `~` to `$HOME` and confirms the target file exists
- FAIL in normal mode, WARN in template mode

### Path-scoped rules — must exist if referenced from CLAUDE.md:
- `.claude/rules/code.{{AI}}ai`
- `.claude/rules/tests.{{AI}}ai`
- `.claude/rules/ai-context.{{AI}}ai`
- `.claude/rules/docs.{{AI}}ai`

### Agent Boot Contract conformance (ADR-BOOT-001):
Per `.repo-manager/standards/boot-contract/BOOT-CONTRACT.{{AI}}ai`. R1 (the `STARTUP_AI.<ext>` capsule exists at the repo root → FAIL) is enforced by the Tier 1 loop above; this section adds:
- **R2** — `CLAUDE.md` and `AGENTS.md` both exist and reference `STARTUP_AI` as the bootstrap → FAIL if either doesn't
- **R3** — `ai_context/START_HERE.md` presents no competing "Boot Sequence"; a Boot Sequence heading is allowed only when the file carries the "not a competing boot sequence" deferral to STARTUP_AI → WARN
- **W1** — `lefthook.yml` exists and carries the drift-sweep `wrap-continuity` arm (the git-native WRITE-edge floor — fires for any committing agent, Claude or Codex) → FAIL if not
- **W3** — `.claude/settings.json` carries the SessionStart gate pair (`handoff-gate.sh` + `wrap-gate.sh`) — the optional Claude UX layer on top of W1 → WARN if absent

### Hygiene checks:
- `.gitignore` present
- `AI_HANDOFF.{{AI}}ai` present
- `WORKSHEET.hey{{HUMAN}}` present
- `SIDEQUESTS.{{AI}}ai` present

### Tracked junk:
- No tracked `.DS_Store` files
- No tracked `.env`, `.env.local`, `.env.production` files
- No tracked `*.local.json` files

### Leftover placeholder tokens:
- No `{{TOKEN}}` placeholders left unfilled (skipped in template mode)

### Freshness checks (90-day threshold):
- `ai_context/current_state.md` modified within 90 days
- `AI_HANDOFF.{{AI}}ai` modified within 90 days
- `readme_AI.{{AI}}ai` modified within 90 days

### Size sanity:
- `AI_HANDOFF.{{AI}}ai` ≤ 200 KB (warn above — rotate older entries to archive)
- `ai_context/current_state.md` ≤ 50 KB (warn above — rotate older deltas to readme_AI_archive.{{AI}}ai)

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
