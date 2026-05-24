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

Two fields need replacing before deploy:

| Placeholder | Replace with |
|-------------|-------------|
| `WORKSPACE_OWNER` | Your name or org (e.g., `WylieH2S`) |
| `GITHUB_USERNAME` | Your GitHub handle (e.g., `wylieh2s`) |

Find-and-replace across all files in this directory:

```bash
# macOS/BSD
grep -rl "WORKSPACE_OWNER\|GITHUB_USERNAME" workspace/ | \
  xargs sed -i '' 's/WORKSPACE_OWNER/YourName/g; s/GITHUB_USERNAME/yourhandle/g'

# Linux/GNU
grep -rl "WORKSPACE_OWNER\|GITHUB_USERNAME" workspace/ | \
  xargs sed -i 's/WORKSPACE_OWNER/YourName/g; s/GITHUB_USERNAME/yourhandle/g'
```

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
cp workspace/.repo-manager/drift_log.chloeai "$WORKSPACE/.repo-manager/"
```

**2. Set up workspace canonical skills:**
```bash
mkdir -p "$WORKSPACE/.claude/skills"
cp -r .claude/skills/drift-sweep "$WORKSPACE/.claude/skills/"
cp -r .claude/skills/validate-substrate "$WORKSPACE/.claude/skills/"
```

**3. (Optional) Set up your operating charter:**

`.claude/skills/hi-mode/` is where your **operating charter** lives — a persistent cross-session kernel that tracks zoom level, recommended model/effort, task queue, and context across AI sessions. It is not bundled in the template; you write your own.

```bash
mkdir -p "$WORKSPACE/.claude/skills/hi-mode"
# Create SKILL.md here — your operating charter.
# Define: who you are, your values, a boot sequence, and a HANDOFF LOG section.
# The boot sequences in CLAUDE.md and AGENTS.md will gracefully skip if absent.
```

To make it available as a Claude Code slash command:
```bash
ln -s "$WORKSPACE/.claude/skills/hi-mode" ~/.claude/skills/hi-mode
```

**Skip this step if you're getting started** — the workspace and per-repo tools work without it.

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
| `.repo-manager/drift_log.chloeai` | Fleet drift findings journal (starts empty) |
