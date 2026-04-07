#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: scripts/check-bug-evidence.sh [--target <path>]"
  echo "  --target <path>  Project root (default: .)  |  -h, --help  Show help"
  echo "Exit codes: 0 = PASSED, 1 = BLOCKED (bug task without DEBUG_CASE)"
}

TARGET="."
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

echo "Bug Evidence Check"

TASK_FILE="$TARGET/.governance/current-task.json"
if [[ ! -f "$TASK_FILE" ]]; then echo "  PASSED   No active task tracking."; exit 0; fi
if ! command -v python3 >/dev/null 2>&1; then echo "  WARNING  python3 not available — skipping check."; exit 0; fi

# Extract task_type
TASK_TYPE=$(python3 -c "
import json
try:
    d = json.load(open('$TASK_FILE'))
    print(d.get('task_type', ''))
except: pass
" 2>/dev/null || true)

if [[ "$TASK_TYPE" != "bug" ]]; then
  echo "  PASSED   Task type is '${TASK_TYPE:-unknown}', not 'bug'."; exit 0
fi

# Get staged files and filter for code files
STAGED=$(git diff --cached --name-only 2>/dev/null || true)
if [[ -z "$STAGED" ]]; then
  echo "  PASSED   No staged files."; exit 0
fi
CODE_FILES=""
while IFS= read -r f; do
  case "$f" in
    docs/*|*.md|.governance/*|.githooks/*|.claude/*|.codex/*|scripts/*|tests/*) continue ;;
    *) CODE_FILES="$CODE_FILES$f"$'\n' ;;
  esac
done <<< "$STAGED"
CODE_FILES="${CODE_FILES%$'\n'}"
if [[ -z "$CODE_FILES" ]]; then
  echo "  PASSED   No governed code files staged."; exit 0
fi

# Extract affected_modules; fall back to walk-up detection from staged paths
MODULES=$(python3 -c "
import json
try:
    d = json.load(open('$TASK_FILE'))
    for m in d.get('affected_modules', []):
        print(m)
except: pass
" 2>/dev/null || true)

if [[ -z "$MODULES" ]]; then
  MODULES_DIR="$TARGET/docs/agents/modules"
  while IFS= read -r f; do
    dir="$(dirname "$f")"
    while [[ "$dir" != "." && "$dir" != "/" ]]; do
      dirname_part="$(basename "$dir")"
      if [[ -d "$MODULES_DIR/$dirname_part" ]]; then
        MODULES="$MODULES$dirname_part"$'\n'; break
      fi
      dir="$(dirname "$dir")"
    done
  done <<< "$CODE_FILES"
  MODULES=$(echo "$MODULES" | sort -u)
  MODULES="${MODULES%$'\n'}"
fi

# Check for DEBUG_CASE files (on disk or staged)
CASES_DIR="$TARGET/docs/agents/debug/cases"
if [[ -n "$MODULES" ]]; then
  while IFS= read -r mod; do
    [[ -z "$mod" ]] && continue
    if compgen -G "$CASES_DIR/DEBUG_CASE_${mod}*.md" >/dev/null 2>&1; then
      echo "  PASSED   DEBUG_CASE found for module '$mod'."; exit 0
    fi
    if echo "$STAGED" | grep -q "docs/agents/debug/cases/DEBUG_CASE_${mod}" 2>/dev/null; then
      echo "  PASSED   DEBUG_CASE for module '$mod' is staged."; exit 0
    fi
  done <<< "$MODULES"
fi

echo "  BLOCKED  Bug task with code changes but no DEBUG_CASE found."
echo "           Create a DEBUG_CASE before committing code."
exit 1
