#!/usr/bin/env bash
set -euo pipefail

# End-to-End Governance Attestation Tests
# Covers Phase 7 verification:
#   7.1 Cross-platform acceptance parity
#   7.2 Receipt vs evidence consistency
#   7.3 Manual attestation approval path
#   7.4 End-to-end bootstrap → task → pre-commit → CI
#   7.5 Index consistency

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

# Helper: write receipt YAML via python3 to avoid heredoc issues
write_receipt() {
  local dest="$1"
  shift
  python3 -c "
import sys
lines = sys.argv[1:]
with open('$dest', 'w') as f:
    f.write('\n'.join(lines) + '\n')
" "$@"
}

TMPDIR=$(mktemp -d)

echo "=== Governance End-to-End Tests ==="
echo ""

# ============================================================
# 7.1 Cross-Platform Acceptance Parity
# ============================================================
echo "--- 7.1 Cross-Platform Acceptance Parity ---"

P_CC="$TMPDIR/platform-cc"
P_CX="$TMPDIR/platform-cx"
bash "$ROOT/scripts/bootstrap-project.sh" --target "$P_CC" --adapter claude-code >/dev/null 2>&1
bash "$ROOT/scripts/bootstrap-project.sh" --target "$P_CX" --platform codex --adapter codex >/dev/null 2>&1

if diff -q "$P_CC/docs/templates/governance/TASK_RECEIPT.schema.yaml" \
           "$P_CX/docs/templates/governance/TASK_RECEIPT.schema.yaml" >/dev/null 2>&1; then
  pass "Receipt schema identical across platforms"
else
  fail "Receipt schema differs"
fi

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
git -C "$PROJ" init -q
git -C "$PROJ" add -A
git -C "$PROJ" commit -q -m "initial bootstrap"

mkdir -p "$PROJ/docs/agents/modules/auth" "$PROJ/docs/agents/debug/cases" "$PROJ/.governance/attestations"
echo "# Auth Module Contract" > "$PROJ/docs/agents/modules/auth/MODULE_CONTRACT.md"
echo "# Debug Case Auth" > "$PROJ/docs/agents/debug/cases/DEBUG_CASE_auth_login.md"

write_receipt "$PROJ/.governance/attestations/T-20260325-001.receipt.yaml" \
  "schema_version: 1" \
  "task_id: T-20260325-001" \
  "task_type: bug" \
  "status: in_progress" \
  "attestation_mode: mcp" \
  "scope:" \
  "  affected_modules: [auth]" \
  "  affected_paths:" \
  "    - src/auth/handler.ts" \
  "governance_claims:" \
  "  debug_case_present: true" \
  "  module_contract_refs:" \
  "    - docs/agents/modules/auth/MODULE_CONTRACT.md" \
  "evidence_refs:" \
  "  - path: docs/agents/debug/cases/DEBUG_CASE_auth_login.md" \
  "    kind: debug_case" \
  "    upstream_hash: null" \
  "  - path: docs/agents/modules/auth/MODULE_CONTRACT.md" \
  "    kind: module_contract" \
  "    upstream_hash: null" \
  "lifecycle:" \
  "  created_at: 2026-03-25T10:00:00Z" \
  "  updated_at: 2026-03-25T10:00:00Z" \
  "  issuer: governance-mcp" \
  "  session_ids:" \
  "    - S-001"

echo '{"task_id":"T-20260325-001","task_type":"bug","status":"in_progress","receipt_path":".governance/attestations/T-20260325-001.receipt.yaml","created_at":"2026-03-25T10:00:00Z","updated_at":"2026-03-25T10:00:00Z","attestation_mode":"mcp"}' > "$PROJ/.governance/attestations/index.jsonl"

# Test: valid receipt passes
RESULT=$(timeout 15 bash -c "cd '$PROJ' && bash scripts/check-task-receipt.sh --task-id T-20260325-001" 2>&1) || true
if echo "$RESULT" | grep -q "PASSED\|OK"; then
  pass "Valid bug receipt with evidence passes"
else
  fail "Valid bug receipt rejected: $RESULT"
fi

# Test: missing evidence (remove debug case)
rm "$PROJ/docs/agents/debug/cases/DEBUG_CASE_auth_login.md"
RESULT=$(timeout 15 bash -c "cd '$PROJ' && bash scripts/check-task-receipt.sh --task-id T-20260325-001" 2>&1) || true
if echo "$RESULT" | grep -q "BLOCKED\|ERROR\|does not exist"; then
  pass "Missing evidence correctly rejected"
else
  fail "Missing evidence was not rejected: $RESULT"
fi

# Restore evidence
echo "# Debug Case Auth" > "$PROJ/docs/agents/debug/cases/DEBUG_CASE_auth_login.md"

# Test: bug receipt without debug_case_present claim
write_receipt "$PROJ/.governance/attestations/T-20260325-002.receipt.yaml" \
  "schema_version: 1" \
  "task_id: T-20260325-002" \
  "task_type: bug" \
  "status: in_progress" \
  "attestation_mode: mcp" \
  "scope:" \
  "  affected_modules: [auth]" \
  "  affected_paths: []" \
  "governance_claims:" \
  "  debug_case_present: false" \
  "  module_contract_refs:" \
  "    - docs/agents/modules/auth/MODULE_CONTRACT.md" \
  "evidence_refs:" \
  "  - path: docs/agents/modules/auth/MODULE_CONTRACT.md" \
  "    kind: module_contract" \
  "    upstream_hash: null" \
  "lifecycle:" \
  "  created_at: 2026-03-25T10:00:00Z" \
  "  updated_at: 2026-03-25T10:00:00Z" \
  "  issuer: governance-mcp" \
  "  session_ids: []"

RESULT=$(timeout 15 bash -c "cd '$PROJ' && bash scripts/check-task-receipt.sh --task-id T-20260325-002" 2>&1) || true
if echo "$RESULT" | grep -q "BLOCKED\|ERROR\|debug_case_present"; then
  pass "Bug receipt without debug_case_present correctly rejected"
else
  fail "Bug receipt without debug_case_present was not rejected: $RESULT"
fi

# Test: feature receipt without module_contract_refs
write_receipt "$PROJ/.governance/attestations/T-20260325-003.receipt.yaml" \
  "schema_version: 1" \
  "task_id: T-20260325-003" \
  "task_type: feature" \
  "status: in_progress" \
  "attestation_mode: mcp" \
  "scope:" \
  "  affected_modules: [payments]" \
  "  affected_paths: []" \
  "governance_claims:" \
  "  module_contract_refs: []" \
  "evidence_refs: []" \
  "lifecycle:" \
  "  created_at: 2026-03-25T10:00:00Z" \
  "  updated_at: 2026-03-25T10:00:00Z" \
  "  issuer: governance-mcp" \
  "  session_ids: []"

RESULT=$(timeout 15 bash -c "cd '$PROJ' && bash scripts/check-task-receipt.sh --task-id T-20260325-003" 2>&1) || true
if echo "$RESULT" | grep -q "BLOCKED\|ERROR\|module_contract_refs"; then
  pass "Feature receipt without module_contract_refs correctly rejected"
else
  fail "Feature receipt without module_contract_refs was not rejected: $RESULT"
fi

# Test: autoresearch receipt without optimization_log_ref
write_receipt "$PROJ/.governance/attestations/T-20260325-004.receipt.yaml" \
  "schema_version: 1" \
  "task_id: T-20260325-004" \
  "task_type: autoresearch" \
  "status: in_progress" \
  "attestation_mode: mcp" \
  "scope:" \
  "  affected_modules: []" \
  "  affected_paths: []" \
  "governance_claims:" \
  "  escalation_upstream: false" \
  "evidence_refs: []" \
  "lifecycle:" \
  "  created_at: 2026-03-25T10:00:00Z" \
  "  updated_at: 2026-03-25T10:00:00Z" \
  "  issuer: governance-mcp" \
  "  session_ids: []"

RESULT=$(timeout 15 bash -c "cd '$PROJ' && bash scripts/check-task-receipt.sh --task-id T-20260325-004" 2>&1) || true
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

write_receipt "$PROJ/.governance/attestations/T-20260325-005.receipt.yaml" \
  "schema_version: 1" \
  "task_id: T-20260325-005" \
  "task_type: design" \
  "status: in_progress" \
  "attestation_mode: manual_attestation" \
  "manual_fallback_reason: null" \
  "scope:" \
  "  affected_modules: []" \
  "  affected_paths: []" \
  "governance_claims: {}" \
  "evidence_refs: []" \
  "lifecycle:" \
  "  created_at: 2026-03-25T10:00:00Z" \
  "  updated_at: 2026-03-25T10:00:00Z" \
  "  issuer: manual" \
  "  session_ids: []"

RESULT=$(timeout 15 bash -c "cd '$PROJ' && bash scripts/check-task-receipt.sh --task-id T-20260325-005" 2>&1) || true
if echo "$RESULT" | grep -q "BLOCKED\|ERROR\|manual_fallback_reason"; then
  pass "Manual attestation without reason correctly rejected"
else
  fail "Manual attestation without reason was not rejected: $RESULT"
fi

write_receipt "$PROJ/.governance/attestations/T-20260325-006.receipt.yaml" \
  "schema_version: 1" \
  "task_id: T-20260325-006" \
  "task_type: design" \
  "status: in_progress" \
  "attestation_mode: manual_attestation" \
  "manual_fallback_reason: MCP server offline during development" \
  "scope:" \
  "  affected_modules: []" \
  "  affected_paths: []" \
  "governance_claims: {}" \
  "evidence_refs: []" \
  "lifecycle:" \
  "  created_at: 2026-03-25T10:00:00Z" \
  "  updated_at: 2026-03-25T10:00:00Z" \
  "  issuer: manual" \
  "  session_ids: []"

RESULT=$(timeout 15 bash -c "cd '$PROJ' && bash scripts/check-task-receipt.sh --task-id T-20260325-006" 2>&1) || true
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
git -C "$E2E" init -q
git -C "$E2E" add -A
git -C "$E2E" commit -q -m "initial bootstrap"

# Validate bootstrap
VALIDATE_RESULT=$(bash "$ROOT/scripts/bootstrap-project.sh" --target "$E2E" --validate 2>&1 || true)
if echo "$VALIDATE_RESULT" | grep -q "\.governance/ directory"; then
  pass "Bootstrap creates .governance/ directory"
else
  fail "Bootstrap missing .governance/ directory"
fi

if echo "$VALIDATE_RESULT" | grep -q "attestation index"; then
  pass "Bootstrap creates attestation index"
else
  fail "Bootstrap missing attestation index"
fi

# Pre-commit with no attestation
PRE_RESULT=$(timeout 30 bash -c "cd '$E2E' && bash scripts/check-commit-governance.sh" 2>&1 || true)
if echo "$PRE_RESULT" | grep -q "All governance checks passed"; then
  pass "Pre-commit passes with no active attestation"
else
  fail "Pre-commit failed with no active attestation"
fi

# Activate attestation
mkdir -p "$E2E/.governance/attestations" "$E2E/docs/agents/modules/core"
echo "# Core Contract" > "$E2E/docs/agents/modules/core/MODULE_CONTRACT.md"

write_receipt "$E2E/.governance/attestations/T-20260325-010.receipt.yaml" \
  "schema_version: 1" \
  "task_id: T-20260325-010" \
  "task_type: feature" \
  "status: in_progress" \
  "attestation_mode: mcp" \
  "scope:" \
  "  affected_modules: [core]" \
  "  affected_paths:" \
  "    - src/core/main.ts" \
  "governance_claims:" \
  "  module_contract_refs:" \
  "    - docs/agents/modules/core/MODULE_CONTRACT.md" \
  "evidence_refs:" \
  "  - path: docs/agents/modules/core/MODULE_CONTRACT.md" \
  "    kind: module_contract" \
  "    upstream_hash: null" \
  "lifecycle:" \
  "  created_at: 2026-03-25T10:00:00Z" \
  "  updated_at: 2026-03-25T10:00:00Z" \
  "  issuer: governance-mcp" \
  "  session_ids:" \
  "    - S-010"

echo '{"task_id":"T-20260325-010","task_type":"feature","status":"in_progress","receipt_path":".governance/attestations/T-20260325-010.receipt.yaml","created_at":"2026-03-25T10:00:00Z","updated_at":"2026-03-25T10:00:00Z","attestation_mode":"mcp"}' > "$E2E/.governance/attestations/index.jsonl"

# Pre-commit with active attestation
PRE_RESULT2=$(timeout 30 bash -c "cd '$E2E' && bash scripts/check-commit-governance.sh" 2>&1 || true)
if echo "$PRE_RESULT2" | grep -q "Task binding"; then
  pass "Phase 3 checks activate when attestation index has entries"
else
  fail "Phase 3 checks did not activate"
fi

if echo "$PRE_RESULT2" | grep -q "Index consistency"; then
  pass "Index consistency check runs"
else
  fail "Index consistency check missing"
fi

# Receipt validation
RECEIPT_RESULT=$(timeout 15 bash -c "cd '$E2E' && bash scripts/check-task-receipt.sh --task-id T-20260325-010" 2>&1 || true)
if echo "$RECEIPT_RESULT" | grep -q "OK"; then
  pass "Receipt validation passes for well-formed feature receipt"
else
  fail "Receipt validation failed: $RECEIPT_RESULT"
fi

# Trivial task
write_receipt "$E2E/.governance/attestations/T-20260325-011.receipt.yaml" \
  "schema_version: 1" \
  "task_id: T-20260325-011" \
  "task_type: trivial" \
  "status: completed" \
  "attestation_mode: mcp" \
  "scope:" \
  "  affected_modules: []" \
  "  affected_paths: []" \
  "governance_claims: {}" \
  "evidence_refs: []" \
  "lifecycle:" \
  "  created_at: 2026-03-25T12:00:00Z" \
  "  updated_at: 2026-03-25T12:00:00Z" \
  "  issuer: governance-mcp" \
  "  session_ids: []"

RECEIPT_RESULT2=$(timeout 15 bash -c "cd '$E2E' && bash scripts/check-task-receipt.sh --task-id T-20260325-011" 2>&1 || true)
if echo "$RECEIPT_RESULT2" | grep -q "OK"; then
  pass "Trivial task type passes with minimal receipt"
else
  fail "Trivial task type failed: $RECEIPT_RESULT2"
fi

# ============================================================
# 7.5 Index Consistency
# ============================================================
echo ""
echo "--- 7.5 Index Consistency ---"

IDX_PROJ="$TMPDIR/idx-test"
bash "$ROOT/scripts/bootstrap-project.sh" --target "$IDX_PROJ" >/dev/null 2>&1
git -C "$IDX_PROJ" init -q
git -C "$IDX_PROJ" add -A
git -C "$IDX_PROJ" commit -q -m "initial"

IDX_RESULT=$(timeout 15 bash -c "cd '$IDX_PROJ' && bash scripts/check-index-consistency.sh" 2>&1) || true
if echo "$IDX_RESULT" | grep -q "PASSED"; then
  pass "Empty index passes consistency check"
else
  fail "Empty index failed: $IDX_RESULT"
fi

mkdir -p "$IDX_PROJ/.governance/attestations" "$IDX_PROJ/docs/agents/modules/core"
echo "# Core" > "$IDX_PROJ/docs/agents/modules/core/MODULE_CONTRACT.md"

write_receipt "$IDX_PROJ/.governance/attestations/T-20260401-001.receipt.yaml" \
  "schema_version: 1" \
  "task_id: T-20260401-001" \
  "task_type: feature" \
  "status: completed" \
  "attestation_mode: mcp" \
  "scope:" \
  "  affected_modules: [core]" \
  "  affected_paths: []" \
  "governance_claims:" \
  "  module_contract_refs:" \
  "    - docs/agents/modules/core/MODULE_CONTRACT.md" \
  "evidence_refs:" \
  "  - path: docs/agents/modules/core/MODULE_CONTRACT.md" \
  "    kind: module_contract" \
  "    upstream_hash: null" \
  "lifecycle:" \
  "  created_at: 2026-04-01T10:00:00Z" \
  "  updated_at: 2026-04-01T12:00:00Z" \
  "  issuer: governance-mcp"

echo '{"task_id":"T-20260401-001","task_type":"feature","status":"completed","receipt_path":".governance/attestations/T-20260401-001.receipt.yaml","created_at":"2026-04-01T10:00:00Z","updated_at":"2026-04-01T12:00:00Z","attestation_mode":"mcp"}' > "$IDX_PROJ/.governance/attestations/index.jsonl"

IDX_RESULT=$(timeout 15 bash -c "cd '$IDX_PROJ' && bash scripts/check-index-consistency.sh" 2>&1) || true
if echo "$IDX_RESULT" | grep -q "PASSED"; then
  pass "Valid index with matching receipt passes"
else
  fail "Valid index rejected: $IDX_RESULT"
fi

# Duplicate task_id
echo '{"task_id":"T-20260401-001","task_type":"feature","status":"completed","receipt_path":".governance/attestations/T-20260401-001.receipt.yaml","created_at":"2026-04-01T10:00:00Z","updated_at":"2026-04-01T12:00:00Z","attestation_mode":"mcp"}' >> "$IDX_PROJ/.governance/attestations/index.jsonl"

IDX_RESULT=$(timeout 15 bash -c "cd '$IDX_PROJ' && bash scripts/check-index-consistency.sh" 2>&1) || true
if echo "$IDX_RESULT" | grep -q "BLOCKED\|ERROR\|duplicate"; then
  pass "Duplicate task_id correctly rejected"
else
  fail "Duplicate task_id was not rejected: $IDX_RESULT"
fi

# Restore
echo '{"task_id":"T-20260401-001","task_type":"feature","status":"completed","receipt_path":".governance/attestations/T-20260401-001.receipt.yaml","created_at":"2026-04-01T10:00:00Z","updated_at":"2026-04-01T12:00:00Z","attestation_mode":"mcp"}' > "$IDX_PROJ/.governance/attestations/index.jsonl"

# Status mismatch
sed -i.bak 's/status: completed/status: in_progress/' "$IDX_PROJ/.governance/attestations/T-20260401-001.receipt.yaml"
IDX_RESULT=$(timeout 15 bash -c "cd '$IDX_PROJ' && bash scripts/check-index-consistency.sh" 2>&1) || true
if echo "$IDX_RESULT" | grep -q "BLOCKED\|ERROR\|status"; then
  pass "Status mismatch between index and receipt detected"
else
  fail "Status mismatch was not detected: $IDX_RESULT"
fi

# Restore
sed -i.bak 's/status: in_progress/status: completed/' "$IDX_PROJ/.governance/attestations/T-20260401-001.receipt.yaml"

# Missing receipt
rm -f "$IDX_PROJ/.governance/attestations/T-20260401-001.receipt.yaml" "$IDX_PROJ/.governance/attestations/T-20260401-001.receipt.yaml.bak"
IDX_RESULT=$(timeout 15 bash -c "cd '$IDX_PROJ' && bash scripts/check-index-consistency.sh" 2>&1) || true
if echo "$IDX_RESULT" | grep -q "BLOCKED\|ERROR\|not found"; then
  pass "Missing receipt file correctly rejected"
else
  fail "Missing receipt file was not rejected: $IDX_RESULT"
fi

# Invalid JSON
echo "not valid json" > "$IDX_PROJ/.governance/attestations/index.jsonl"
IDX_RESULT=$(timeout 15 bash -c "cd '$IDX_PROJ' && bash scripts/check-index-consistency.sh" 2>&1) || true
if echo "$IDX_RESULT" | grep -q "BLOCKED\|ERROR\|invalid JSON"; then
  pass "Invalid JSON in index correctly rejected"
else
  fail "Invalid JSON was not rejected: $IDX_RESULT"
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
