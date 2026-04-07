#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: scripts/check-escalation-block.sh [--target <path>]"
  echo ""
  echo "Options:"
  echo "  --target <path>  Target project root (default: .)"
  echo "  -h, --help       Show this help text"
  echo ""
  echo "Exit: 0=PASSED, 1=BLOCKED (pending escalations + code staged)"
}

TARGET="."

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

ESC_FILE="$TARGET/.governance/escalations.jsonl"

echo "Escalation Block Check"

# No escalation file → PASSED
if [[ ! -f "$ESC_FILE" ]]; then
  echo "  PASSED   No escalation file found."
  exit 0
fi

# Count pending escalations (handle empty file gracefully)
PENDING=$(grep -c '"status":"pending"' "$ESC_FILE" 2>/dev/null || true)

if [[ "$PENDING" -eq 0 ]]; then
  echo "  PASSED   No pending escalations."
  exit 0
fi

# Pending escalations exist — check staged files
STAGED=$(git diff --cached --name-only 2>/dev/null || true)

if [[ -z "$STAGED" ]]; then
  echo "  PASSED   $PENDING pending escalation(s), but nothing staged."
  exit 0
fi

# Filter for governed code files (exclude docs, governance, tooling)
CODE_FILES=""
while IFS= read -r f; do
  case "$f" in
    docs/*|*.md|.governance/*|.githooks/*|.claude/*|.codex/*|scripts/*|tests/*)
      continue ;;
    *) CODE_FILES="$CODE_FILES$f"$'\n' ;;
  esac
done <<< "$STAGED"
CODE_FILES="${CODE_FILES%$'\n'}"

if [[ -z "$CODE_FILES" ]]; then
  echo "  PASSED   WARNING: $PENDING pending escalation(s), but no governed code staged."
  exit 0
fi

echo "  BLOCKED  $PENDING pending escalation(s). Resolve before committing code changes."
exit 1
