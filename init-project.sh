#!/usr/bin/env bash
set -euo pipefail

# init-project.sh -- one-shot bootstrap for a project cloned from templateRepo_EXAMPLE.
# Prompts for project metadata and stack, copies chosen stack rules into .claude/rules/,
# sweeps placeholder tokens, seeds ADR-001 for the stack choice, then self-deletes.

cd "$(dirname "$0")"

# ── Portable in-place sed (Darwin/BSD vs GNU) ─────────────────────────────────
if [[ "$(uname)" == "Darwin" ]]; then
  SED_INPLACE=(sed -i '')
else
  SED_INPLACE=(sed -i)
fi

# ── Project metadata ──────────────────────────────────────────────────────────
echo
echo "=== templateRepo_EXAMPLE — Project Bootstrap ==="
echo

read -r -p "Project name (no spaces, e.g. MyProject): " PROJECT_NAME
read -r -p "Project blurb (one sentence): " PROJECT_BLURB
read -r -p "Owner name (e.g. Wy): " OWNER_NAME
read -r -p "Repo URL or path (e.g. github.com/user/repo): " REPO_PATH
read -r -p "Unlock phrase [Rangers lead the way!]: " UNLOCK_PHRASE
UNLOCK_PHRASE="${UNLOCK_PHRASE:-Rangers lead the way!}"
TODAY="$(date +%F)"

if [[ -z "$PROJECT_NAME" || -z "$PROJECT_BLURB" || -z "$OWNER_NAME" ]]; then
  echo "ERROR: project name, blurb, and owner name are required." >&2
  exit 1
fi

# ── Stack selection ───────────────────────────────────────────────────────────
echo
echo "Select a stack starter pack:"
echo "  1)  ts-node        TypeScript / Node.js"
echo "  2)  python         Python"
echo "  3)  swift-ios      Swift / iOS"
echo "  4)  go             Go"
echo "  5)  rust           Rust"
echo "  6)  java-spring    Java / Spring Boot"
echo "  7)  kotlin         Kotlin / JVM"
echo "  8)  ruby-rails     Ruby / Rails"
echo "  9)  elixir-phoenix Elixir / Phoenix"
echo "  10) dotnet         .NET / C#"
echo "  11) php-laravel    PHP / Laravel"
echo "  12) generic        No stack (fill everything in manually)"
echo

read -r -p "Enter number [12]: " STACK_CHOICE
STACK_CHOICE="${STACK_CHOICE:-12}"

case "$STACK_CHOICE" in
  1)  STACK="ts-node"        ; STACK_DISPLAY="TypeScript / Node.js" ;;
  2)  STACK="python"         ; STACK_DISPLAY="Python" ;;
  3)  STACK="swift-ios"      ; STACK_DISPLAY="Swift / iOS" ;;
  4)  STACK="go"             ; STACK_DISPLAY="Go" ;;
  5)  STACK="rust"           ; STACK_DISPLAY="Rust" ;;
  6)  STACK="java-spring"    ; STACK_DISPLAY="Java / Spring Boot" ;;
  7)  STACK="kotlin"         ; STACK_DISPLAY="Kotlin / JVM" ;;
  8)  STACK="ruby-rails"     ; STACK_DISPLAY="Ruby / Rails" ;;
  9)  STACK="elixir-phoenix" ; STACK_DISPLAY="Elixir / Phoenix" ;;
  10) STACK="dotnet"         ; STACK_DISPLAY=".NET / C#" ;;
  11) STACK="php-laravel"    ; STACK_DISPLAY="PHP / Laravel" ;;
  12) STACK="generic"        ; STACK_DISPLAY="Generic (no stack)" ;;
  *)
    echo "Invalid selection. Defaulting to generic."
    STACK="generic"
    STACK_DISPLAY="Generic (no stack)"
    ;;
esac

echo
echo "Stack: ${STACK_DISPLAY}"

# ── Copy stack rules into .claude/rules/ ─────────────────────────────────────
STACK_DIR="stacks/${STACK}"
RULES_DIR=".claude/rules"

if [[ ! -d "$STACK_DIR" ]]; then
  echo "ERROR: stack directory '${STACK_DIR}' not found." >&2
  exit 1
fi

mkdir -p "$RULES_DIR"

echo "Copying stack rules → ${RULES_DIR}/"
cp "${STACK_DIR}/code.chloeai"  "${RULES_DIR}/code.chloeai"
cp "${STACK_DIR}/tests.chloeai" "${RULES_DIR}/tests.chloeai"

# ── Substitute placeholders ───────────────────────────────────────────────────
FILES=()
while IFS= read -r -d '' f; do
  FILES+=("$f")
done < <(
  find . \
    -type f \
    \( -name "*.md" -o -name "*.chloeai" -o -name "*.heywy" -o -name "*.sh" \) \
    ! -name "init-project.sh" \
    ! -path "./.git/*" \
    ! -path "./stacks/*" \
    -print0
)

echo "Substituting placeholders across ${#FILES[@]} files..."

for f in "${FILES[@]}"; do
  "${SED_INPLACE[@]}" \
    -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
    -e "s|{{PROJECT_BLURB}}|${PROJECT_BLURB}|g" \
    -e "s|{{OWNER_NAME}}|${OWNER_NAME}|g" \
    -e "s|{{REPO_PATH_OR_URL}}|${REPO_PATH}|g" \
    -e "s|{{PROJECT_GOAL_STATEMENT}}|${PROJECT_BLURB}|g" \
    -e "s|{{UNLOCK_PHRASE}}|${UNLOCK_PHRASE}|g" \
    -e "s|{{TODAY}}|${TODAY}|g" \
    "$f"
done

# ── Seed ADR-001 for stack choice ─────────────────────────────────────────────
ADR_FILE="ai_context/decisions/001-stack-choice.chloeai"

cat > "$ADR_FILE" <<ADEOF
#CHLOEAI:1
# ADR-001: Stack Choice — ${STACK_DISPLAY}
**Status:** Accepted
**Date:** ${TODAY}
**Signed:** ${OWNER_NAME}

## Context
Project bootstrapped from templateRepo_EXAMPLE. A stack starter pack
was selected at init time to pre-seed .claude/rules/ with language-specific
conventions.

## Decision
Use **${STACK_DISPLAY}** (stacks/${STACK}/).

## Alternatives Considered
| Option | Why Rejected |
|--------|-------------|
| Other stacks | Not applicable to this project's requirements |
| generic | Would require filling in all rules from scratch |

## Consequences
- .claude/rules/code.chloeai and tests.chloeai are pre-seeded for ${STACK_DISPLAY}.
- Fill in version pins, build commands, and project-specific rules before first AI session.
- stacks/ directory can be deleted once rules are finalized.
ADEOF

echo "Seeded ${ADR_FILE}"

# ── Update ADR index ──────────────────────────────────────────────────────────
README_CHLOEAI="ai_context/decisions/README.chloeai"
if [[ -f "$README_CHLOEAI" ]]; then
  # Append stack ADR row to the index table if not already present
  if ! grep -q "001-stack-choice" "$README_CHLOEAI"; then
    "${SED_INPLACE[@]}" \
      "s|## Index|## Index\n\n| ADR | Title | Status |\n|-----|-------|--------|\n| [001](001-stack-choice.chloeai) | Stack Choice — ${STACK_DISPLAY} | Accepted |" \
      "$README_CHLOEAI" 2>/dev/null || true
  fi
fi

# ── Scan for leftover tokens ──────────────────────────────────────────────────
echo
echo "Scanning for unfilled placeholder tokens..."
LEFTOVER="$(grep -rE '\{\{[A-Z_]+\}\}' . \
  --exclude-dir=.git \
  --exclude-dir=stacks \
  --exclude="init-project.sh" \
  2>/dev/null || true)"

if [[ -n "$LEFTOVER" ]]; then
  echo
  echo "WARNING: unfilled placeholder tokens remain. Review and edit by hand:"
  echo "$LEFTOVER"
  echo
else
  echo "No unfilled tokens. Bootstrap clean."
  echo
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo "=== Bootstrap complete ==="
echo "  Project:  ${PROJECT_NAME}"
echo "  Owner:    ${OWNER_NAME}"
echo "  Stack:    ${STACK_DISPLAY}"
echo "  Rules:    .claude/rules/code.chloeai + tests.chloeai"
echo "  ADR-001:  ${ADR_FILE}"
echo
echo "Next steps:"
echo "  1. Fill in version pins and build commands in .claude/rules/code.chloeai"
echo "  2. Fill in ai_context/project_brief.md and ai_context/CURRENT_MISSION.md"
echo "  3. Set your unlock phrase in readme_AI.chloeai (already substituted if you entered one)"
echo "  4. Run: git init && git add . && git commit -m 'bootstrap: ${PROJECT_NAME} from templateRepo_EXAMPLE'"
echo "  5. Delete stacks/ when you no longer need the other starter packs"
echo

# ── Self-delete ───────────────────────────────────────────────────────────────
read -r -p "Delete init-project.sh now? [y/N]: " ANSWER
if [[ "$ANSWER" =~ ^[yY]([eE][sS])?$ ]]; then
  rm -- "$0"
  echo "Self-deleted."
else
  echo "Keeping init-project.sh. Delete it manually when ready."
fi
