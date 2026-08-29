#!/usr/bin/env bash
# Preferred path: delegate to policy_engine.cli if available.
# Fallback: embedded logic for downstream projects bootstrapped pre-M2.
# Authority: docs/plans/2026-04-23-policy-engine-design.md §2.3

set -euo pipefail

usage() {
  echo "Usage: scripts/check-bug-evidence.sh [--target <path>]"
  echo "  --target <path>  Project root (default: auto-detect)"
  echo "  -h, --help       Show help"
}

TARGET=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_DIR="$SCRIPT_DIR/../governance-mcp-server"

if [[ -z "$TARGET" ]]; then
  d="$(pwd)"
  while [[ "$d" != "/" ]]; do
    if [[ -d "$d/.governance" ]]; then TARGET="$d"; break; fi
    d="$(dirname "$d")"
  done
  [[ -z "$TARGET" ]] && TARGET="."
fi

if [[ -d "$MCP_DIR/policy_engine" ]] && command -v python3 >/dev/null 2>&1; then
  PYTHONPATH="$MCP_DIR" exec python3 -m policy_engine.cli check bug-evidence --target "$TARGET"
fi

# ==============================================================
# Fallback
# ==============================================================

echo "Bug Evidence Check"

TASK_FILE="$TARGET/.governance/current-task.json"
if [[ ! -f "$TASK_FILE" ]]; then echo "  PASSED   No active task tracking."; exit 0; fi
if ! command -v python3 >/dev/null 2>&1; then echo "  WARNING  python3 not available — skipping check."; exit 0; fi

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

STAGED=$(git diff --cached --name-only 2>/dev/null || true)
if [[ -z "$STAGED" ]]; then echo "  PASSED   No staged files."; exit 0; fi
CODE_FILES=""
while IFS= read -r f; do
  case "$f" in
    docs/*|*.md|.governance/*|.githooks/*|.claude/*|.codex/*|scripts/*|tests/*) continue ;;
    *) CODE_FILES="$CODE_FILES$f"$'\n' ;;
  esac
done <<< "$STAGED"
CODE_FILES="${CODE_FILES%$'\n'}"
if [[ -z "$CODE_FILES" ]]; then echo "  PASSED   No governed code files staged."; exit 0; fi

ROUTE_DATA=$(python3 -c "
import json
try:
    d = json.load(open('$TASK_FILE'))
    print('true' if d.get('debug_required', True) else 'false')
    print(d.get('route_reason') or '')
    print(d.get('root_cause_evidence') or '')
except: pass
" 2>/dev/null || true)
DEBUG_REQUIRED=$(printf '%s\n' "$ROUTE_DATA" | sed -n '1p')
ROUTE_REASON=$(printf '%s\n' "$ROUTE_DATA" | sed -n '2p')
ROOT_CAUSE_EVIDENCE=$(printf '%s\n' "$ROUTE_DATA" | sed -n '3p')
if [[ "$DEBUG_REQUIRED" == "false" ]]; then
  if [[ -n "$ROUTE_REASON" && -n "$ROOT_CAUSE_EVIDENCE" ]]; then
    echo "  PASSED   Routine bug route has explicit reason and root-cause evidence."; exit 0
  fi
  echo "  BLOCKED  Routine bug route lacks route_reason or root_cause_evidence."; exit 1
fi

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

echo "  BLOCKED  Formal Debug route has code changes but no DEBUG_CASE found."
echo "           Create a DEBUG_CASE before committing code."
exit 1
