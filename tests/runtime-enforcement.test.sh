#!/usr/bin/env bash
# Runtime enforcement end-to-end test (M3).
# Invokes adapters/claude-code/cc-authority-hook.py with different actor roles
# and asserts exit codes match the authority matrix.
#
# Authority: docs/plans/2026-04-23-runtime-enforcement-implementation-plan.md Step K

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP_TMP=""

cleanup() {
  [[ -n "$BOOTSTRAP_TMP" ]] && rm -rf "$BOOTSTRAP_TMP"
}
trap cleanup EXIT

BOOTSTRAP_TMP=$(mktemp -d)
bash "$ROOT/scripts/bootstrap-project.sh" --target "$BOOTSTRAP_TMP" --adapter claude-code >/dev/null 2>&1
TEST_ROOT="$BOOTSTRAP_TMP"
HOOK="$TEST_ROOT/adapters/claude-code/cc-authority-hook.py"

PASS=0
FAIL=0
pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

# --- Scenario 1: implementation writes PROJECT_BASELINE -> BLOCKED ---
CG_REPO_ROOT="$TEST_ROOT" \
CG_ACTOR_ROLE=implementation \
CLAUDE_TOOL_NAME=Edit \
CLAUDE_TOOL_PARAM_file_path=docs/agents/PROJECT_BASELINE.md \
python3 "$HOOK" >/dev/null 2>&1
RC=$?
if [[ "$RC" -eq 1 ]]; then
  pass "impl writing PROJECT_BASELINE returns exit 1 (blocked)"
else
  fail "impl writing PROJECT_BASELINE returned exit $RC (expected 1)"
fi

# --- Scenario 2: system-architect writes SYSTEM_INVARIANTS -> ALLOWED ---
CG_REPO_ROOT="$TEST_ROOT" \
CG_ACTOR_ROLE=system-architect \
CLAUDE_TOOL_NAME=Edit \
CLAUDE_TOOL_PARAM_file_path=docs/agents/system/SYSTEM_INVARIANTS.md \
python3 "$HOOK" >/dev/null 2>&1
RC=$?
if [[ "$RC" -eq 0 ]]; then
  pass "SA writing SYSTEM_INVARIANTS returns exit 0 (allowed)"
else
  fail "SA writing SYSTEM_INVARIANTS returned exit $RC (expected 0)"
fi

# --- Scenario 3: implementation writes Tier-7 code -> ALLOWED ---
CG_REPO_ROOT="$TEST_ROOT" \
CG_ACTOR_ROLE=implementation \
CLAUDE_TOOL_NAME=Write \
CLAUDE_TOOL_PARAM_file_path=src/auth/handler.ts \
python3 "$HOOK" >/dev/null 2>&1
RC=$?
if [[ "$RC" -eq 0 ]]; then
  pass "impl writing Tier-7 code returns exit 0 (allowed)"
else
  fail "impl writing Tier-7 code returned exit $RC (expected 0)"
fi

# --- Scenario 4: restricted context class + WebFetch -> BLOCKED ---
TASK_FILE="$TEST_ROOT/.governance/current-task.json"
BACKUP=""
if [[ -f "$TASK_FILE" ]]; then BACKUP="$(cat "$TASK_FILE")"; fi
mkdir -p "$ROOT/.governance"
echo '{"task_id":"T-M3-E2E-001","active_role":"implementation","context_class":"restricted"}' > "$TASK_FILE"

CG_REPO_ROOT="$TEST_ROOT" \
CLAUDE_TOOL_NAME=WebFetch \
CLAUDE_TOOL_PARAM_file_path="" \
python3 "$HOOK" >/dev/null 2>&1
RC=$?
if [[ "$RC" -eq 1 ]]; then
  pass "restricted context + WebFetch returns exit 1 (blocked)"
else
  fail "restricted context + WebFetch returned exit $RC (expected 1)"
fi

# Restore task file state.
if [[ -n "$BACKUP" ]]; then
  echo "$BACKUP" > "$TASK_FILE"
else
  rm -f "$TASK_FILE"
fi

# --- Scenario 5: PDRs persisted to decisions.jsonl ---
DECISIONS="$TEST_ROOT/.governance/decisions.jsonl"
if [[ -f "$DECISIONS" ]] && grep -q '"decision":"DENY"' "$DECISIONS"; then
  pass "PDR with DENY decision persisted to decisions.jsonl"
else
  fail "no DENY PDR found in decisions.jsonl after test run"
fi

# Clean up test-generated decisions (don't leak into git state).
rm -f "$DECISIONS"

# --- Scenario 6: freshly bootstrapped Claude project enforces the same rule ---
CG_REPO_ROOT="$TEST_ROOT" \
CG_ACTOR_ROLE=implementation \
CLAUDE_TOOL_NAME=Edit \
CLAUDE_TOOL_PARAM_file_path=docs/agents/PROJECT_BASELINE.md \
PYTHONDONTWRITEBYTECODE=1 \
python3 "$BOOTSTRAP_TMP/adapters/claude-code/cc-authority-hook.py" >/dev/null 2>&1
RC=$?
if [[ "$RC" -eq 1 ]]; then
  pass "bootstrapped Claude project blocks unauthorized baseline write"
else
  fail "bootstrapped Claude project returned exit $RC (expected 1)"
fi

echo ""
echo "==========================="
echo "Runtime Enforcement: $PASS passed, $FAIL failed"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
echo "All runtime enforcement tests passed."
