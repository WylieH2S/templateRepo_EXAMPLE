# Fleet Status

Surface the latest HANDOFF block from every repo's `readme_AI` cartridge in a single view.

## Usage

```
/fleet-status
```

Or run directly:
```bash
bash ~/.claude/skills/fleet-status/fleet-status.sh
```

## What it does

Walks every git repo in the workspace root, finds the latest `@DATE|SESSION|` HANDOFF block in `readme_AI.ai`, and prints:

- Zoom level, recommended model/effort
- Reason (truncated to 100 chars)
- Up to 3 queued tasks with tier label
- Signed model

## Flags

| Flag | Effect |
|------|--------|
| `--quiet` / `-q` | One-line per repo (no reason, no tasks) — good for quick triage |
| `--repo=<name>` | Single repo only |

## Output example

```
[MyProject]  2026-05-24 | SESSION-001
  zoom=TACTICAL  model=sonnet  effort=medium
  reason: Wy live-tested the care feedback build...
  • [sonnet] Choose the next core-mechanics slice from main
  • [sonnet] Decide whether to push main and/or create a follow-up tag
  signed: Codex GPT-5 | Charter-HI-Mode-Repo-2026-04d | 2026-05-21
```

## When to use

At STRATEGIC zoom boot — run before reading individual repo substrates. Catches updates from Codex or other AI agents without opening each repo manually.

## Setup

Symlink into your user-level skills for slash command access:
```bash
ln -s ~/Documents/Projects/GitHub/.claude/skills/fleet-status ~/.claude/skills/fleet-status
```
