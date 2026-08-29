#!/usr/bin/env bash
# Preferred path: delegate to policy_engine.cli if available.
# Fallback: embedded grep-based logic for downstream projects pre-M2.
# Authority: docs/plans/2026-04-23-policy-engine-design.md §2.3

set -euo pipefail

usage() {
  echo "Usage: scripts/check-escalation-block.sh [--target <path>]"
  echo "  --target <path>  Project root (default: auto-detect)"
  echo "  -h, --help       Show help"
  echo "Exit: 0=PASSED, 1=BLOCKED"
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
  PYTHONPATH="$MCP_DIR" exec python3 -m policy_engine.cli check escalation-block --target "$TARGET"
fi

# ==============================================================
# Fallback
# ==============================================================

ESC_FILE="$TARGET/.governance/escalations.jsonl"
echo "Escalation Block Check"

if [[ ! -f "$ESC_FILE" ]]; then
  echo "  PASSED   No escalation file found."; exit 0
fi

PENDING=$(grep -c '"status":"pending"' "$ESC_FILE" 2>/dev/null || true)
if [[ "$PENDING" -eq 0 ]]; then
  echo "  PASSED   No pending escalations."; exit 0
fi

STAGED=$(git diff --cached --name-only 2>/dev/null || true)
if [[ -z "$STAGED" ]]; then
  echo "  PASSED   $PENDING pending escalation(s), but nothing staged."; exit 0
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
  echo "  PASSED   WARNING: $PENDING pending escalation(s), but no governed code staged."; exit 0
fi

echo "  BLOCKED  $PENDING pending escalation(s). Resolve before committing code changes."
exit 1
