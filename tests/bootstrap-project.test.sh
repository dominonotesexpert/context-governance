#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0
CLEANUP_DIRS=()

cleanup() {
  for d in "${CLEANUP_DIRS[@]}"; do
    rm -rf "$d"
  done
}
trap cleanup EXIT

mktemp_tracked() {
  local d
  d="$(mktemp -d)"
  CLEANUP_DIRS+=("$d")
  echo "$d"
}

assert_pass() {
  PASS=$((PASS + 1))
}

assert_fail() {
  echo "FAIL: $1" >&2
  FAIL=$((FAIL + 1))
}

# ============================================================
# 1. Basic bootstrap — all core files created
# ============================================================
T="$(mktemp_tracked)"
bash "$ROOT/scripts/bootstrap-project.sh" --target "$T" --platform claude >/dev/null

# Platform entrypoint
test -f "$T/CLAUDE.md" && assert_pass || assert_fail "CLAUDE.md not created"

# Bootstrap readiness
test -f "$T/docs/agents/BOOTSTRAP_READINESS.md" && assert_pass || assert_fail "BOOTSTRAP_READINESS missing"

# System artifacts (9 files)
for f in SYSTEM_GOAL_PACK SYSTEM_AUTHORITY_MAP SYSTEM_INVARIANTS SYSTEM_BOOTSTRAP_PACK \
         SYSTEM_SCENARIO_MAP_INDEX SYSTEM_CONFLICT_REGISTER ROUTING_POLICY MODULE_TAXONOMY \
         BASELINE_INTERPRETATION_LOG; do
  test -f "$T/docs/agents/system/$f.md" && assert_pass || assert_fail "system/$f.md missing"
done

# Debug artifacts (4 files)
for f in DEBUG_BOOTSTRAP_PACK DEBUG_CASE_TEMPLATE BUG_CLASS_REGISTER RECURRENCE_PREVENTION_RULES; do
  test -f "$T/docs/agents/debug/$f.md" && assert_pass || assert_fail "debug/$f.md missing"
done

# Verification artifacts
test -f "$T/docs/agents/verification/ACCEPTANCE_RULES.md" && assert_pass || assert_fail "ACCEPTANCE_RULES missing"

# No module seeded by default
test ! -f "$T/docs/agents/modules/billing/MODULE_CONTRACT.md" && assert_pass || assert_fail "module should not exist without --seed-module"

# ============================================================
# 2. Namespace READMEs — all 10 created
# ============================================================
for f in \
  "$T/docs/agents/README.md" \
  "$T/docs/agents/system/README.md" \
  "$T/docs/agents/modules/README.md" \
  "$T/docs/agents/debug/README.md" \
  "$T/docs/agents/implementation/README.md" \
  "$T/docs/agents/verification/README.md" \
  "$T/docs/agents/frontend/README.md" \
  "$T/docs/agents/execution/README.md" \
  "$T/docs/agents/task-checklists/README.md" \
  "$T/docs/plans/agents/README.md"; do
  test -f "$f" && assert_pass || assert_fail "namespace README missing: $f"
done

# ============================================================
# 3. Directory structure — all expected dirs exist
# ============================================================
for d in \
  "$T/docs/agents/system/scenarios" \
  "$T/docs/agents/modules" \
  "$T/docs/agents/debug/cases" \
  "$T/docs/agents/implementation" \
  "$T/docs/agents/verification" \
  "$T/docs/agents/frontend" \
  "$T/docs/agents/execution" \
  "$T/docs/agents/task-checklists" \
  "$T/docs/plans/agents"; do
  test -d "$d" && assert_pass || assert_fail "directory missing: $d"
done

# ============================================================
# 4. Skip behavior — existing files not overwritten
# ============================================================
echo "existing" > "$T/CLAUDE.md"
bash "$ROOT/scripts/bootstrap-project.sh" --target "$T" --platform claude >/dev/null
[[ "$(cat "$T/CLAUDE.md")" == "existing" ]] && assert_pass || assert_fail "existing file was overwritten"

# ============================================================
# 5. --force overwrites
# ============================================================
bash "$ROOT/scripts/bootstrap-project.sh" --target "$T" --platform claude --force >/dev/null
[[ "$(cat "$T/CLAUDE.md")" != "existing" ]] && assert_pass || assert_fail "--force did not overwrite"

# ============================================================
# 6. --copy-commands
# ============================================================
bash "$ROOT/scripts/bootstrap-project.sh" --target "$T" --platform claude --copy-commands >/dev/null
test -f "$T/.claude/commands/bug.md" && assert_pass || assert_fail "commands/bug.md missing"
test -f "$T/.claude/commands/impl.md" && assert_pass || assert_fail "commands/impl.md missing"
test -f "$T/.claude/commands/audit.md" && assert_pass || assert_fail "commands/audit.md missing"
test -f "$T/.claude/commands/verify.md" && assert_pass || assert_fail "commands/verify.md missing"

# ============================================================
# 7. --copy-skills
# ============================================================
T_SKILLS="$(mktemp_tracked)"
bash "$ROOT/scripts/bootstrap-project.sh" --target "$T_SKILLS" --platform claude --copy-skills >/dev/null
test -d "$T_SKILLS/.claude/skills" && assert_pass || assert_fail "skills dir missing"
for skill in system-architect module-architect debug implementation verification frontend-specialist; do
  test -f "$T_SKILLS/.claude/skills/$skill/SKILL.md" && assert_pass || assert_fail "skill $skill missing"
done

# ============================================================
# 8. --seed-module creates module contract
# ============================================================
bash "$ROOT/scripts/bootstrap-project.sh" --target "$T" --platform claude --seed-module billing >/dev/null
test -f "$T/docs/agents/modules/billing/MODULE_CONTRACT.md" && assert_pass || assert_fail "seeded module missing"

# ============================================================
# 9. Frontmatter — all bootstrapped files have YAML frontmatter
# ============================================================
FRONTMATTER_FILES=(
  "$T/docs/agents/system/SYSTEM_GOAL_PACK.md"
  "$T/docs/agents/system/SYSTEM_AUTHORITY_MAP.md"
  "$T/docs/agents/system/SYSTEM_INVARIANTS.md"
  "$T/docs/agents/system/ROUTING_POLICY.md"
  "$T/docs/agents/system/MODULE_TAXONOMY.md"
  "$T/docs/agents/system/SYSTEM_CONFLICT_REGISTER.md"
  "$T/docs/agents/system/SYSTEM_BOOTSTRAP_PACK.md"
  "$T/docs/agents/system/SYSTEM_SCENARIO_MAP_INDEX.md"
  "$T/docs/agents/system/BASELINE_INTERPRETATION_LOG.md"
  "$T/docs/agents/debug/DEBUG_BOOTSTRAP_PACK.md"
  "$T/docs/agents/debug/DEBUG_CASE_TEMPLATE.md"
  "$T/docs/agents/debug/BUG_CLASS_REGISTER.md"
  "$T/docs/agents/debug/RECURRENCE_PREVENTION_RULES.md"
  "$T/docs/agents/verification/ACCEPTANCE_RULES.md"
  "$T/docs/agents/BOOTSTRAP_READINESS.md"
  "$T/docs/agents/modules/billing/MODULE_CONTRACT.md"
)
for f in "${FRONTMATTER_FILES[@]}"; do
  if head -1 "$f" | grep -q "^---$" && head -5 "$f" | grep -q "^artifact_type:"; then
    assert_pass
  else
    assert_fail "frontmatter missing in $f"
  fi
done

# ============================================================
# 10. Frontmatter fields — verify all 6 required fields present
# ============================================================
SAMPLE="$T/docs/agents/system/SYSTEM_GOAL_PACK.md"
for field in artifact_type status owner_role scope downstream_consumers last_reviewed; do
  if head -10 "$SAMPLE" | grep -q "^${field}:"; then
    assert_pass
  else
    assert_fail "frontmatter field '$field' missing in SYSTEM_GOAL_PACK"
  fi
done

# ============================================================
# 11. MODULE_CONTRACT 10-section structure
# ============================================================
MC="$T/docs/agents/modules/billing/MODULE_CONTRACT.md"
EXPECTED_SECTIONS=(
  "## 1. Responsibility"
  "## 2. Boundaries"
  "## 3. Inputs"
  "## 4. Outputs"
  "## 5. Upstream Dependencies"
  "## 6. Downstream Consumers"
  "## 7. Shared Interfaces"
  "## 8. Invariants"
  "## 9. Breaking Change Policy"
  "## 10. Verification Expectations"
)
for section in "${EXPECTED_SECTIONS[@]}"; do
  if grep -qF "$section" "$MC"; then
    assert_pass
  else
    assert_fail "MODULE_CONTRACT missing section: $section"
  fi
done

# ============================================================
# 12. ROUTING_POLICY content — has route table and key rules
# ============================================================
RP="$T/docs/agents/system/ROUTING_POLICY.md"
for pattern in "System.*Module.*Debug.*Implementation.*Verification" \
               "System.*Module.*Implementation.*Verification" \
               "System.*Module.*Verification" \
               "Frontend Specialist" \
               "Reroute"; do
  if grep -qiE "$pattern" "$RP"; then
    assert_pass
  else
    assert_fail "ROUTING_POLICY missing expected content: $pattern"
  fi
done

# ============================================================
# 13. MODULE_TAXONOMY content — has all 5 module types
# ============================================================
MT="$T/docs/agents/system/MODULE_TAXONOMY.md"
for mtype in "service-module" "domain-flow-module" "runtime-subsystem" "ui-domain-module" "cross-cutting-concern"; do
  if grep -qi "$mtype" "$MT"; then
    assert_pass
  else
    assert_fail "MODULE_TAXONOMY missing type: $mtype"
  fi
done

# ============================================================
# 14. Platform variants — codex and gemini
# ============================================================
T_CODEX="$(mktemp_tracked)"
T_GEMINI="$(mktemp_tracked)"

bash "$ROOT/scripts/bootstrap-project.sh" --target "$T_CODEX" --platform codex >/dev/null
test -f "$T_CODEX/AGENTS.md" && assert_pass || assert_fail "codex: AGENTS.md missing"
test ! -f "$T_CODEX/CLAUDE.md" && assert_pass || assert_fail "codex: should not have CLAUDE.md"
# Codex still gets all governance docs
test -f "$T_CODEX/docs/agents/system/SYSTEM_GOAL_PACK.md" && assert_pass || assert_fail "codex: system docs missing"
test -f "$T_CODEX/docs/agents/system/ROUTING_POLICY.md" && assert_pass || assert_fail "codex: ROUTING_POLICY missing"

bash "$ROOT/scripts/bootstrap-project.sh" --target "$T_GEMINI" --platform gemini >/dev/null
test -f "$T_GEMINI/GEMINI.md" && assert_pass || assert_fail "gemini: GEMINI.md missing"
test ! -f "$T_GEMINI/CLAUDE.md" && assert_pass || assert_fail "gemini: should not have CLAUDE.md"
test -f "$T_GEMINI/docs/agents/system/SYSTEM_GOAL_PACK.md" && assert_pass || assert_fail "gemini: system docs missing"

# ============================================================
# 15. --dry-run — no files written
# ============================================================
T_DRY="$(mktemp_tracked)"
DRY_OUTPUT="$(bash "$ROOT/scripts/bootstrap-project.sh" --target "$T_DRY" --platform claude --dry-run 2>&1)"
[[ "$DRY_OUTPUT" == *"dry run"* ]] && assert_pass || assert_fail "dry-run: missing 'dry run' in output"
test ! -f "$T_DRY/docs/agents/system/SYSTEM_GOAL_PACK.md" && assert_pass || assert_fail "dry-run: files should not be written"
# Dry-run output should list files that would be created
[[ "$DRY_OUTPUT" == *"SYSTEM_GOAL_PACK"* ]] && assert_pass || assert_fail "dry-run: should list SYSTEM_GOAL_PACK"
[[ "$DRY_OUTPUT" == *"ROUTING_POLICY"* ]] && assert_pass || assert_fail "dry-run: should list ROUTING_POLICY"

# ============================================================
# 16. --validate — reports unfilled docs
# ============================================================
T_VAL="$(mktemp_tracked)"
bash "$ROOT/scripts/bootstrap-project.sh" --target "$T_VAL" --platform claude >/dev/null
VAL_OUTPUT="$(bash "$ROOT/scripts/bootstrap-project.sh" --target "$T_VAL" --validate 2>&1)"
[[ "$VAL_OUTPUT" == *"UNFILLED"* ]] && assert_pass || assert_fail "validate: should report UNFILLED for fresh bootstrap"
[[ "$VAL_OUTPUT" == *"SYSTEM_GOAL_PACK"* ]] && assert_pass || assert_fail "validate: should mention SYSTEM_GOAL_PACK"
[[ "$VAL_OUTPUT" == *"ROUTING_POLICY"* ]] && assert_pass || assert_fail "validate: should mention ROUTING_POLICY"
[[ "$VAL_OUTPUT" == *"issue"* ]] && assert_pass || assert_fail "validate: should report issue count"

# ============================================================
# 17. --validate on empty directory — reports MISSING
# ============================================================
T_EMPTY="$(mktemp_tracked)"
mkdir -p "$T_EMPTY"
EMPTY_VAL="$(bash "$ROOT/scripts/bootstrap-project.sh" --target "$T_EMPTY" --validate 2>&1)"
[[ "$EMPTY_VAL" == *"MISSING"* ]] && assert_pass || assert_fail "validate-empty: should report MISSING"

# ============================================================
# 18. Input safety — reject invalid module names
# ============================================================
if bash "$ROOT/scripts/bootstrap-project.sh" --target "$T" --seed-module "INVALID NAME!" 2>/dev/null; then
  assert_fail "should reject invalid module name with spaces and !"
else
  assert_pass
fi

# 123abc is valid — [a-z0-9] allows digits as first char
T_DIGIT="$(mktemp_tracked)"
bash "$ROOT/scripts/bootstrap-project.sh" --target "$T_DIGIT" --platform claude --seed-module "123abc" >/dev/null
test -f "$T_DIGIT/docs/agents/modules/123abc/MODULE_CONTRACT.md" && assert_pass || assert_fail "digit-start module name should be valid"

if bash "$ROOT/scripts/bootstrap-project.sh" --target "$T" --seed-module "My-Module" 2>/dev/null; then
  assert_fail "should reject uppercase module name"
else
  assert_pass
fi

if bash "$ROOT/scripts/bootstrap-project.sh" --target "$T" --seed-module "-bad" 2>/dev/null; then
  assert_fail "should reject module name starting with hyphen"
else
  assert_pass
fi

# Valid names should succeed
T_VALID="$(mktemp_tracked)"
bash "$ROOT/scripts/bootstrap-project.sh" --target "$T_VALID" --platform claude --seed-module "auth-service" >/dev/null
test -f "$T_VALID/docs/agents/modules/auth-service/MODULE_CONTRACT.md" && assert_pass || assert_fail "valid module name 'auth-service' rejected"

T_VALID2="$(mktemp_tracked)"
bash "$ROOT/scripts/bootstrap-project.sh" --target "$T_VALID2" --platform claude --seed-module "api_v2" >/dev/null
test -f "$T_VALID2/docs/agents/modules/api_v2/MODULE_CONTRACT.md" && assert_pass || assert_fail "valid module name 'api_v2' rejected"

# ============================================================
# 19. Input safety — reject dangerous targets
# ============================================================
if bash "$ROOT/scripts/bootstrap-project.sh" --target "/" 2>/dev/null; then
  assert_fail "should reject / as target"
else
  assert_pass
fi

if bash "$ROOT/scripts/bootstrap-project.sh" --target "$HOME" 2>/dev/null; then
  assert_fail "should reject HOME as target"
else
  assert_pass
fi

# ============================================================
# 20. Template source integrity — all templates have frontmatter
# ============================================================
while IFS= read -r -d '' tmpl; do
  if head -1 "$tmpl" | grep -q "^---$" && head -5 "$tmpl" | grep -q "^artifact_type:"; then
    assert_pass
  else
    assert_fail "source template missing frontmatter: $tmpl"
  fi
done < <(find "$ROOT/docs/templates" -name "*.template.md" -print0)

# ============================================================
# 21. Example repo integrity — all example files exist and have content
# ============================================================
EXAMPLE_DIR="$ROOT/docs/examples/minimal-governed-repo"
for f in \
  "$EXAMPLE_DIR/README.md" \
  "$EXAMPLE_DIR/system/SYSTEM_GOAL_PACK.md" \
  "$EXAMPLE_DIR/system/SYSTEM_INVARIANTS.md" \
  "$EXAMPLE_DIR/system/SYSTEM_AUTHORITY_MAP.md" \
  "$EXAMPLE_DIR/modules/api-service/MODULE_CONTRACT.md"; do
  if [[ -f "$f" ]] && [[ -s "$f" ]]; then
    assert_pass
  else
    assert_fail "example file missing or empty: $f"
  fi
done

# Example MODULE_CONTRACT should have the 10-section structure
EXAMPLE_MC="$EXAMPLE_DIR/modules/api-service/MODULE_CONTRACT.md"
if grep -qF "## 1. Responsibility" "$EXAMPLE_MC" && grep -qF "## 10. Verification Expectations" "$EXAMPLE_MC"; then
  assert_pass
else
  assert_fail "example MODULE_CONTRACT missing 10-section structure"
fi

# Example files should have status: active (not proposed)
if grep -q "^status: active" "$EXAMPLE_DIR/system/SYSTEM_GOAL_PACK.md"; then
  assert_pass
else
  assert_fail "example SYSTEM_GOAL_PACK should have status: active"
fi

# ============================================================
# 22a. PROJECT_BASELINE created as first artifact
# ============================================================
test -f "$T/docs/agents/PROJECT_BASELINE.md" && assert_pass || assert_fail "PROJECT_BASELINE not created"
if head -1 "$T/docs/agents/PROJECT_BASELINE.md" | grep -q "^---$" && head -5 "$T/docs/agents/PROJECT_BASELINE.md" | grep -q "^artifact_type:"; then
  assert_pass
else
  assert_fail "PROJECT_BASELINE missing frontmatter"
fi

# ============================================================
# 22b. New verification artifacts created
# ============================================================
test -f "$T/docs/agents/verification/FEEDBACK_LOG.md" && assert_pass || assert_fail "FEEDBACK_LOG not created"
test -f "$T/docs/agents/verification/CRITERIA_EVOLUTION.md" && assert_pass || assert_fail "CRITERIA_EVOLUTION not created"

# ============================================================
# 22c. Optimization artifacts and test scenarios created
# ============================================================
test -f "$T/docs/agents/optimization/OPTIMIZATION_LOG.md" && assert_pass || assert_fail "OPTIMIZATION_LOG not created"
test -d "$T/docs/agents/optimization/test-scenarios" && assert_pass || assert_fail "test-scenarios dir missing"
test -f "$T/docs/agents/optimization/test-scenarios/seed-bug.json" && assert_pass || assert_fail "seed-bug.json missing"
test -f "$T/docs/agents/optimization/test-scenarios/seed-feature.json" && assert_pass || assert_fail "seed-feature.json missing"
test -f "$T/docs/agents/optimization/test-scenarios/seed-design.json" && assert_pass || assert_fail "seed-design.json missing"
test -f "$T/docs/agents/optimization/test-scenarios/seed-audit.json" && assert_pass || assert_fail "seed-audit.json missing"

# ============================================================
# 22c1. Phase 4 feedback analysis and conflict detection
# ============================================================
test -f "$T/docs/agents/verification/FEEDBACK_ANALYSIS_PROTOCOL.md" && assert_pass || assert_fail "FEEDBACK_ANALYSIS_PROTOCOL not created"
test -f "$T/docs/agents/system/AUTHORITY_CONFLICT_DETECTOR.md" && assert_pass || assert_fail "AUTHORITY_CONFLICT_DETECTOR not created"

# ============================================================
# 22c2. Phase 3 optimization protocols created
# ============================================================
test -f "$T/docs/agents/optimization/PROMPT_TUNING_PROTOCOL.md" && assert_pass || assert_fail "PROMPT_TUNING_PROTOCOL not created"
test -f "$T/docs/agents/optimization/ROLLBACK_GUARD.md" && assert_pass || assert_fail "ROLLBACK_GUARD not created"
test -f "$T/docs/agents/optimization/REGRESSION_CASES.md" && assert_pass || assert_fail "REGRESSION_CASES not created"

# ============================================================
# 22d. Execution directory and template created
# ============================================================
test -d "$T/docs/agents/execution/completed" && assert_pass || assert_fail "execution/completed dir missing"
test -f "$T/docs/agents/execution/GOVERNANCE_PROGRESS.template.md" && assert_pass || assert_fail "GOVERNANCE_PROGRESS template missing"
test -f "$T/docs/agents/execution/CURRENT_DIRECTION.md" && assert_pass || assert_fail "CURRENT_DIRECTION missing"

# ============================================================
# 22e. Optimization backups directory created
# ============================================================
test -d "$T/docs/agents/optimization/backups" && assert_pass || assert_fail "optimization/backups dir missing"

# ============================================================
# 22f. Example repo has PROJECT_BASELINE
# ============================================================
test -f "$ROOT/docs/examples/minimal-governed-repo/PROJECT_BASELINE.md" && assert_pass || assert_fail "example PROJECT_BASELINE missing"
if grep -q "^status: active" "$ROOT/docs/examples/minimal-governed-repo/PROJECT_BASELINE.md"; then
  assert_pass
else
  assert_fail "example PROJECT_BASELINE should have status: active"
fi

# ============================================================
# 22g. Derived documents have derivation metadata
# ============================================================
if head -15 "$T/docs/agents/system/SYSTEM_GOAL_PACK.md" | grep -q "derived_from_baseline_version"; then
  assert_pass
else
  assert_fail "SYSTEM_GOAL_PACK missing derived_from_baseline_version"
fi
if head -15 "$T/docs/agents/system/SYSTEM_INVARIANTS.md" | grep -q "derived_from_baseline_version"; then
  assert_pass
else
  assert_fail "SYSTEM_INVARIANTS missing derived_from_baseline_version"
fi

# ============================================================
# 22h. SYSTEM_AUTHORITY_MAP has Tier 0 and Tier 0.5
# ============================================================
if grep -q "Tier 0" "$T/docs/agents/system/SYSTEM_AUTHORITY_MAP.md"; then
  assert_pass
else
  assert_fail "SYSTEM_AUTHORITY_MAP missing Tier 0"
fi
if grep -q "Tier 0.5" "$T/docs/agents/system/SYSTEM_AUTHORITY_MAP.md"; then
  assert_pass
else
  assert_fail "SYSTEM_AUTHORITY_MAP missing Tier 0.5"
fi
if grep -q "BASELINE_INTERPRETATION_LOG" "$T/docs/agents/system/SYSTEM_AUTHORITY_MAP.md"; then
  assert_pass
else
  assert_fail "SYSTEM_AUTHORITY_MAP missing BASELINE_INTERPRETATION_LOG reference"
fi

# ============================================================
# 22h2. BASELINE_INTERPRETATION_LOG has authority_tier 0.5
# ============================================================
BIL="$T/docs/agents/system/BASELINE_INTERPRETATION_LOG.md"
if head -15 "$BIL" | grep -q "authority_tier:.*0.5"; then
  assert_pass
else
  assert_fail "BASELINE_INTERPRETATION_LOG missing authority_tier: 0.5"
fi
if head -15 "$BIL" | grep -q "owner_role:.*system-architect"; then
  assert_pass
else
  assert_fail "BASELINE_INTERPRETATION_LOG missing owner_role: system-architect"
fi

# ============================================================
# 22h3. CURRENT_DIRECTION has execution-context frontmatter
# ============================================================
CD="$T/docs/agents/execution/CURRENT_DIRECTION.md"
if head -1 "$CD" | grep -q "^---$" && head -5 "$CD" | grep -q "^artifact_type:"; then
  assert_pass
else
  assert_fail "CURRENT_DIRECTION missing frontmatter"
fi

# ============================================================
# 22i. ROUTING_POLICY references PROJECT_BASELINE
# ============================================================
if grep -q "PROJECT_BASELINE" "$T/docs/agents/system/ROUTING_POLICY.md"; then
  assert_pass
else
  assert_fail "ROUTING_POLICY missing PROJECT_BASELINE reference"
fi

# ============================================================
# 22j. Validate mode checks PROJECT_BASELINE
# ============================================================
VAL_BASELINE="$(bash "$ROOT/scripts/bootstrap-project.sh" --target "$T_VAL" --validate 2>&1)"
if [[ "$VAL_BASELINE" == *"PROJECT_BASELINE"* ]]; then
  assert_pass
else
  assert_fail "validate should check PROJECT_BASELINE"
fi

# ============================================================
# 22j2. Validate mode checks BASELINE_INTERPRETATION_LOG
# ============================================================
if [[ "$VAL_BASELINE" == *"BASELINE_INTERPRETATION_LOG"* ]]; then
  assert_pass
else
  assert_fail "validate should check BASELINE_INTERPRETATION_LOG"
fi

# ============================================================
# 22k. Validate mode checks optimization infrastructure fully
# ============================================================
if [[ "$VAL_BASELINE" == *"REGRESSION_CASES"* ]]; then
  assert_pass
else
  assert_fail "validate should check REGRESSION_CASES"
fi
if [[ "$VAL_BASELINE" == *"PROMPT_TUNING_PROTOCOL"* ]]; then
  assert_pass
else
  assert_fail "validate should check PROMPT_TUNING_PROTOCOL"
fi
if [[ "$VAL_BASELINE" == *"ROLLBACK_GUARD"* ]]; then
  assert_pass
else
  assert_fail "validate should check ROLLBACK_GUARD"
fi
if [[ "$VAL_BASELINE" == *"FEEDBACK_ANALYSIS_PROTOCOL"* ]]; then
  assert_pass
else
  assert_fail "validate should check FEEDBACK_ANALYSIS_PROTOCOL"
fi
if [[ "$VAL_BASELINE" == *"AUTHORITY_CONFLICT_DETECTOR"* ]]; then
  assert_pass
else
  assert_fail "validate should check AUTHORITY_CONFLICT_DETECTOR"
fi

# ============================================================
# 22. CLAUDE.md references ROUTING_POLICY
# ============================================================
if grep -q "ROUTING_POLICY" "$ROOT/CLAUDE.md"; then
  assert_pass
else
  assert_fail "CLAUDE.md should reference ROUTING_POLICY"
fi

# ============================================================
# 23. Skills integrity — all 7 skill files exist
# ============================================================
for skill in system-architect module-architect debug implementation verification frontend-specialist autoresearch; do
  if [[ -f "$ROOT/.claude/skills/$skill/SKILL.md" ]]; then
    assert_pass
  else
    assert_fail "skill missing: $skill"
  fi
done

# ============================================================
# 23b. Skills — all 7 have When NOT to Activate and Produces sections
# ============================================================
for skill in system-architect module-architect debug implementation verification frontend-specialist autoresearch; do
  SKILL_FILE="$ROOT/.claude/skills/$skill/SKILL.md"
  if grep -q "When NOT to Activate" "$SKILL_FILE"; then
    assert_pass
  else
    assert_fail "skill $skill missing 'When NOT to Activate'"
  fi
  if grep -q "Produces" "$SKILL_FILE"; then
    assert_pass
  else
    assert_fail "skill $skill missing 'Produces'"
  fi
done

# ============================================================
# 23c. System Architect loads PROJECT_BASELINE in HARD-GATE
# ============================================================
if grep -q "PROJECT_BASELINE" "$ROOT/.claude/skills/system-architect/SKILL.md"; then
  assert_pass
else
  assert_fail "system-architect SKILL.md missing PROJECT_BASELINE"
fi

# ============================================================
# 23d. Downstream skills do NOT load PROJECT_BASELINE directly
# ============================================================
for skill in module-architect debug implementation verification; do
  if grep -q "do NOT load PROJECT_BASELINE directly" "$ROOT/.claude/skills/$skill/SKILL.md"; then
    assert_pass
  else
    assert_fail "skill $skill should state 'do NOT load PROJECT_BASELINE directly'"
  fi
done

# ============================================================
# 24. Commands integrity — all 5 command files exist
# ============================================================
for cmd in bug impl audit verify autoresearch; do
  if [[ -f "$ROOT/.claude/commands/$cmd.md" ]]; then
    assert_pass
  else
    assert_fail "command missing: $cmd"
  fi
done

# ============================================================
# Results
# ============================================================
echo ""
echo "Results: $PASS passed, $FAIL failed"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
echo "PASS"
