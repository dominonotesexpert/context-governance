#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: scripts/check-manual-attestation-policy.sh [--target <path>]"
  echo ""
  echo "Options:"
  echo "  --target <path>  Target project root (default: .)"
  echo "  -h, --help       Show this help text"
  echo ""
  echo "Enforces manual attestation policy: requires fallback_reason,"
  echo "flags for CI review. Exit: 0=PASSED, 1=BLOCKED"
}

TARGET="."

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

echo "Manual Attestation Policy Check"

ATTESTATION_DIR="$TARGET/.governance/attestations"
INDEX_FILE="$ATTESTATION_DIR/index.jsonl"

# Guard: only enforce when attestation system is active
if [[ ! -f "$INDEX_FILE" ]] || [[ ! -s "$INDEX_FILE" ]]; then
  echo "  PASSED   Attestation system not yet active."
  exit 0
fi

# Extract CG-Task from commit message
COMMIT_MSG_FILE="$TARGET/.git/COMMIT_EDITMSG"
if [[ ! -f "$COMMIT_MSG_FILE" ]]; then
  echo "  PASSED   No commit message available (will be validated by CI)."
  exit 0
fi

TASK_IDS=$(grep -oP '^CG-Task:\s*\K(T-\d{8}-\d{3,})' "$COMMIT_MSG_FILE" 2>/dev/null || true)
if [[ -z "$TASK_IDS" ]]; then
  echo "  PASSED   No CG-Task trailer — manual attestation check not applicable."
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "  WARNING  python3 not available — skipping manual attestation check."
  exit 0
fi

ERRORS=0
WARNINGS=0

while IFS= read -r task_id; do
  [[ -z "$task_id" ]] && continue
  RECEIPT_PATH="$ATTESTATION_DIR/${task_id}.receipt.yaml"
  if [[ ! -f "$RECEIPT_PATH" ]]; then
    continue
  fi

  RESULT=$(python3 - "$RECEIPT_PATH" <<'PYEOF'
import sys

receipt_path = sys.argv[1]
mode = None
reason = None

with open(receipt_path) as f:
    for line in f:
        stripped = line.strip()
        if stripped.startswith('attestation_mode:'):
            mode = stripped.split(':', 1)[1].strip()
        if stripped.startswith('manual_fallback_reason:'):
            val = stripped.split(':', 1)[1].strip()
            if val and val != 'null':
                reason = val

if mode != 'manual_attestation':
    print("NOT_MANUAL")
    sys.exit(0)

if not reason:
    print("ERROR: manual_attestation without manual_fallback_reason")
    sys.exit(1)
else:
    print(f"WARNING: manual_attestation — {reason}")
    sys.exit(0)
PYEOF
  )

  EXIT_CODE=$?
  if [[ "$RESULT" == "NOT_MANUAL" ]]; then
    continue
  elif [[ $EXIT_CODE -ne 0 ]]; then
    echo "  BLOCKED  $task_id: $RESULT"
    ERRORS=$((ERRORS + 1))
  else
    echo "  $RESULT"
    echo "           Protected branch merge requires explicit human approval."
    WARNINGS=$((WARNINGS + 1))
  fi
done <<< "$TASK_IDS"

if [[ "$ERRORS" -gt 0 ]]; then
  exit 1
fi

if [[ "$WARNINGS" -gt 0 ]]; then
  echo "  PASSED   (with $WARNINGS manual attestation warning(s))"
else
  echo "  PASSED   No manual attestation detected."
fi
exit 0
