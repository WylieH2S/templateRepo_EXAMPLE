---
name: validate-substrate
description: Validate that a repo's AI substrate is consistent with the templateRepo_EXAMPLE conventions, including Agent Boot Contract (ADR-BOOT-001) conformance. Runs structural checks on required files, expected directory layout, boot-contract edges, and substrate freshness. Use when onboarding a new repo, after a substrate migration, or to audit repos for drift.
---

# /validate-substrate

Validates a repo against the two-tier load model conventions defined in templateRepo_EXAMPLE.

## What it checks

### Template mode detection
The script detects "template mode" by **two** conditions: `init-project.sh` is present **and** the substrate is still placeholder-named (`*.{{AI}}ai` / `*.hey{{HUMAN}}`). One condition is not enough, and used to be: `init-project.sh`'s self-delete is a **prompt that defaults to NO**, so a real seeded repo whose owner pressed Enter kept the script and was silently validated in template mode — with the leftover-placeholder check skipped and the `EXTENDS` check softened, on the one repo where an unfilled placeholder is an actual defect, printing ✓ throughout. The second condition cannot survive seeding: init renames those files unconditionally, no prompt. In template mode, two accommodations apply because they describe state that only becomes valid post-bootstrap: leftover `{{TOKEN}}` placeholders are skipped entirely, and an unresolved `EXTENDS` path downgrades from FAIL to WARN.

**Carrier extensions are resolved, not hardcoded (2026-08-16).** There used to be a third accommodation: substrate filenames resolved through *both* variants (`NAME.chloeai` ⇄ `NAME.{{AI}}ai`), a dual-name lookup that existed solely so the placeholder-named template could validate. That is gone. The script now detects the AI and human carrier suffixes from the repo's own substrate — ordered anchors, root waystone card first, then Tier-1 files — so there is only ever **one** name, and the template and a seeded repo are the same code path rather than two.

This is what **retired the template's declared fork** of this skill. The fork existed because it had to be genericized to self-validate before and after init substitution, and, in the words of the note it carried, *"the canonical cannot do that."* The canonical can now: run in the template, its output is byte-identical to the fork it replaced, and `CANONICAL_FORK_SKILLS` there is empty. See drift-sweep v0.1.29 for the two live defects the old hardcoding had produced.

Resolution refuses loudly rather than defaulting. An unresolved suffix would make every substrate path end in a bare `.`, every file would read as missing, and the run would be a wall of FAILs describing nothing — so it exits 2 with a reason, the same way the container guard does. The anchor order is load-bearing: `init-project.sh` **deletes** both root waystone cards when it seeds a project, so anchoring on the card alone would have broken every newly-seeded repo. The Tier-1 anchors are files init renames rather than removes.

### Tier 1 (always-loaded) files — must exist:
- `CLAUDE.md` — path-routing table
- `STARTUP_AI.chloeai` — boot file (READ_ORDER source of truth)
- `readme_AI.chloeai` — active threads + latest handoff
- `ai_context/ai_rules.chloeai` — hard constraints
- `ai_context/glossary.chloeai` — terminology
- `ai_context/START_HERE.md` — file map and conventions

### ai_modules/ — must exist:
- `ai_modules/` directory
- `ai_modules/hi_mode.chloeai` — HI Mode shim

### EXTENDS path resolution:
- Reads `EXTENDS=` line from `ai_modules/hi_mode.chloeai`
- Expands `~` to `$HOME` and confirms the target file exists
- FAIL in normal mode, WARN in template mode

### Path-scoped rules — must exist if referenced from CLAUDE.md:
- `.claude/rules/code.chloeai`
- `.claude/rules/tests.chloeai`
- `.claude/rules/ai-context.chloeai`
- `.claude/rules/docs.chloeai`

### Agent Boot Contract conformance (ADR-BOOT-001):
Per `.repo-manager/standards/boot-contract/BOOT-CONTRACT.chloeai`. R1 (the `STARTUP_AI.<ext>` capsule exists at the repo root → FAIL) is enforced by the Tier 1 loop above; this section adds:
- **R2** — `CLAUDE.md` and `AGENTS.md` both exist and reference `STARTUP_AI` as the bootstrap → FAIL if either doesn't
- **R3** — `ai_context/START_HERE.md` presents no competing "Boot Sequence"; a Boot Sequence heading is allowed only when the file carries the "not a competing boot sequence" deferral to STARTUP_AI → WARN
- **W1** — `lefthook.yml` exists and carries the drift-sweep `wrap-continuity` arm (the git-native WRITE-edge floor — fires for any committing agent, Claude or Codex) → FAIL if not
- **W3** — `.claude/settings.json` carries the SessionStart gate pair (`handoff-gate.sh` + `wrap-gate.sh`) — the optional Claude UX layer on top of W1 → WARN if absent

### Hygiene checks:
- `.gitignore` present
- `AI_HANDOFF.chloeai` present
- `WORKSHEET.heywy` present
- `SIDEQUESTS.chloeai` present
- Repo-root `_waystone.chloeai` carries a `heywy:` inscription (WISL-STANDARD v1.5 /
  ADR-015) → **WARN only**. Absence is valid everywhere; the readout falls back to
  `orient` + `continuity`. Unknown `heywy:` sub-keys also WARN, since the renderer drops
  them silently and an author would otherwise never find out.

### Tracked junk:
- No tracked `.DS_Store` files
- No tracked `.env`, `.env.local`, `.env.production` files
- No tracked `*.local.json` files

### Leftover placeholder tokens:
- No `{{TOKEN}}` placeholders left unfilled **in files the template ships** (skipped entirely in template mode)
- **Mention vs use (2026-08-16).** Matching `{{TOKEN}}` anywhere cannot tell an unfilled slot from prose that *describes* the placeholder mechanism, and this fleet writes a lot of the latter — planTheBeast's `ai_context/upsync.chloeai` was the fleet's only validate-substrate failure for weeks purely because a hint entry explains what `{{AI}}` is. A gate whose one standing failure is known-bogus is a gate people learn to scroll past. The discriminator is the definition of the check rather than a guess about sentence shape: this asks *"did `init-project.sh` finish?"*, which is only answerable about files init ever touched — i.e. files the template ships. A file with no counterpart in `templateRepo_EXAMPLE` was authored by the project; init never saw it. Path mapping converts *this* repo's suffix to the template's (`foo.<ext>` → `foo.{{AI}}ai`); the `{{AI}}ai` side stays literal because it is a fact about the template, not about the repo being validated.
- **Degrades toward over-detection, never under.** No reachable template (repo cloned outside the fleet, single-repo CI checkout) → every hit stays a failure, exactly as before, with a line saying so. A missing oracle must not quietly switch a gate off.

### Freshness checks (90-day threshold):
- `ai_context/current_state.md` modified within 90 days
- `AI_HANDOFF.chloeai` modified within 90 days
- `readme_AI.chloeai` modified within 90 days

### Size sanity:
- `AI_HANDOFF.chloeai` ≤ 200 KB (warn above — rotate older entries to archive)
- `ai_context/current_state.md` ≤ 50 KB (warn above — rotate older deltas to readme_AI_archive.chloeai)

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
