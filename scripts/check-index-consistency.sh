#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: scripts/check-index-consistency.sh [--target <path>]"
  echo ""
  echo "Options:"
  echo "  --target <path>   Target project root (default: .)"
  echo "  -h, --help        Show this help text"
  echo ""
  echo "Validates .governance/attestations/index.jsonl consistency."
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

echo "Index Consistency Check"

INDEX_FILE="$TARGET/.governance/attestations/index.jsonl"

if [[ ! -f "$INDEX_FILE" ]] || [[ ! -s "$INDEX_FILE" ]]; then
  echo "  PASSED   Attestation index empty or absent."
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "  WARNING  python3 not available — skipping index validation."
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR="$SCRIPT_DIR/validate-index.py"
if [[ ! -f "$VALIDATOR" ]]; then
  echo "  WARNING  validate-index.py not found — skipping index validation."
  exit 0
fi

RESULT=$(python3 "$VALIDATOR" "$INDEX_FILE" "$TARGET" 2>&1) || true

if echo "$RESULT" | grep -q "^ERROR:"; then
  echo "$RESULT" | grep "^ERROR:" | sed 's/^/  BLOCKED  /'
  exit 1
fi

echo "  PASSED   Index is consistent."
exit 0
