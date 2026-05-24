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
echo "  12) gbdk          Game Boy Development Kit (GBDK-2020)"
echo "  13) generic        No stack (fill everything in manually)"
echo

read -r -p "Enter number [13]: " STACK_CHOICE
STACK_CHOICE="${STACK_CHOICE:-13}"

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
  12) STACK="gbdk"           ; STACK_DISPLAY="Game Boy Development Kit (GBDK-2020)" ;;
  13) STACK="generic"        ; STACK_DISPLAY="Generic (no stack)" ;;
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
cp "${STACK_DIR}/code.ai"  "${RULES_DIR}/code.ai"
cp "${STACK_DIR}/tests.ai" "${RULES_DIR}/tests.ai"

# ── Append stack metadata into technical_reference.md ────────────────────────
STACK_META="${STACK_DIR}/stack.ai"
TECH_REF="ai_context/technical_reference.md"

if [[ -f "$STACK_META" && -f "$TECH_REF" ]]; then
  echo "Wiring stack metadata into ${TECH_REF}..."
  {
    echo ""
    echo "---"
    echo ""
    echo "## Stack Starter Pack — ${STACK_DISPLAY}"
    echo ""
    echo "Seeded from \`stacks/${STACK}/stack.ai\` at bootstrap (${TODAY})."
    echo ""
    # Extract DESCRIPTION and RECOMMENDED_TOOLS sections from stack.ai.
    # Format is plain blocks delimited by all-caps headers ending in colon.
    awk '
      /^DESCRIPTION:/ { in_block=1; print "### Description"; print ""; next }
      /^RECOMMENDED_TOOLS:/ { in_block=1; print ""; print "### Recommended Tools"; print ""; next }
      /^INIT_NOTES:/ { in_block=0; next }
      /^[A-Z_]+:/ { in_block=0; next }
      in_block && /^$/ { print ""; next }
      in_block { print }
    ' "$STACK_META"
    echo ""
  } >> "$TECH_REF"
fi

# ── Substitute placeholders ───────────────────────────────────────────────────
FILES=()
while IFS= read -r -d '' f; do
  FILES+=("$f")
done < <(
  find . \
    -type f \
    \( -name "*.md" -o -name "*.ai" -o -name "*.heywy" -o -name "*.sh" \) \
    ! -name "init-project.sh" \
    ! -path "./.git/*" \
    ! -path "./stacks/*" \
    ! -path "./workspace/*" \
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
ADR_FILE="ai_context/decisions/001-stack-choice.ai"

cat > "$ADR_FILE" <<ADEOF
#AI:1
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
- .claude/rules/code.ai and tests.ai are pre-seeded for ${STACK_DISPLAY}.
- Fill in version pins, build commands, and project-specific rules before first AI session.
- stacks/ directory can be deleted once rules are finalized.
ADEOF

echo "Seeded ${ADR_FILE}"

# ── Update ADR index ──────────────────────────────────────────────────────────
README_CHLOEAI="ai_context/decisions/README.ai"
if [[ -f "$README_CHLOEAI" ]]; then
  # Append stack ADR row to the index table if not already present
  if ! grep -q "001-stack-choice" "$README_CHLOEAI"; then
    "${SED_INPLACE[@]}" \
      "s|## Index|## Index\n\n| ADR | Title | Status |\n|-----|-------|--------|\n| [001](001-stack-choice.ai) | Stack Choice — ${STACK_DISPLAY} | Accepted |" \
      "$README_CHLOEAI" 2>/dev/null || true
  fi
fi

# ── Scan for leftover tokens ──────────────────────────────────────────────────
# Exclude .claude/skills/ — those files may legitimately document the
# placeholder convention in their content. Same exclusion set as validate.sh.
echo
echo "Scanning for unfilled placeholder tokens..."
LEFTOVER="$(grep -rE '\{\{[A-Z_]+\}\}' . \
  --exclude-dir=.git \
  --exclude-dir=stacks \
  --exclude-dir=.claude \
  --exclude-dir=workspace \
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
echo "  Rules:    .claude/rules/code.ai + tests.ai"
echo "  ADR-001:  ${ADR_FILE}"
echo
echo "Next steps:"
echo "  1. Fill in version pins and build commands in .claude/rules/code.ai"
echo "  2. Fill in ai_context/project_brief.md and ai_context/CURRENT_MISSION.md"
echo "  3. Confirm ai_modules/hi_mode.ai EXTENDS path resolves (defaults to ~/.claude/skills/hi-mode/SKILL.md)"
echo "  4. Run: bash .claude/skills/validate-substrate/validate.sh  (should pass with 0 failures)"
echo "  5. git init && git add . && git commit -m 'bootstrap: ${PROJECT_NAME} from templateRepo_EXAMPLE'"
echo "  (pre-commit guards: lefthook was activated above if installed, otherwise run 'brew install lefthook && lefthook install')"
echo

# ── Activate lefthook pre-commit guards ──────────────────────────────────────
if command -v lefthook > /dev/null 2>&1; then
  if [ -d .git ]; then
    echo "Activating pre-commit guards (lefthook install)..."
    lefthook install && echo "Hooks registered." || echo "lefthook install failed — run it manually."
  else
    echo "ℹ  lefthook installed but no .git dir yet. Run 'lefthook install' after 'git init'."
  fi
else
  echo "ℹ  lefthook not installed. Run 'brew install lefthook && lefthook install' to activate pre-commit guards."
fi
echo

# ── Stacks/ deletion prompt ───────────────────────────────────────────────────
if [[ -d stacks ]]; then
  read -r -p "Delete stacks/ now? Other starter packs will no longer be available. [y/N]: " STACKS_ANSWER
  if [[ "$STACKS_ANSWER" =~ ^[yY]([eE][sS])?$ ]]; then
    rm -rf stacks
    echo "Deleted stacks/."
  else
    echo "Keeping stacks/. Delete it manually when ready."
  fi
  echo
fi

# ── Self-delete ───────────────────────────────────────────────────────────────
read -r -p "Delete init-project.sh now? [y/N]: " ANSWER
if [[ "$ANSWER" =~ ^[yY]([eE][sS])?$ ]]; then
  rm -- "$0"
  echo "Self-deleted."
else
  echo "Keeping init-project.sh. Delete it manually when ready."
fi
