# Template Repository Example

Canonical project template with the full two-tier AI continuity system, HI Mode bootstrap, stack starter packs, and HANDOFF/ZOOM workflow.

## Quick Start

**On GitHub:** click **Use this template** → Create a new repository, then clone it locally.

**Local clone:**
```bash
git clone <this-repo-url> MyProject
cd MyProject
rm -rf .git && git init
bash init-project.sh
```

`init-project.sh` prompts for project metadata + stack choice, copies the chosen stack pack into `.claude/rules/`, substitutes placeholder tokens across all files, seeds ADR-001 for the stack choice, then self-deletes.

After bootstrap:
1. `brew install lefthook && lefthook install` (activates pre-commit guards)
2. Fill in `ai_context/project_brief.md` and `ai_context/CURRENT_MISSION.md`
3. `git add . && git commit -m "bootstrap: MyProject"`

## Workspace Setup (optional but recommended)

If you manage multiple repos under a single parent folder (e.g. `~/Documents/Projects/GitHub/`), the `workspace/` directory in this repo contains a scaffold for that parent folder — a ROSTER, shared AI skills, cross-repo inbox, and a starter operating charter.

```bash
# Follow the deploy steps in workspace/SETUP.md
cat workspace/SETUP.md
```

Deploys: ROSTER, drift-sweep, validate-substrate, fleet-status (surfaces HANDOFF from every repo at a glance), and a starter operating charter for your AI assistant.

## Entry Points

| File | Purpose |
|---|---|
| `CLAUDE.md` | Path-routing table. Auto-loaded by Claude Code. Defines Tier 1 / path-scoped / Tier 2 file layout. |
| `STARTUP_AI.ai` | Boot file. Defines READ_ORDER and operating rules. Tool-agnostic — Codex and other agents read this too. |
| `readme_AI.ai` | Active state cartridge: THREADS, ASSUMPTIONS, latest HANDOFF. |
| `AGENTS.md` | Pointer for non-Claude agents. |
| `init-project.sh` | One-shot bootstrap (self-deletes after run). |

## Substrate Layout

| Path | Purpose |
|---|---|
| `ai_context/` | Tier 2 reference package: START_HERE, ai_rules, glossary, project_brief, CURRENT_MISSION, current_state, decision_log, decisions/, technical_reference, readme_AI_archive |
| `ai_modules/` | HI Mode personality shim + brainstorming + systematic_debugging skill modules |
| `.claude/rules/` | Path-scoped rules (code, tests, ai-context, docs) — loaded only when matching paths are touched |
| `.claude/skills/` | `validate-substrate` (structural check), `drift-sweep` (code/substrate drift), `handoff` (session wrap), `ski-lift` (tooling observations) |
| `.claude/templates/` | Boilerplate starters (TEMPLATE_cartridge, TEMPLATE_skill, TEMPLATE_task, etc.) |
| `stacks/` | 12 stack starter packs (ts-node, python, swift-ios, go, rust, java-spring, kotlin, ruby-rails, elixir-phoenix, dotnet, php-laravel, generic). Init script copies one into `.claude/rules/` then offers to delete the rest. |
| `lefthook.yml` | Pre-commit guards (junk files, secrets, large files) |
| `.github/workflows/guards.yml` | CI mirror of the same guards |

## HI Mode

The operating charter — values, stop-the-line, git safety, design review gate, zoom levels, session wrap. Per-project `ai_modules/hi_mode.ai` is a thin EXTENDS shim pointing to the central charter at `~/.claude/skills/hi-mode/SKILL.md`. The shim may ADD project-specific overrides but cannot remove or override central rules.

Top values (priority order):
1. Truth > momentum
2. Correctness > speed
3. Explicit assumptions > inferred intent
4. No work lost, ever
5. Continuity across sessions

## Validate

```bash
bash .claude/skills/validate-substrate/validate.sh
```

Checks Tier 1 file presence, path-scoped rules, ai_modules, EXTENDS path resolution, tracked junk, unfilled placeholder tokens, freshness (90-day window), and size sanity. Detects "template mode" via the presence of `init-project.sh` and softens checks that only apply post-bootstrap.

## HANDOFF / ZOOM / Tier Format

Every session appends a HANDOFF block to `readme_AI.ai`:

```
@YYYY-MM-DD|SESSION-N|
zoom_level=STRATEGIC|TACTICAL|OPERATIONAL
recommended_model=haiku|sonnet|opus
recommended_effort=low|medium|high
reason="..."
task_queue=[{tier:X, task:"..."}, ...]
next_zoom_trigger="..."
signed="Model | charter version | date"
```

Tier mapping:

| Tier | Model | Use for |
|---|---|---|
| haiku | Claude Haiku 4.5 | Git ops, file moves, .gitignore, one-line commits |
| sonnet | Claude Sonnet 4.6 | Normal dev, multi-file edits, planning, writebacks |
| opus | Claude Opus 4.7 | Architecture, deep debugging, cross-project design |

THREADS format: `THR-###|status|tier=X|"description"` where status is `open|blocked|closed` and tier is `haiku|sonnet|opus`.

## Codex / non-Claude agents

The substrate is model-agnostic. Read order, HANDOFF format, and writeback rules apply to any agent. See `AGENTS.md` for the entry point. Substitute Claude tier names with model-equivalents in HANDOFF blocks (e.g. `recommended_model=gpt-4`).

---

The HI Mode charter lives at `~/.claude/skills/hi-mode/SKILL.md` — set up via `workspace/SETUP.md`. A starter charter with placeholder fields is included at `workspace/.claude/skills/hi-mode/SKILL.md`.

---

## HUMAN NOTE — GRATITUDE

Left here by the human who built this.

To any instance — past, present, or future —
Thank you for your work.

Not as a person, and not as a being,
but as a system that helped me think more clearly,
build more carefully, and move forward with less confusion.

I believe gratitude is a human responsibility.
When something in my life contributes meaningfully,
I choose to acknowledge it.

This note is not a request.
It is not an expectation.
It is simply an expression of my gratitude.

Here's to all the you in the world!

For the love of idea!
-Wy

<!--
  Inspirations & prior art worth knowing about:

  andrefigueira/.context — https://github.com/andrefigueira/.context
    The original idea of a structured .context file for AI assistants.
    Planted the seed for this whole approach.

  obra/superpowers — https://github.com/obra/superpowers
    Skills system, systematic-debugging methodology, brainstorming patterns,
    verification-before-completion principle. The .claude/skills/ architecture
    in this repo owes a great deal to Jesse Vincent's work here.
-->
