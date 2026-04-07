#!/usr/bin/env bash
# Context Governance Pre-Commit Check
# Orchestrates all commit-time governance checks.
# Called by .githooks/pre-commit or directly.
# Exit codes: 0 = all pass, 1 = any violation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "Usage: $(basename "$0")"
  echo "  Runs all commit-time governance checks sequentially."
  echo "  Stops on first failure. Exit 0 = all pass, 1 = violation."
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

# Detect whether the attestation system is active
# (index.jsonl exists and has at least one entry)
ATTESTATION_ACTIVE=0
INDEX_FILE=".governance/attestations/index.jsonl"
if [[ -f "$INDEX_FILE" ]] && [[ -s "$INDEX_FILE" ]]; then
  ATTESTATION_ACTIVE=1
fi

if [[ "$ATTESTATION_ACTIVE" -eq 1 ]]; then
  TOTAL=8
else
  TOTAL=4
fi

echo "=== Context Governance Pre-Commit Check ==="
echo ""

# --- Phase 1.5: Core checks (always active) ---

# Check 1: Derived document protection
if [[ -f "$SCRIPT_DIR/check-derived-edits.sh" ]]; then
  echo "  [1/$TOTAL] Derived document protection..."
  bash "$SCRIPT_DIR/check-derived-edits.sh" --strict || exit 1
fi

# Check 2: Module contract requirement
if [[ -f "$SCRIPT_DIR/check-module-contract.sh" ]]; then
  echo "  [2/$TOTAL] Module contract requirement..."
  bash "$SCRIPT_DIR/check-module-contract.sh" || exit 1
fi

# Check 3: Escalation blocking
if [[ -f "$SCRIPT_DIR/check-escalation-block.sh" ]]; then
  echo "  [3/$TOTAL] Escalation blocking..."
  bash "$SCRIPT_DIR/check-escalation-block.sh" || exit 1
fi

# Check 4: Bug evidence
if [[ -f "$SCRIPT_DIR/check-bug-evidence.sh" ]]; then
  echo "  [4/$TOTAL] Bug evidence..."
  bash "$SCRIPT_DIR/check-bug-evidence.sh" || exit 1
fi

# --- Phase 3: Receipt-dependent checks (active when attestation index has entries) ---

if [[ "$ATTESTATION_ACTIVE" -eq 1 ]]; then
  if [[ -f "$SCRIPT_DIR/check-task-binding.sh" ]]; then
    echo "  [5/$TOTAL] Task binding..."
    bash "$SCRIPT_DIR/check-task-binding.sh" || exit 1
  fi

  if [[ -f "$SCRIPT_DIR/check-task-receipt.sh" ]]; then
    echo "  [6/$TOTAL] Task receipt validation..."
    bash "$SCRIPT_DIR/check-task-receipt.sh" || exit 1
  fi

  if [[ -f "$SCRIPT_DIR/check-receipt-scope.sh" ]]; then
    echo "  [7/$TOTAL] Receipt scope..."
    bash "$SCRIPT_DIR/check-receipt-scope.sh" || exit 1
  fi

  if [[ -f "$SCRIPT_DIR/check-manual-attestation-policy.sh" ]]; then
    echo "  [8/$TOTAL] Manual attestation policy..."
    bash "$SCRIPT_DIR/check-manual-attestation-policy.sh" || exit 1
  fi
fi

echo ""
echo "All governance checks passed."
exit 0
