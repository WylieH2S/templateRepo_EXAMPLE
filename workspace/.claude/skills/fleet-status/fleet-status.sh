#!/usr/bin/env bash
# fleet-status: surface the latest HANDOFF block from each repo's readme_AI cartridge

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

QUIET=0
SINGLE_REPO=""

for arg in "$@"; do
    case "$arg" in
        --quiet|-q) QUIET=1 ;;
        --repo=*) SINGLE_REPO="${arg#--repo=}" ;;
        --repo) shift; SINGLE_REPO="$1" ;;
        --help|-h)
            echo "Usage: fleet-status.sh [--quiet] [--repo=<name>]"
            echo "  --quiet      One-line per repo (no reason, no tasks)"
            echo "  --repo=NAME  Single repo only"
            exit 0 ;;
    esac
done

# Color support
if [ -t 1 ]; then
    BOLD='\033[1m'; RESET='\033[0m'; DIM='\033[2m'; CYAN='\033[36m'; YELLOW='\033[33m'
else
    BOLD=''; RESET=''; DIM=''; CYAN=''; YELLOW=''
fi

echo -e "${BOLD}Fleet status — $(date '+%Y-%m-%d')${RESET}"
echo -e "${DIM}Workspace: $WORKSPACE_ROOT${RESET}"
echo ""

REPOS_FOUND=0
REPOS_WITH_HANDOFF=0
REPOS_NO_CARTRIDGE=()
REPOS_NO_HANDOFF=()

for repo_path in "$WORKSPACE_ROOT"/*/; do
    repo_name="$(basename "$repo_path")"

    # Filter to single repo if requested
    [ -n "$SINGLE_REPO" ] && [ "$repo_name" != "$SINGLE_REPO" ] && continue

    [ -d "$repo_path/.git" ] || continue
    REPOS_FOUND=$((REPOS_FOUND + 1))

    cartridge="$repo_path/readme_AI.ai"

    if [ -z "$cartridge" ]; then
        REPOS_NO_CARTRIDGE+=("$repo_name")
        continue
    fi

    # Scan @ blocks newest-first (prepended); skip experiment blocks (no zoom_level=)
    last_line=""
    while IFS= read -r candidate; do
        lno="${candidate%%:*}"
        snippet=$(tail -n +"$lno" "$cartridge" | head -20)
        if echo "$snippet" | grep -q '^zoom_level='; then
            last_line="$candidate"
            break
        fi
    done < <(grep -n '^@[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]|' "$cartridge")
    if [ -z "$last_line" ]; then
        REPOS_NO_HANDOFF+=("$repo_name")
        continue
    fi

    REPOS_WITH_HANDOFF=$((REPOS_WITH_HANDOFF + 1))
    lineno="${last_line%%:*}"
    header="${last_line#*:}"

    date_val=$(echo "$header" | sed 's/@\([0-9-]*\)|.*/\1/')
    session_val=$(echo "$header" | sed 's/^@[0-9-]*|\([^|]*\)|.*/\1/')

    # Read block (60 lines covers any HANDOFF)
    block=$(tail -n +"$lineno" "$cartridge" | head -60)

    zoom=$(echo "$block"   | grep '^zoom_level='         | head -1 | cut -d= -f2-)
    model=$(echo "$block"  | grep '^recommended_model='  | head -1 | cut -d= -f2-)
    effort=$(echo "$block" | grep '^recommended_effort=' | head -1 | cut -d= -f2-)
    reason=$(echo "$block" | grep '^reason='             | head -1 | sed 's/^reason="\(.*\)"/\1/')
    signed=$(echo "$block" | grep '^signed='             | head -1 | sed 's/^signed="\(.*\)"/\1/')

    if [ "$QUIET" -eq 1 ]; then
        printf "${BOLD}%-28s${RESET}  %s | %s | zoom=${YELLOW}%-12s${RESET} %s/%s\n" \
            "[$repo_name]" "$date_val" "$session_val" "$zoom" "$model" "$effort"
        continue
    fi

    echo -e "${BOLD}[$repo_name]${RESET}  $date_val | $session_val"
    echo -e "  zoom=${YELLOW}${zoom}${RESET}  model=${model}  effort=${effort}"

    if [ -n "$reason" ]; then
        short_reason="${reason:0:100}"
        [ ${#reason} -gt 100 ] && short_reason="${short_reason}..."
        echo "  reason: $short_reason"
    fi

    # First 3 task_queue items
    task_lines=$(echo "$block" | grep -E '^\s*\{tier:' | head -3)
    if [ -n "$task_lines" ]; then
        while IFS= read -r tline; do
            tier_val=$(echo "$tline" | sed 's/.*{tier:\([^,}]*\).*/\1/' | tr -d ' ')
            task_text=$(echo "$tline" | sed 's/.*task:"\([^"]*\)".*/\1/')
            short_task="${task_text:0:72}"
            [ ${#task_text} -gt 72 ] && short_task="${short_task}..."
            echo -e "  • ${CYAN}[${tier_val}]${RESET} $short_task"
        done <<< "$task_lines"
    fi

    [ -n "$signed" ] && echo -e "  ${DIM}signed: $signed${RESET}"
    echo ""
done

echo "── Summary ──"
echo "Repos: ${REPOS_FOUND} total | ${REPOS_WITH_HANDOFF} with HANDOFF"
[ ${#REPOS_NO_HANDOFF[@]} -gt 0 ]    && echo "No HANDOFF:   ${REPOS_NO_HANDOFF[*]}"
[ ${#REPOS_NO_CARTRIDGE[@]} -gt 0 ]  && echo "No cartridge: ${REPOS_NO_CARTRIDGE[*]}"
exit 0
