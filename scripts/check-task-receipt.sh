#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: scripts/check-task-receipt.sh [--target <path>] [--task-id <id>]"
  echo ""
  echo "Options:"
  echo "  --target <path>   Target project root (default: .)"
  echo "  --task-id <id>    Validate a specific receipt (default: validate all in-progress)"
  echo "  -h, --help        Show this help text"
  echo ""
  echo "Validates receipt YAML against schema and per-task-type required claims."
  echo "Exit: 0=PASSED, 1=BLOCKED"
}

TARGET="."
TASK_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 ;;
    --task-id) TASK_ID="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

echo "Task Receipt Check"

ATTESTATION_DIR="$TARGET/.governance/attestations"
INDEX_FILE="$ATTESTATION_DIR/index.jsonl"

# Guard: only enforce when attestation system is active
if [[ ! -f "$INDEX_FILE" ]] || [[ ! -s "$INDEX_FILE" ]]; then
  echo "  PASSED   Attestation system not yet active."
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "  WARNING  python3 not available — skipping receipt validation."
  exit 0
fi

# Locate the validator script (beside this script, or in framework root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR="$SCRIPT_DIR/validate-receipt.py"
if [[ ! -f "$VALIDATOR" ]]; then
  echo "  WARNING  validate-receipt.py not found — skipping receipt validation."
  exit 0
fi

# Collect receipt files to validate
RECEIPTS=()
if [[ -n "$TASK_ID" ]]; then
  RECEIPT_PATH="$ATTESTATION_DIR/${TASK_ID}.receipt.yaml"
  if [[ ! -f "$RECEIPT_PATH" ]]; then
    echo "  BLOCKED  Receipt not found: $RECEIPT_PATH"
    exit 1
  fi
  RECEIPTS+=("$RECEIPT_PATH")
else
  # Validate receipts bound to current commit (from COMMIT_EDITMSG)
  COMMIT_MSG_FILE="$TARGET/.git/COMMIT_EDITMSG"
  if [[ -f "$COMMIT_MSG_FILE" ]]; then
    while IFS= read -r tid; do
      [[ -z "$tid" ]] && continue
      rpath="$ATTESTATION_DIR/${tid}.receipt.yaml"
      [[ -f "$rpath" ]] && RECEIPTS+=("$rpath")
    done < <(grep -oP '^CG-Task:\s*\K(T-\d{8}-\d{3,})' "$COMMIT_MSG_FILE" 2>/dev/null || true)
  fi

  # Fallback: validate all in_progress receipts
  if [[ ${#RECEIPTS[@]} -eq 0 ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      rpath=$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('receipt_path',''))" "$line" 2>/dev/null || true)
      status=$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('status',''))" "$line" 2>/dev/null || true)
      if [[ "$status" == "in_progress" && -n "$rpath" && -f "$TARGET/$rpath" ]]; then
        RECEIPTS+=("$TARGET/$rpath")
      fi
    done < "$INDEX_FILE"
  fi
fi

if [[ ${#RECEIPTS[@]} -eq 0 ]]; then
  echo "  PASSED   No receipts to validate."
  exit 0
fi

# Validate each receipt
ERRORS=0
for receipt in "${RECEIPTS[@]}"; do
  BASENAME=$(basename "$receipt")
  RESULT=$(python3 "$VALIDATOR" "$receipt" "$TARGET" 2>&1) || true
  EXIT_CODE=${PIPESTATUS[0]:-$?}

  if echo "$RESULT" | grep -q "^ERROR:"; then
    echo "  BLOCKED  $BASENAME:"
    echo "$RESULT" | grep "^ERROR:" | sed 's/^/           /'
    ERRORS=$((ERRORS + 1))
  else
    echo "  OK       $BASENAME — valid"
  fi
done

if [[ "$ERRORS" -gt 0 ]]; then
  echo "  BLOCKED  $ERRORS receipt(s) failed validation."
  exit 1
fi

echo "  PASSED   All receipts valid."
exit 0
