#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: scripts/check-task-binding.sh [--target <path>]"
  echo ""
  echo "Options:"
  echo "  --target <path>  Target project root (default: .)"
  echo "  -h, --help       Show this help text"
  echo ""
  echo "Validates that the pending commit message contains a CG-Task trailer"
  echo "referencing a valid receipt, when the attestation system is active."
  echo "Exit: 0=PASSED, 1=BLOCKED"
}

TARGET="."

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

echo "Task Binding Check"

ATTESTATION_DIR="$TARGET/.governance/attestations"
INDEX_FILE="$ATTESTATION_DIR/index.jsonl"

# Guard: only enforce when attestation system is active (index has entries)
if [[ ! -f "$INDEX_FILE" ]] || [[ ! -s "$INDEX_FILE" ]]; then
  echo "  PASSED   Attestation system not yet active (empty or missing index)."
  exit 0
fi

# Check staged files — only enforce binding when governed files are staged
STAGED=$(git diff --cached --name-only 2>/dev/null || true)
if [[ -z "$STAGED" ]]; then
  echo "  PASSED   No staged files."
  exit 0
fi

# Filter for governed files (code + docs/agents/)
GOVERNED_FILES=""
while IFS= read -r f; do
  case "$f" in
    .governance/*|.githooks/*|.claude/*|.codex/*|scripts/check-*|tests/*) continue ;;
    *) GOVERNED_FILES="$GOVERNED_FILES$f"$'\n' ;;
  esac
done <<< "$STAGED"
GOVERNED_FILES="${GOVERNED_FILES%$'\n'}"

if [[ -z "$GOVERNED_FILES" ]]; then
  echo "  PASSED   No governed files staged."
  exit 0
fi

# Read the commit message (from .git/COMMIT_EDITMSG during pre-commit, or from stdin)
COMMIT_MSG_FILE="$TARGET/.git/COMMIT_EDITMSG"
if [[ -f "$COMMIT_MSG_FILE" ]]; then
  COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")
else
  # During pre-commit hook, COMMIT_EDITMSG may not exist yet.
  # In that case, we check via prepare-commit-msg or defer to CI.
  echo "  PASSED   No commit message available (will be validated by CI)."
  exit 0
fi

# Extract CG-Task trailer(s)
TASK_IDS=$(echo "$COMMIT_MSG" | grep -oP '^CG-Task:\s*\K(T-\d{8}-\d{3,})' || true)

if [[ -z "$TASK_IDS" ]]; then
  echo "  BLOCKED  Governed files staged but no CG-Task trailer in commit message."
  echo "           Add: CG-Task: T-YYYYMMDD-NNN"
  exit 1
fi

# Validate each referenced task ID has a receipt
ERRORS=0
while IFS= read -r task_id; do
  [[ -z "$task_id" ]] && continue
  RECEIPT_FILE="$ATTESTATION_DIR/${task_id}.receipt.yaml"
  if [[ ! -f "$RECEIPT_FILE" ]]; then
    echo "  BLOCKED  CG-Task: $task_id — receipt not found at $RECEIPT_FILE"
    ERRORS=$((ERRORS + 1))
  else
    echo "  OK       CG-Task: $task_id — receipt exists"
  fi
done <<< "$TASK_IDS"

if [[ "$ERRORS" -gt 0 ]]; then
  exit 1
fi

echo "  PASSED   Task binding valid."
exit 0
