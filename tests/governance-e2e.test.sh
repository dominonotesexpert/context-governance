#!/usr/bin/env bash
set -euo pipefail

# End-to-End Governance Attestation Tests
# Covers Phase 7 verification:
#   7.1 Cross-platform acceptance parity
#   7.2 Receipt vs evidence consistency
#   7.3 Manual attestation approval path
#   7.4 End-to-end bootstrap → task → pre-commit → CI

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0
FAIL=0
TMPDIR=""

cleanup() {
  [[ -n "$TMPDIR" ]] && rm -rf "$TMPDIR"
}
trap cleanup EXIT

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

TMPDIR=$(mktemp -d)

echo "=== Governance End-to-End Tests ==="
echo ""

# ============================================================
# 7.1 Cross-Platform Acceptance Parity
# ============================================================
echo "--- 7.1 Cross-Platform Acceptance Parity ---"

# Bootstrap both platforms
P_CC="$TMPDIR/platform-cc"
P_CX="$TMPDIR/platform-cx"
bash "$ROOT/scripts/bootstrap-project.sh" --target "$P_CC" --adapter claude-code >/dev/null 2>&1
bash "$ROOT/scripts/bootstrap-project.sh" --target "$P_CX" --platform codex --adapter codex >/dev/null 2>&1

# Same receipt schema
if diff -q "$P_CC/docs/templates/governance/TASK_RECEIPT.schema.yaml" \
           "$P_CX/docs/templates/governance/TASK_RECEIPT.schema.yaml" >/dev/null 2>&1; then
  pass "Receipt schema identical across platforms"
else
  fail "Receipt schema differs"
fi

# Same check scripts
SCRIPTS_MATCH=1
for s in check-commit-governance.sh check-task-binding.sh check-task-receipt.sh check-receipt-scope.sh check-manual-attestation-policy.sh; do
  if ! diff -q "$P_CC/scripts/$s" "$P_CX/scripts/$s" >/dev/null 2>&1; then
    SCRIPTS_MATCH=0
    break
  fi
done
if [[ "$SCRIPTS_MATCH" -eq 1 ]]; then
  pass "All gate scripts identical across platforms"
else
  fail "Gate scripts differ between platforms"
fi

# Same CI workflow
if diff -q "$P_CC/.github/workflows/governance.yml" "$P_CX/.github/workflows/governance.yml" >/dev/null 2>&1; then
  pass "CI workflow identical across platforms"
else
  fail "CI workflow differs"
fi

echo ""

# ============================================================
# 7.2 Receipt vs Evidence Consistency
# ============================================================
echo "--- 7.2 Receipt vs Evidence Consistency ---"

PROJ="$TMPDIR/evidence-test"
bash "$ROOT/scripts/bootstrap-project.sh" --target "$PROJ" >/dev/null 2>&1
cd "$PROJ"
git init -q
git add -A
git commit -q -m "initial bootstrap"

# Create a valid bug receipt with evidence
mkdir -p docs/agents/modules/auth docs/agents/debug/cases .governance/attestations
echo "# Auth Module Contract" > docs/agents/modules/auth/MODULE_CONTRACT.md
echo "# Debug Case Auth" > docs/agents/debug/cases/DEBUG_CASE_auth_login.md

cat > .governance/attestations/T-20260325-001.receipt.yaml << 'RECEIPT'
schema_version: 1
task_id: T-20260325-001
task_type: bug
status: in_progress
attestation_mode: mcp
manual_fallback_reason: null

scope:
  affected_modules: [auth]
  affected_paths:
    - src/auth/handler.ts

governance_claims:
  debug_case_present: true
  module_contract_refs:
    - docs/agents/modules/auth/MODULE_CONTRACT.md

evidence_refs:
  - path: docs/agents/debug/cases/DEBUG_CASE_auth_login.md
    kind: debug_case
    upstream_hash: null
  - path: docs/agents/modules/auth/MODULE_CONTRACT.md
    kind: module_contract
    upstream_hash: null

lifecycle:
  created_at: 2026-03-25T10:00:00Z
  updated_at: 2026-03-25T10:00:00Z
  issuer: governance-mcp
  session_ids:
    - S-001
RECEIPT

echo '{"task_id":"T-20260325-001","task_type":"bug","status":"in_progress","receipt_path":".governance/attestations/T-20260325-001.receipt.yaml","created_at":"2026-03-25T10:00:00Z","updated_at":"2026-03-25T10:00:00Z","attestation_mode":"mcp"}' > .governance/attestations/index.jsonl

# Test: valid receipt passes
RESULT=$(bash scripts/check-task-receipt.sh --task-id T-20260325-001 2>&1) || true
if echo "$RESULT" | grep -q "PASSED\|OK"; then
  pass "Valid bug receipt with evidence passes"
else
  fail "Valid bug receipt rejected: $RESULT"
fi

# Test: missing evidence (remove debug case)
rm docs/agents/debug/cases/DEBUG_CASE_auth_login.md
RESULT=$(bash scripts/check-task-receipt.sh --task-id T-20260325-001 2>&1) || true
if echo "$RESULT" | grep -q "BLOCKED\|ERROR\|does not exist"; then
  pass "Missing evidence correctly rejected"
else
  fail "Missing evidence was not rejected: $RESULT"
fi

# Restore evidence
echo "# Debug Case Auth" > docs/agents/debug/cases/DEBUG_CASE_auth_login.md

# Test: bug receipt without debug_case_present claim
cat > .governance/attestations/T-20260325-002.receipt.yaml << 'RECEIPT'
schema_version: 1
task_id: T-20260325-002
task_type: bug
status: in_progress
attestation_mode: mcp
manual_fallback_reason: null

scope:
  affected_modules: [auth]
  affected_paths: []

governance_claims:
  debug_case_present: false
  module_contract_refs:
    - docs/agents/modules/auth/MODULE_CONTRACT.md

evidence_refs:
  - path: docs/agents/modules/auth/MODULE_CONTRACT.md
    kind: module_contract
    upstream_hash: null

lifecycle:
  created_at: 2026-03-25T10:00:00Z
  updated_at: 2026-03-25T10:00:00Z
  issuer: governance-mcp
  session_ids: []
RECEIPT

RESULT=$(bash scripts/check-task-receipt.sh --task-id T-20260325-002 2>&1) || true
if echo "$RESULT" | grep -q "BLOCKED\|ERROR\|debug_case_present"; then
  pass "Bug receipt without debug_case_present correctly rejected"
else
  fail "Bug receipt without debug_case_present was not rejected: $RESULT"
fi

# Test: feature receipt without module_contract_refs
cat > .governance/attestations/T-20260325-003.receipt.yaml << 'RECEIPT'
schema_version: 1
task_id: T-20260325-003
task_type: feature
status: in_progress
attestation_mode: mcp
manual_fallback_reason: null

scope:
  affected_modules: [payments]
  affected_paths: []

governance_claims:
  module_contract_refs: []

evidence_refs: []

lifecycle:
  created_at: 2026-03-25T10:00:00Z
  updated_at: 2026-03-25T10:00:00Z
  issuer: governance-mcp
  session_ids: []
RECEIPT

RESULT=$(bash scripts/check-task-receipt.sh --task-id T-20260325-003 2>&1) || true
if echo "$RESULT" | grep -q "BLOCKED\|ERROR\|module_contract_refs"; then
  pass "Feature receipt without module_contract_refs correctly rejected"
else
  fail "Feature receipt without module_contract_refs was not rejected: $RESULT"
fi

# Test: autoresearch receipt without optimization_log_ref
cat > .governance/attestations/T-20260325-004.receipt.yaml << 'RECEIPT'
schema_version: 1
task_id: T-20260325-004
task_type: autoresearch
status: in_progress
attestation_mode: mcp
manual_fallback_reason: null

scope:
  affected_modules: []
  affected_paths: []

governance_claims:
  escalation_upstream: false

evidence_refs: []

lifecycle:
  created_at: 2026-03-25T10:00:00Z
  updated_at: 2026-03-25T10:00:00Z
  issuer: governance-mcp
  session_ids: []
RECEIPT

RESULT=$(bash scripts/check-task-receipt.sh --task-id T-20260325-004 2>&1) || true
if echo "$RESULT" | grep -q "BLOCKED\|ERROR\|optimization_log_ref\|escalation_upstream"; then
  pass "Autoresearch receipt with missing claims correctly rejected"
else
  fail "Autoresearch receipt with missing claims was not rejected: $RESULT"
fi

echo ""

# ============================================================
# 7.3 Manual Attestation Approval Path
# ============================================================
echo "--- 7.3 Manual Attestation Approval Path ---"

# Test: manual attestation without reason
cat > .governance/attestations/T-20260325-005.receipt.yaml << 'RECEIPT'
schema_version: 1
task_id: T-20260325-005
task_type: design
status: in_progress
attestation_mode: manual_attestation
manual_fallback_reason: null

scope:
  affected_modules: []
  affected_paths: []

governance_claims: {}

evidence_refs: []

lifecycle:
  created_at: 2026-03-25T10:00:00Z
  updated_at: 2026-03-25T10:00:00Z
  issuer: manual
  session_ids: []
RECEIPT

RESULT=$(bash scripts/check-task-receipt.sh --task-id T-20260325-005 2>&1) || true
if echo "$RESULT" | grep -q "BLOCKED\|ERROR\|manual_fallback_reason"; then
  pass "Manual attestation without reason correctly rejected"
else
  fail "Manual attestation without reason was not rejected: $RESULT"
fi

# Test: manual attestation with valid reason
cat > .governance/attestations/T-20260325-006.receipt.yaml << 'RECEIPT'
schema_version: 1
task_id: T-20260325-006
task_type: design
status: in_progress
attestation_mode: manual_attestation
manual_fallback_reason: MCP server offline during development

scope:
  affected_modules: []
  affected_paths: []

governance_claims: {}

evidence_refs: []

lifecycle:
  created_at: 2026-03-25T10:00:00Z
  updated_at: 2026-03-25T10:00:00Z
  issuer: manual
  session_ids: []
RECEIPT

RESULT=$(bash scripts/check-task-receipt.sh --task-id T-20260325-006 2>&1) || true
if echo "$RESULT" | grep -q "PASSED\|OK"; then
  pass "Manual attestation with valid reason passes"
else
  fail "Manual attestation with valid reason was rejected: $RESULT"
fi

echo ""

# ============================================================
# 7.4 End-to-End Bootstrap → Task → Pre-commit → Validation
# ============================================================
echo "--- 7.4 End-to-End Lifecycle ---"

E2E="$TMPDIR/e2e-project"
bash "$ROOT/scripts/bootstrap-project.sh" --target "$E2E" >/dev/null 2>&1
cd "$E2E"
git init -q
git add -A
git commit -q -m "initial bootstrap"

# Validate bootstrap
VALIDATE_RESULT=$(bash scripts/bootstrap-project.sh --target "$E2E" --validate 2>&1 || true)
if echo "$VALIDATE_RESULT" | grep -q "OK.*\.governance/ directory"; then
  pass "Bootstrap creates .governance/ directory"
else
  fail "Bootstrap missing .governance/ directory"
fi

if echo "$VALIDATE_RESULT" | grep -q "OK.*attestation index"; then
  pass "Bootstrap creates attestation index"
else
  fail "Bootstrap missing attestation index"
fi

# Pre-commit runs without attestation (Phase 1.5 only)
PRE_RESULT=$(bash scripts/check-commit-governance.sh 2>&1 || true)
if echo "$PRE_RESULT" | grep -q "All governance checks passed"; then
  pass "Pre-commit passes with no active attestation"
else
  fail "Pre-commit failed with no active attestation: $PRE_RESULT"
fi

# Activate attestation by adding an index entry
mkdir -p .governance/attestations docs/agents/modules/core
echo "# Core Contract" > docs/agents/modules/core/MODULE_CONTRACT.md

cat > .governance/attestations/T-20260325-010.receipt.yaml << 'RECEIPT'
schema_version: 1
task_id: T-20260325-010
task_type: feature
status: in_progress
attestation_mode: mcp
manual_fallback_reason: null

scope:
  affected_modules: [core]
  affected_paths:
    - src/core/main.ts
    - docs/agents/modules/core/MODULE_CONTRACT.md

governance_claims:
  module_contract_refs:
    - docs/agents/modules/core/MODULE_CONTRACT.md

evidence_refs:
  - path: docs/agents/modules/core/MODULE_CONTRACT.md
    kind: module_contract
    upstream_hash: null

lifecycle:
  created_at: 2026-03-25T10:00:00Z
  updated_at: 2026-03-25T10:00:00Z
  issuer: governance-mcp
  session_ids:
    - S-010
RECEIPT

echo '{"task_id":"T-20260325-010","task_type":"feature","status":"in_progress","receipt_path":".governance/attestations/T-20260325-010.receipt.yaml","created_at":"2026-03-25T10:00:00Z","updated_at":"2026-03-25T10:00:00Z","attestation_mode":"mcp"}' > .governance/attestations/index.jsonl

# Pre-commit now runs 8 checks (Phase 1.5 + Phase 3)
PRE_RESULT2=$(bash scripts/check-commit-governance.sh 2>&1 || true)
if echo "$PRE_RESULT2" | grep -q "\[5/8\].*Task binding"; then
  pass "Phase 3 checks activate when attestation index has entries"
else
  fail "Phase 3 checks did not activate: $PRE_RESULT2"
fi

if echo "$PRE_RESULT2" | grep -q "All governance checks passed"; then
  pass "All 8 checks pass with valid receipt"
else
  fail "Checks failed with valid receipt: $PRE_RESULT2"
fi

# Receipt validation passes for valid receipt
RECEIPT_RESULT=$(bash scripts/check-task-receipt.sh --task-id T-20260325-010 2>&1) || true
if echo "$RECEIPT_RESULT" | grep -q "PASSED\|OK"; then
  pass "Receipt validation passes for well-formed feature receipt"
else
  fail "Receipt validation failed: $RECEIPT_RESULT"
fi

# Trivial task type passes with minimal receipt
cat > .governance/attestations/T-20260325-011.receipt.yaml << 'RECEIPT'
schema_version: 1
task_id: T-20260325-011
task_type: trivial
status: completed
attestation_mode: mcp
manual_fallback_reason: null

scope:
  affected_modules: []
  affected_paths: []

governance_claims: {}

evidence_refs: []

lifecycle:
  created_at: 2026-03-25T12:00:00Z
  updated_at: 2026-03-25T12:00:00Z
  issuer: governance-mcp
  session_ids: []
RECEIPT

RECEIPT_RESULT2=$(bash scripts/check-task-receipt.sh --task-id T-20260325-011 2>&1) || true
if echo "$RECEIPT_RESULT2" | grep -q "PASSED\|OK"; then
  pass "Trivial task type passes with minimal receipt"
else
  fail "Trivial task type failed: $RECEIPT_RESULT2"
fi

echo ""

# ============================================================
# Summary
# ============================================================
echo "==========================="
echo "E2E Tests: $PASS passed, $FAIL failed"

if [[ "$FAIL" -gt 0 ]]; then
  echo "FAILED"
  exit 1
fi

echo "All end-to-end tests passed."
exit 0
