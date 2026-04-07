#!/usr/bin/env bash
set -euo pipefail

# Adapter Parity Tests
# Verifies that Codex and Claude Code adapters produce equivalent acceptance rules.
# Authority: design §6.3 — same receipt schema, evidence requirements, pre-commit, CI rules.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0
FAIL=0
TMPDIR_CC=""
TMPDIR_CX=""

cleanup() {
  [[ -n "$TMPDIR_CC" ]] && rm -rf "$TMPDIR_CC"
  [[ -n "$TMPDIR_CX" ]] && rm -rf "$TMPDIR_CX"
}
trap cleanup EXIT

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

echo "=== Adapter Parity Tests ==="
echo ""

# --- Bootstrap both adapters ---
TMPDIR_CC=$(mktemp -d)
TMPDIR_CX=$(mktemp -d)

bash "$ROOT/scripts/bootstrap-project.sh" --target "$TMPDIR_CC" --adapter claude-code >/dev/null 2>&1
bash "$ROOT/scripts/bootstrap-project.sh" --target "$TMPDIR_CX" --platform codex --adapter codex >/dev/null 2>&1

# --- Test 1: Same receipt schema ---
echo "Receipt Schema Parity:"
if diff -q "$TMPDIR_CC/docs/templates/governance/TASK_RECEIPT.schema.yaml" \
           "$TMPDIR_CX/docs/templates/governance/TASK_RECEIPT.schema.yaml" >/dev/null 2>&1; then
  pass "Receipt schema identical"
else
  fail "Receipt schema differs between adapters"
fi

# --- Test 2: Same evidence requirements docs ---
echo ""
echo "Evidence Requirements Parity:"
for doc in ATTESTATION_INDEX.schema.md MANUAL_ATTESTATION_POLICY.md TASK_BINDING_CONVENTION.md GOVERNANCE_MODE_RECEIPT_RULES.md BRANCH_PROTECTION.md; do
  if diff -q "$TMPDIR_CC/docs/templates/governance/$doc" \
             "$TMPDIR_CX/docs/templates/governance/$doc" >/dev/null 2>&1; then
    pass "$doc identical"
  else
    fail "$doc differs"
  fi
done

# --- Test 3: Same pre-commit scripts ---
echo ""
echo "Pre-Commit Script Parity:"
for script in check-commit-governance.sh check-derived-edits.sh check-module-contract.sh check-escalation-block.sh check-bug-evidence.sh check-task-binding.sh check-task-receipt.sh check-receipt-scope.sh check-manual-attestation-policy.sh; do
  CC_FILE="$TMPDIR_CC/scripts/$script"
  CX_FILE="$TMPDIR_CX/scripts/$script"
  if [[ -f "$CC_FILE" ]] && [[ -f "$CX_FILE" ]]; then
    if diff -q "$CC_FILE" "$CX_FILE" >/dev/null 2>&1; then
      pass "$script identical"
    else
      fail "$script differs"
    fi
  elif [[ ! -f "$CC_FILE" ]] && [[ ! -f "$CX_FILE" ]]; then
    pass "$script absent on both (expected)"
  else
    fail "$script exists on one adapter but not the other"
  fi
done

# --- Test 4: Same CI workflow ---
echo ""
echo "CI Workflow Parity:"
if diff -q "$TMPDIR_CC/.github/workflows/governance.yml" \
           "$TMPDIR_CX/.github/workflows/governance.yml" >/dev/null 2>&1; then
  pass "CI workflow identical"
else
  fail "CI workflow differs"
fi

# --- Test 5: Same MCP server ---
echo ""
echo "MCP Server Parity:"
if diff -q "$TMPDIR_CC/governance-mcp-server/server.py" \
           "$TMPDIR_CX/governance-mcp-server/server.py" >/dev/null 2>&1; then
  pass "MCP server identical"
else
  fail "MCP server differs"
fi

# --- Test 6: Same attestation index ---
echo ""
echo "Attestation Index Parity:"
if diff -q "$TMPDIR_CC/.governance/attestations/index.jsonl" \
           "$TMPDIR_CX/.governance/attestations/index.jsonl" >/dev/null 2>&1; then
  pass "Attestation index identical (both empty)"
else
  fail "Attestation index differs"
fi

# --- Test 7: Adapter-specific files exist only where expected ---
echo ""
echo "Adapter-Specific Files:"
if [[ -f "$TMPDIR_CC/adapters/claude-code/hooks.json.template" ]]; then
  pass "Claude Code has hooks template"
else
  fail "Claude Code missing hooks template"
fi

if [[ ! -f "$TMPDIR_CC/.codex/config.toml.template" ]]; then
  pass "Claude Code does NOT have Codex config (correct)"
else
  fail "Claude Code has Codex config (should not)"
fi

if [[ -f "$TMPDIR_CX/.codex/config.toml.template" ]]; then
  pass "Codex has config template"
else
  fail "Codex missing config template"
fi

if [[ -f "$TMPDIR_CX/adapters/codex/skills/governance-check/SKILL.md" ]]; then
  pass "Codex has governance-check skill"
else
  fail "Codex missing governance-check skill"
fi

if [[ ! -f "$TMPDIR_CX/adapters/claude-code/hooks.json.template" ]]; then
  pass "Codex does NOT have Claude Code hooks (correct)"
else
  fail "Codex has Claude Code hooks (should not)"
fi

# --- Summary ---
echo ""
echo "==========================="
echo "Parity: $PASS passed, $FAIL failed"

if [[ "$FAIL" -gt 0 ]]; then
  echo "FAILED — adapters are not at parity"
  exit 1
fi

echo "All parity checks passed."
exit 0
