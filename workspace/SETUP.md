# Workspace Root Setup Guide

This directory contains the scaffold for your **workspace root** — the parent folder that
holds all your project repos.

> **These files are not part of the per-project template.** They are for setting up the
> *parent directory* that contains all your projects (e.g., `~/Documents/Projects/GitHub/`).
> `init-project.sh` deliberately skips this directory.

---

## What problem does this solve?

When you have multiple project repos in one parent directory, the parent directory itself
becomes useful substrate: a ROSTER of what's alive vs. dormant, a cross-repo inbox, shared
AI tooling (drift-sweep, validate-substrate), and a continuity journal for an AI repo manager
operating across all your repos.

This `workspace/` scaffold is that setup, ready to deploy.

---

## Personalization

Replace these before deploy:

| Placeholder | Files | Replace with |
|-------------|-------|-------------|
| `WORKSPACE_OWNER` | All workspace/ files | Your name or org (e.g., `WylieH2S`) |
| `GITHUB_USERNAME` | `ROSTER.md` | Your GitHub handle (e.g., `wylieh2s`) |
| `AI_NAME` | `.claude/skills/hi-mode/SKILL.md` | Your AI assistant's name or persona (e.g., `Claude`) |
| `UNLOCK_PHRASE` | `.claude/skills/hi-mode/SKILL.md` | A phrase the AI echoes to confirm it has read the rules |
| `OWNER_NAME` | `.claude/skills/hi-mode/SKILL.md` | Your name or handle |

Bulk find-and-replace for WORKSPACE_OWNER and GITHUB_USERNAME:

```bash
# macOS/BSD
grep -rl "WORKSPACE_OWNER\|GITHUB_USERNAME" workspace/ | \
  xargs sed -i '' 's/WORKSPACE_OWNER/YourName/g; s/GITHUB_USERNAME/yourhandle/g'

# Linux/GNU
grep -rl "WORKSPACE_OWNER\|GITHUB_USERNAME" workspace/ | \
  xargs sed -i 's/WORKSPACE_OWNER/YourName/g; s/GITHUB_USERNAME/yourhandle/g'
```

Edit `workspace/.claude/skills/hi-mode/SKILL.md` by hand for `AI_NAME`, `OWNER_NAME`, and `UNLOCK_PHRASE` — these are personal choices.

---

## Deploy steps

Assuming your workspace root is `~/Documents/Projects/GitHub/`:

**1. Copy workspace root files:**
```bash
WORKSPACE=~/Documents/Projects/GitHub

cp workspace/AGENTS.md "$WORKSPACE/"
cp workspace/CLAUDE.md "$WORKSPACE/"
cp workspace/README.md "$WORKSPACE/"
cp workspace/ROSTER.md "$WORKSPACE/"
mkdir -p "$WORKSPACE/.repo-manager"
cp workspace/.repo-manager/README.md "$WORKSPACE/.repo-manager/"
cp workspace/.repo-manager/inbox.md "$WORKSPACE/.repo-manager/"
cp workspace/.repo-manager/drift_log.ai "$WORKSPACE/.repo-manager/"
```

**2. Set up workspace canonical skills:**
```bash
mkdir -p "$WORKSPACE/.claude/skills"
cp -r .claude/skills/drift-sweep "$WORKSPACE/.claude/skills/"
cp -r .claude/skills/validate-substrate "$WORKSPACE/.claude/skills/"
cp -r workspace/.claude/skills/hi-mode "$WORKSPACE/.claude/skills/"
cp -r workspace/.claude/skills/fleet-status "$WORKSPACE/.claude/skills/"
```

**3. Customize your operating charter:**

A starter charter is pre-seeded at `.claude/skills/hi-mode/SKILL.md`. Open it and replace the placeholders:
- `AI_NAME` — your AI assistant's name (e.g., `Claude`, `Copilot`)
- `OWNER_NAME` — your name or handle
- `UNLOCK_PHRASE` — a phrase the AI echoes to confirm it has read the rules
- Delete the `CHANGEME` section when done

To make the charter and fleet-status available as Claude Code slash commands:
```bash
ln -s "$WORKSPACE/.claude/skills/hi-mode" ~/.claude/skills/hi-mode
ln -s "$WORKSPACE/.claude/skills/fleet-status" ~/.claude/skills/fleet-status
```

**Skip the slash command link if you don't use Claude Code** — the workspace CLAUDE.md and AGENTS.md boot sequences work with any AI that can read files.

**4. For each project repo, symlink the workspace canonical skills:**
```bash
mkdir -p <repo>/.claude/skills
ln -s "$WORKSPACE/.claude/skills/drift-sweep" <repo>/.claude/skills/drift-sweep
ln -s "$WORKSPACE/.claude/skills/validate-substrate" <repo>/.claude/skills/validate-substrate
```

**5. Edit ROSTER.md** to add your repos with their status and stack.

**6. Verify:**
```bash
cd "$WORKSPACE"
bash .claude/skills/validate-substrate/validate.sh
bash .claude/skills/drift-sweep/sweep.sh --quiet
```

---

## What's in workspace/

| File | Deployed to workspace root |
|------|---------------------------|
| `AGENTS.md` | Universal AI entry point (any AI agent reads this) |
| `CLAUDE.md` | Claude Code-native boot sequence |
| `README.md` | Human-facing workspace overview |
| `ROSTER.md` | Repo lifecycle dashboard |
| `.repo-manager/README.md` | Workspace conventions |
| `.repo-manager/inbox.md` | Between-session quick capture |
| `.repo-manager/drift_log.ai` | Fleet drift findings journal (starts empty) |
| `.claude/skills/hi-mode/SKILL.md` | Starter operating charter (customize with your AI name + unlock phrase) |
| `.claude/skills/hi-mode/ski_lift_log.ai` | Tooling adoption candidates log (starts empty) |
| `.claude/skills/fleet-status/fleet-status.sh` | Fleet status script — surfaces latest HANDOFF from every repo |
| `.claude/skills/fleet-status/SKILL.md` | `/fleet-status` slash command definition |
