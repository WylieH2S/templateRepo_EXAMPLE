#!/usr/bin/env bash
set -euo pipefail

# init-project.sh -- one-shot bootstrap for a project cloned from baseline-template.
# Prompts for project metadata, sweeps placeholder tokens across all template files,
# warns about anything left unfilled, then offers to delete itself.

cd "$(dirname "$0")"

read -r -p "Project name (no spaces, e.g. MyProject): " PROJECT_NAME
read -r -p "Project blurb (one sentence): " PROJECT_BLURB
read -r -p "Owner name (e.g. Wy): " OWNER_NAME
read -r -p "Unlock phrase [Rangers lead the way!]: " UNLOCK_PHRASE
UNLOCK_PHRASE="${UNLOCK_PHRASE:-Rangers lead the way!}"

TODAY="$(date +%F)"

if [[ -z "$PROJECT_NAME" || -z "$PROJECT_BLURB" || -z "$OWNER_NAME" ]]; then
  echo "ERROR: project name, blurb, and owner name are required." >&2
  exit 1
fi

# Portable in-place sed (Darwin/BSD vs GNU)
if [[ "$(uname)" == "Darwin" ]]; then
  SED_INPLACE=(sed -i '')
else
  SED_INPLACE=(sed -i)
fi

# Find files that may contain placeholders. Exclude this script and .git.
FILES=()
while IFS= read -r -d '' f; do
  FILES+=("$f")
done < <(
  find . \
    -type f \
    \( -name "*.md" -o -name "*.chloeai" -o -name "*.heywy" -o -name "*.sh" \) \
    ! -name "init-project.sh" \
    ! -path "./.git/*" \
    -print0
)

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No template files found. Nothing to substitute."
  exit 0
fi

echo
echo "Substituting placeholders across ${#FILES[@]} files..."

for f in "${FILES[@]}"; do
  "${SED_INPLACE[@]}" \
    -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
    -e "s|{{PROJECT_BLURB}}|${PROJECT_BLURB}|g" \
    -e "s|{{OWNER_NAME}}|${OWNER_NAME}|g" \
    -e "s|{{UNLOCK_PHRASE}}|${UNLOCK_PHRASE}|g" \
    -e "s|{{TODAY}}|${TODAY}|g" \
    "$f"
done

echo "Substitution complete. Scanning for unfilled tokens..."
echo

LEFTOVER="$(grep -rE '\{\{[A-Z_]+\}\}' . --exclude-dir=.git --exclude=init-project.sh 2>/dev/null || true)"
if [[ -n "$LEFTOVER" ]]; then
  echo "WARNING: unfilled placeholder tokens found. Review and edit by hand:"
  echo "$LEFTOVER"
else
  echo "No unfilled tokens. Bootstrap clean."
fi

echo
read -r -p "Delete init-project.sh now? [y/N]: " ANSWER
if [[ "$ANSWER" =~ ^[yY]([eE][sS])?$ ]]; then
  rm -- "$0"
  echo "Self-deleted."
else
  echo "Keeping init-project.sh. Delete it manually when ready."
fi
