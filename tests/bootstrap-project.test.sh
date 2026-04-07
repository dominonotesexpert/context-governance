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
# 23e. Business semantics boundary in downstream templates
# ============================================================
# SYSTEM_GOAL_PACK must reference BASELINE_INTERPRETATION_LOG as upstream source
SGP_TMPL="$ROOT/docs/templates/system/SYSTEM_GOAL_PACK.template.md"
if grep -q "BASELINE_INTERPRETATION_LOG" "$SGP_TMPL"; then
  assert_pass
else
  assert_fail "SYSTEM_GOAL_PACK template missing BASELINE_INTERPRETATION_LOG reference"
fi

# SYSTEM_INVARIANTS must allow BASELINE_INTERPRETATION_LOG as upstream source
SI_TMPL="$ROOT/docs/templates/system/SYSTEM_INVARIANTS.template.md"
if grep -q "BASELINE_INTERPRETATION_LOG" "$SI_TMPL"; then
  assert_pass
else
  assert_fail "SYSTEM_INVARIANTS template missing BASELINE_INTERPRETATION_LOG reference"
fi

# MODULE_CONTRACT must have business_semantics_impact field
MC_TMPL="$ROOT/docs/templates/modules/MODULE_CONTRACT.template.md"
if grep -q "business_semantics_impact" "$MC_TMPL"; then
  assert_pass
else
  assert_fail "MODULE_CONTRACT template missing business_semantics_impact"
fi

# ACCEPTANCE_RULES must have business/technical split
AR_TMPL="$ROOT/docs/templates/verification/ACCEPTANCE_RULES.template.md"
if grep -qi "Business Acceptance Semantics" "$AR_TMPL"; then
  assert_pass
else
  assert_fail "ACCEPTANCE_RULES template missing Business Acceptance Semantics section"
fi
if grep -qi "Technical Verification Gates" "$AR_TMPL"; then
  assert_pass
else
  assert_fail "ACCEPTANCE_RULES template missing Technical Verification Gates section"
fi

# VERIFICATION_ORACLE must acknowledge the business/technical distinction
VO_TMPL="$ROOT/docs/templates/verification/VERIFICATION_ORACLE.template.md"
if grep -qi "business" "$VO_TMPL"; then
  assert_pass
else
  assert_fail "VERIFICATION_ORACLE template missing business-semantics awareness"
fi

# ROUTING_POLICY must mention business-semantic confirmation boundary
RP_TMPL="$ROOT/docs/templates/system/ROUTING_POLICY.template.md"
if grep -qi "business.semantic" "$RP_TMPL"; then
  assert_pass
else
  assert_fail "ROUTING_POLICY template missing business-semantic confirmation boundary"
fi

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
# 25. ACCEPTANCE_RULES template — external validation signals
# ============================================================
AR_TMPL="$ROOT/docs/templates/verification/ACCEPTANCE_RULES.template.md"
if grep -qF "External Validation Signals" "$AR_TMPL"; then
  assert_pass
else
  assert_fail "ACCEPTANCE_RULES template missing 'External Validation Signals'"
fi
if grep -qF "user-feedback" "$AR_TMPL"; then
  assert_pass
else
  assert_fail "ACCEPTANCE_RULES template missing 'user-feedback' signal type"
fi
if grep -qF "FEEDBACK_LOG" "$AR_TMPL"; then
  assert_pass
else
  assert_fail "ACCEPTANCE_RULES template missing FEEDBACK_LOG reference"
fi

# ============================================================
# 26. FEEDBACK_LOG template — periodic review checkpoint
# ============================================================
FL_TMPL="$ROOT/docs/templates/verification/FEEDBACK_LOG.template.md"
if grep -qF "Periodic Business Alignment Review" "$FL_TMPL"; then
  assert_pass
else
  assert_fail "FEEDBACK_LOG template missing 'Periodic Business Alignment Review'"
fi
if grep -qF "Review Protocol" "$FL_TMPL"; then
  assert_pass
else
  assert_fail "FEEDBACK_LOG template missing 'Review Protocol'"
fi

# ============================================================
# 27. Engineering Constraints (Tier 1.5)
# ============================================================
EC_TMPL="$ROOT/docs/templates/system/ENGINEERING_CONSTRAINTS.template.md"
if [[ -f "$EC_TMPL" ]]; then
  assert_pass
else
  assert_fail "ENGINEERING_CONSTRAINTS template missing"
fi
if grep -q "authority_tier: 1.5" "$EC_TMPL" 2>/dev/null; then
  assert_pass
else
  assert_fail "ENGINEERING_CONSTRAINTS template missing authority_tier: 1.5"
fi
if grep -q "owner_role: system-architect" "$EC_TMPL" 2>/dev/null; then
  assert_pass
else
  assert_fail "ENGINEERING_CONSTRAINTS template missing owner_role: system-architect"
fi
MC_TMPL="$ROOT/docs/templates/modules/MODULE_CONTRACT.template.md"
if grep -qF "ENGINEERING_CONSTRAINTS" "$MC_TMPL"; then
  assert_pass
else
  assert_fail "MODULE_CONTRACT template missing ENGINEERING_CONSTRAINTS reference"
fi
SAM_TMPL="$ROOT/docs/templates/system/SYSTEM_AUTHORITY_MAP.template.md"
if grep -qi "Tier 1.5" "$SAM_TMPL"; then
  assert_pass
else
  assert_fail "SYSTEM_AUTHORITY_MAP template missing Tier 1.5"
fi

# ============================================================
# 28. Derivation fingerprinting
# ============================================================
DR_TMPL="$ROOT/docs/templates/system/DERIVATION_REGISTRY.template.md"
if [[ -f "$DR_TMPL" ]]; then
  assert_pass
else
  assert_fail "DERIVATION_REGISTRY template missing"
fi
if grep -q "artifact_type: derivation-registry" "$DR_TMPL" 2>/dev/null; then
  assert_pass
else
  assert_fail "DERIVATION_REGISTRY template missing artifact_type: derivation-registry"
fi

# Check derivation_context in all 5 derived-document templates
for tmpl_file in \
  "$ROOT/docs/templates/system/SYSTEM_GOAL_PACK.template.md" \
  "$ROOT/docs/templates/system/SYSTEM_INVARIANTS.template.md" \
  "$ROOT/docs/templates/modules/MODULE_CONTRACT.template.md" \
  "$ROOT/docs/templates/verification/ACCEPTANCE_RULES.template.md" \
  "$ROOT/docs/templates/verification/VERIFICATION_ORACLE.template.md"; do
  tmpl_name=$(basename "$tmpl_file")
  if grep -q "derivation_context:" "$tmpl_file" 2>/dev/null; then
    assert_pass
  else
    assert_fail "$tmpl_name missing derivation_context in frontmatter"
  fi
done

# Check ROUTING_POLICY has staleness rules
RP_TMPL="$ROOT/docs/templates/system/ROUTING_POLICY.template.md"
if grep -qF "Derivation Staleness" "$RP_TMPL"; then
  assert_pass
else
  assert_fail "ROUTING_POLICY template missing Derivation Staleness section"
fi

# Check bootstrap creates ENGINEERING_CONSTRAINTS and DERIVATION_REGISTRY
BS_SCRIPT="$ROOT/scripts/bootstrap-project.sh"
if grep -qF "ENGINEERING_CONSTRAINTS" "$BS_SCRIPT"; then
  assert_pass
else
  assert_fail "bootstrap script missing ENGINEERING_CONSTRAINTS"
fi
if grep -qF "DERIVATION_REGISTRY" "$BS_SCRIPT"; then
  assert_pass
else
  assert_fail "bootstrap script missing DERIVATION_REGISTRY"
fi

# ============================================================
# 29. Governance Modes
# ============================================================
GM_TMPL="$ROOT/docs/templates/execution/GOVERNANCE_MODE.template.md"
if [[ -f "$GM_TMPL" ]]; then
  assert_pass
else
  assert_fail "GOVERNANCE_MODE template missing"
fi
if grep -q "current_mode: steady-state" "$GM_TMPL" 2>/dev/null; then
  assert_pass
else
  assert_fail "GOVERNANCE_MODE template missing default steady-state mode"
fi
if grep -q "artifact_type: governance-mode" "$GM_TMPL" 2>/dev/null; then
  assert_pass
else
  assert_fail "GOVERNANCE_MODE template missing artifact_type: governance-mode"
fi

MTL_TMPL="$ROOT/docs/templates/execution/MODE_TRANSITION_LOG.template.md"
if [[ -f "$MTL_TMPL" ]]; then
  assert_pass
else
  assert_fail "MODE_TRANSITION_LOG template missing"
fi
if grep -q "artifact_type: mode-transition-log" "$MTL_TMPL" 2>/dev/null; then
  assert_pass
else
  assert_fail "MODE_TRANSITION_LOG template missing artifact_type"
fi

# Mode expiry HARD-GATE in ROUTING_POLICY
RP_TMPL="$ROOT/docs/templates/system/ROUTING_POLICY.template.md"
if grep -qF "Mode Expiry Check" "$RP_TMPL"; then
  assert_pass
else
  assert_fail "ROUTING_POLICY missing Mode Expiry Check HARD-GATE"
fi
if grep -qF "Governance Mode Effects" "$RP_TMPL"; then
  assert_pass
else
  assert_fail "ROUTING_POLICY missing Governance Mode Effects section"
fi

# blocked state in BOOTSTRAP_READINESS
BR_TMPL="$ROOT/docs/templates/BOOTSTRAP_READINESS.template.md"
if grep -qF "blocked" "$BR_TMPL"; then
  assert_pass
else
  assert_fail "BOOTSTRAP_READINESS missing blocked state"
fi

# Mode-aware gates in ACCEPTANCE_RULES
AR_TMPL="$ROOT/docs/templates/verification/ACCEPTANCE_RULES.template.md"
if grep -qF "Mode-Aware Verification Gates" "$AR_TMPL"; then
  assert_pass
else
  assert_fail "ACCEPTANCE_RULES missing Mode-Aware Verification Gates"
fi

# Bootstrap creates governance mode files
BS_SCRIPT="$ROOT/scripts/bootstrap-project.sh"
if grep -qF "GOVERNANCE_MODE" "$BS_SCRIPT"; then
  assert_pass
else
  assert_fail "bootstrap script missing GOVERNANCE_MODE"
fi
if grep -qF "MODE_TRANSITION_LOG" "$BS_SCRIPT"; then
  assert_pass
else
  assert_fail "bootstrap script missing MODE_TRANSITION_LOG"
fi

# System Architect skill loads GOVERNANCE_MODE
SA_SKILL="$ROOT/.claude/skills/system-architect/SKILL.md"
if grep -qF "GOVERNANCE_MODE" "$SA_SKILL"; then
  assert_pass
else
  assert_fail "System Architect skill missing GOVERNANCE_MODE in loading list"
fi

# ============================================================
# 30. Tier 0.8 architecture baseline
# ============================================================
test -f "$ROOT/docs/templates/PROJECT_ARCHITECTURE_BASELINE.template.md" && assert_pass || assert_fail "PROJECT_ARCHITECTURE_BASELINE template missing"
if head -5 "$ROOT/docs/templates/PROJECT_ARCHITECTURE_BASELINE.template.md" | grep -q "^artifact_type: project-architecture-baseline"; then
  assert_pass
else
  assert_fail "PROJECT_ARCHITECTURE_BASELINE missing artifact_type: project-architecture-baseline"
fi
if head -10 "$ROOT/docs/templates/PROJECT_ARCHITECTURE_BASELINE.template.md" | grep -q "^owner_role: user"; then
  assert_pass
else
  assert_fail "PROJECT_ARCHITECTURE_BASELINE missing owner_role: user"
fi
if head -10 "$ROOT/docs/templates/PROJECT_ARCHITECTURE_BASELINE.template.md" | grep -q "^authority_tier: 0.8"; then
  assert_pass
else
  assert_fail "PROJECT_ARCHITECTURE_BASELINE missing authority_tier: 0.8"
fi
# Bootstrap script references PROJECT_ARCHITECTURE_BASELINE
if grep -q "PROJECT_ARCHITECTURE_BASELINE" "$ROOT/scripts/bootstrap-project.sh"; then
  assert_pass
else
  assert_fail "bootstrap script does not reference PROJECT_ARCHITECTURE_BASELINE"
fi

# ============================================================
# 31. Tier 2 derived architecture
# ============================================================
test -f "$ROOT/docs/templates/system/SYSTEM_ARCHITECTURE.template.md" && assert_pass || assert_fail "SYSTEM_ARCHITECTURE template missing"
if head -5 "$ROOT/docs/templates/system/SYSTEM_ARCHITECTURE.template.md" | grep -q "^artifact_type: system-architecture"; then
  assert_pass
else
  assert_fail "SYSTEM_ARCHITECTURE missing artifact_type: system-architecture"
fi
if head -15 "$ROOT/docs/templates/system/SYSTEM_ARCHITECTURE.template.md" | grep -q "derived_from_baseline_version"; then
  assert_pass
else
  assert_fail "SYSTEM_ARCHITECTURE missing derived_from_baseline_version"
fi
if head -15 "$ROOT/docs/templates/system/SYSTEM_ARCHITECTURE.template.md" | grep -q "derived_from_architecture_baseline_version"; then
  assert_pass
else
  assert_fail "SYSTEM_ARCHITECTURE missing derived_from_architecture_baseline_version"
fi
if head -20 "$ROOT/docs/templates/system/SYSTEM_ARCHITECTURE.template.md" | grep -q "derivation_context"; then
  assert_pass
else
  assert_fail "SYSTEM_ARCHITECTURE missing derivation_context"
fi

# ============================================================
# 32. Architecture change proposal
# ============================================================
test -f "$ROOT/docs/templates/system/ARCHITECTURE_CHANGE_PROPOSAL.template.md" && assert_pass || assert_fail "ARCHITECTURE_CHANGE_PROPOSAL template missing"
if head -5 "$ROOT/docs/templates/system/ARCHITECTURE_CHANGE_PROPOSAL.template.md" | grep -q "^artifact_type: architecture-change-proposal"; then
  assert_pass
else
  assert_fail "ARCHITECTURE_CHANGE_PROPOSAL missing artifact_type: architecture-change-proposal"
fi
# Bootstrap script references ARCHITECTURE_CHANGE_PROPOSAL
if grep -q "ARCHITECTURE_CHANGE_PROPOSAL" "$ROOT/scripts/bootstrap-project.sh"; then
  assert_pass
else
  assert_fail "bootstrap script does not reference ARCHITECTURE_CHANGE_PROPOSAL"
fi

# ============================================================
# 33. Authority map wiring
# ============================================================
if grep -q "Tier 0.8" "$ROOT/docs/templates/system/SYSTEM_AUTHORITY_MAP.template.md"; then
  assert_pass
else
  assert_fail "SYSTEM_AUTHORITY_MAP template missing Tier 0.8"
fi
if grep -q "SYSTEM_ARCHITECTURE" "$ROOT/docs/templates/system/SYSTEM_AUTHORITY_MAP.template.md"; then
  assert_pass
else
  assert_fail "SYSTEM_AUTHORITY_MAP template missing SYSTEM_ARCHITECTURE"
fi

# ============================================================
# 36. Downstream templates reference SYSTEM_ARCHITECTURE
# ============================================================
MC_TMPL="$ROOT/docs/templates/modules/MODULE_CONTRACT.template.md"
if grep -qF "SYSTEM_ARCHITECTURE" "$MC_TMPL"; then
  assert_pass
else
  assert_fail "MODULE_CONTRACT template missing SYSTEM_ARCHITECTURE reference"
fi

MT_TMPL="$ROOT/docs/templates/system/MODULE_TAXONOMY.template.md"
if grep -qi "architecture" "$MT_TMPL"; then
  assert_pass
else
  assert_fail "MODULE_TAXONOMY template missing architecture reference"
fi

AR_TMPL="$ROOT/docs/templates/verification/ACCEPTANCE_RULES.template.md"
if grep -qi "architectural conformance" "$AR_TMPL"; then
  assert_pass
else
  assert_fail "ACCEPTANCE_RULES template missing architectural conformance"
fi

VO_TMPL="$ROOT/docs/templates/verification/VERIFICATION_ORACLE.template.md"
if grep -qi "architecture" "$VO_TMPL"; then
  assert_pass
else
  assert_fail "VERIFICATION_ORACLE template missing architecture reference"
fi

# ============================================================
# 37. Canonical workflow/dataflow templates reference architecture
# ============================================================
CW_TMPL="$ROOT/docs/templates/modules/MODULE_CANONICAL_WORKFLOW.template.md"
if grep -qi "SYSTEM_ARCHITECTURE\|architecture baseline" "$CW_TMPL"; then
  assert_pass
else
  assert_fail "MODULE_CANONICAL_WORKFLOW template missing architecture reference"
fi

CD_TMPL="$ROOT/docs/templates/modules/MODULE_CANONICAL_DATAFLOW.template.md"
if grep -qi "SYSTEM_ARCHITECTURE\|architecture baseline" "$CD_TMPL"; then
  assert_pass
else
  assert_fail "MODULE_CANONICAL_DATAFLOW template missing architecture reference"
fi

# ============================================================
# 34. Architecture baseline size validation — exists in bootstrap
# ============================================================
if grep -q "PROJECT_ARCHITECTURE_BASELINE" "$ROOT/scripts/bootstrap-project.sh"; then
  assert_pass
else
  assert_fail "bootstrap script missing PROJECT_ARCHITECTURE_BASELINE validation"
fi

# ============================================================
# 35. Architecture baseline size limits are enforced
# ============================================================
if grep -q "body.*line" "$ROOT/scripts/bootstrap-project.sh" || grep -q "Mermaid" "$ROOT/scripts/bootstrap-project.sh"; then
  assert_pass
else
  assert_fail "bootstrap script missing architecture baseline size limit enforcement"
fi

# ============================================================
# 38. check-hardgate.sh — script exists and is invocable
# ============================================================
if [[ -f "$ROOT/scripts/check-hardgate.sh" ]] && bash "$ROOT/scripts/check-hardgate.sh" -h >/dev/null 2>&1; then
  assert_pass
else
  assert_fail "check-hardgate.sh missing or not invocable"
fi

# ============================================================
# 38b. check-hardgate.sh — passes for fully bootstrapped project (debug role)
# ============================================================
T_HG="$(mktemp_tracked)"
bash "$ROOT/scripts/bootstrap-project.sh" --target "$T_HG" --platform claude --seed-module billing >/dev/null
if bash "$ROOT/scripts/check-hardgate.sh" --role debug --target "$T_HG" >/dev/null 2>&1; then
  assert_pass
else
  assert_fail "check-hardgate should pass for bootstrapped project with debug role"
fi

# ============================================================
# 38c. check-hardgate.sh — fails for empty directory (debug role), output contains MISSING
# ============================================================
T_HG_EMPTY="$(mktemp_tracked)"
mkdir -p "$T_HG_EMPTY"
HG_EMPTY_OUTPUT="$(bash "$ROOT/scripts/check-hardgate.sh" --role debug --target "$T_HG_EMPTY" 2>&1 || true)"
if [[ "$HG_EMPTY_OUTPUT" == *"MISSING"* ]]; then
  assert_pass
else
  assert_fail "check-hardgate should report MISSING for empty directory"
fi

# ============================================================
# 38d. check-hardgate.sh — passes for system-architect role on bootstrapped project
# ============================================================
if bash "$ROOT/scripts/check-hardgate.sh" --role system-architect --target "$T_HG" >/dev/null 2>&1; then
  assert_pass
else
  assert_fail "check-hardgate should pass for bootstrapped project with system-architect role"
fi

# ============================================================
# 38e. check-hardgate.sh — rejects unknown role (exit code 2)
# ============================================================
HG_UNKNOWN_EXIT=0
bash "$ROOT/scripts/check-hardgate.sh" --role unknown-role --target "$T_HG" >/dev/null 2>&1 || HG_UNKNOWN_EXIT=$?
if [[ "$HG_UNKNOWN_EXIT" -eq 2 ]]; then
  assert_pass
else
  assert_fail "check-hardgate should exit 2 for unknown role (got $HG_UNKNOWN_EXIT)"
fi

# ============================================================
# 38f. All 4 Bootstrap Pack templates have required_files in frontmatter
# ============================================================
for bp_tmpl in \
  "$ROOT/docs/templates/debug/DEBUG_BOOTSTRAP_PACK.template.md" \
  "$ROOT/docs/templates/system/SYSTEM_BOOTSTRAP_PACK.template.md" \
  "$ROOT/docs/templates/modules/MODULE_BOOTSTRAP_PACK.template.md" \
  "$ROOT/docs/templates/verification/VERIFICATION_BOOTSTRAP_PACK.template.md"; do
  if head -20 "$bp_tmpl" | grep -q "^required_files:"; then
    assert_pass
  else
    assert_fail "Bootstrap Pack template missing required_files: $(basename "$bp_tmpl")"
  fi
done

# ============================================================
# 38g. check-hardgate.sh — --module flag adds MODULE_CONTRACT check
# ============================================================
HG_MODULE_OUTPUT="$(bash "$ROOT/scripts/check-hardgate.sh" --role debug --target "$T_HG" --module billing 2>&1 || true)"
if [[ "$HG_MODULE_OUTPUT" == *"MODULE_CONTRACT"* ]]; then
  assert_pass
else
  assert_fail "check-hardgate --module should check MODULE_CONTRACT"
fi

# ============================================================
# 38h. check-hardgate.sh — shows help with -h flag
# ============================================================
HG_HELP_OUTPUT="$(bash "$ROOT/scripts/check-hardgate.sh" -h 2>&1)"
if [[ "$HG_HELP_OUTPUT" == *"Usage"* ]]; then
  assert_pass
else
  assert_fail "check-hardgate -h should show Usage"
fi

# ============================================================
# 39. Phase 3 enforcement scripts exist and are executable
# ============================================================
test -f "$ROOT/scripts/check-staleness.sh" && assert_pass || assert_fail "check-staleness.sh missing"
test -x "$ROOT/scripts/check-staleness.sh" && assert_pass || assert_fail "check-staleness.sh not executable"

test -f "$ROOT/scripts/check-derived-edits.sh" && assert_pass || assert_fail "check-derived-edits.sh missing"
test -x "$ROOT/scripts/check-derived-edits.sh" && assert_pass || assert_fail "check-derived-edits.sh not executable"

test -f "$ROOT/.githooks/pre-commit" && assert_pass || assert_fail ".githooks/pre-commit missing"
test -x "$ROOT/.githooks/pre-commit" && assert_pass || assert_fail ".githooks/pre-commit not executable"

# ============================================================
# 40. check-staleness.sh reports NO_HASH for fresh bootstrap
# ============================================================
T_STALE="$(mktemp_tracked)"
bash "$ROOT/scripts/bootstrap-project.sh" --target "$T_STALE" --platform claude >/dev/null
# Initialize git so hash-object works
git -C "$T_STALE" init >/dev/null 2>&1
STALE_OUTPUT="$(bash "$ROOT/scripts/check-staleness.sh" --target "$T_STALE" 2>&1)"
if [[ "$STALE_OUTPUT" == *"NO_HASH"* ]]; then
  assert_pass
else
  assert_fail "check-staleness should report NO_HASH for fresh bootstrap"
fi

# ============================================================
# 41. check-staleness.sh handles non-git directory gracefully
# ============================================================
T_NOGIT="$(mktemp_tracked)"
bash "$ROOT/scripts/bootstrap-project.sh" --target "$T_NOGIT" --platform claude >/dev/null
# Do NOT git init — test non-git behavior
NOGIT_OUTPUT="$(bash "$ROOT/scripts/check-staleness.sh" --target "$T_NOGIT" 2>&1)"
NOGIT_EXIT=$?
# Should not crash and should contain NO_GIT or NO_HASH
if [[ "$NOGIT_EXIT" -eq 0 ]] && { [[ "$NOGIT_OUTPUT" == *"NO_GIT"* ]] || [[ "$NOGIT_OUTPUT" == *"NO_HASH"* ]]; }; then
  assert_pass
else
  assert_fail "check-staleness should handle non-git directory gracefully"
fi

# ============================================================
# 42. All 6 derived templates have upstream_sources in frontmatter
# ============================================================
for tmpl_file in \
  "$ROOT/docs/templates/system/SYSTEM_GOAL_PACK.template.md" \
  "$ROOT/docs/templates/system/SYSTEM_INVARIANTS.template.md" \
  "$ROOT/docs/templates/system/SYSTEM_ARCHITECTURE.template.md" \
  "$ROOT/docs/templates/modules/MODULE_CONTRACT.template.md" \
  "$ROOT/docs/templates/verification/ACCEPTANCE_RULES.template.md" \
  "$ROOT/docs/templates/verification/VERIFICATION_ORACLE.template.md"; do
  tmpl_name=$(basename "$tmpl_file")
  if grep -q "upstream_sources:" "$tmpl_file" 2>/dev/null; then
    assert_pass
  else
    assert_fail "$tmpl_name missing upstream_sources in frontmatter"
  fi
done

# ============================================================
# 43. SYSTEM_ARCHITECTURE upstream_sources includes ENGINEERING_CONSTRAINTS
# ============================================================
SA_TMPL="$ROOT/docs/templates/system/SYSTEM_ARCHITECTURE.template.md"
if grep -A10 "upstream_sources:" "$SA_TMPL" | grep -q "ENGINEERING_CONSTRAINTS"; then
  assert_pass
else
  assert_fail "SYSTEM_ARCHITECTURE upstream_sources missing ENGINEERING_CONSTRAINTS"
fi

# ============================================================
# 44. MODULE_CONTRACT upstream_sources includes SYSTEM_ARCHITECTURE
# ============================================================
MC_TMPL="$ROOT/docs/templates/modules/MODULE_CONTRACT.template.md"
if grep -A10 "upstream_sources:" "$MC_TMPL" | grep -q "SYSTEM_ARCHITECTURE"; then
  assert_pass
else
  assert_fail "MODULE_CONTRACT upstream_sources missing SYSTEM_ARCHITECTURE"
fi

# ============================================================
# 50. DEBUG_CASE_TEMPLATE has Root Cause Level field with all 6 levels
# ============================================================
DCT="$ROOT/docs/templates/debug/DEBUG_CASE_TEMPLATE.template.md"
if grep -qF "Root Cause Level:" "$DCT"; then
  assert_pass
else
  assert_fail "DEBUG_CASE_TEMPLATE missing Root Cause Level field"
fi
for level in code module cross-module engineering-constraint architecture baseline; do
  if grep -q "$level" "$DCT"; then
    assert_pass
  else
    assert_fail "DEBUG_CASE_TEMPLATE missing level: $level"
  fi
done

# ============================================================
# 51. DEBUG_CASE_TEMPLATE has Root Cause Validation Gate with 4 items
# ============================================================
if grep -qF "Root Cause Validation Gate" "$DCT"; then
  assert_pass
else
  assert_fail "DEBUG_CASE_TEMPLATE missing Root Cause Validation Gate section"
fi
for gate_item in "Anti-falsification" "Prediction verified" "All symptoms explained" "Open gaps empty"; do
  if grep -qF "$gate_item" "$DCT"; then
    assert_pass
  else
    assert_fail "DEBUG_CASE_TEMPLATE Validation Gate missing: $gate_item"
  fi
done
# Verify user confirmation is NOT in the gate (it's a separate escalation)
if grep -A20 "Root Cause Validation Gate" "$DCT" | grep -qF "User confirmation is NOT part of this gate"; then
  assert_pass
else
  assert_fail "DEBUG_CASE_TEMPLATE Validation Gate should note user confirmation is separate"
fi

# ============================================================
# 52. Debug SKILL has new steps and level-based routing
# ============================================================
DS="$ROOT/.claude/skills/debug/SKILL.md"
if grep -qF "Upstream Boundary Check" "$DS"; then
  assert_pass
else
  assert_fail "Debug SKILL missing Upstream Boundary Check"
fi
if grep -qF "Prediction-Observation Validation" "$DS"; then
  assert_pass
else
  assert_fail "Debug SKILL missing Prediction-Observation Validation"
fi
if grep -qF "Business-Semantics Escalation Gate" "$DS"; then
  assert_pass
else
  assert_fail "Debug SKILL missing Business-Semantics Escalation Gate"
fi
# Level-based routing table with all 6 levels
for level in code module cross-module engineering-constraint architecture baseline; do
  if grep -q "\`$level\`" "$DS"; then
    assert_pass
  else
    assert_fail "Debug SKILL level-based routing missing: $level"
  fi
done

# ============================================================
# 53. Debug SKILL has Governance Mode Compatibility
# ============================================================
if grep -qF "Governance Mode Compatibility" "$DS"; then
  assert_pass
else
  assert_fail "Debug SKILL missing Governance Mode Compatibility section"
fi
if grep -q "incident.*DEFERRED\|DEFERRED.*incident" "$DS"; then
  assert_pass
else
  assert_fail "Debug SKILL Governance Mode should defer steps in incident mode"
fi

# ============================================================
# 54. ROUTING_POLICY has Level-Based Routing section with engineering-constraint
# ============================================================
RP="$ROOT/docs/templates/system/ROUTING_POLICY.template.md"
if grep -qF "Level-Based Routing" "$RP"; then
  assert_pass
else
  assert_fail "ROUTING_POLICY missing Level-Based Routing section"
fi
if grep -q "engineering-constraint" "$RP"; then
  assert_pass
else
  assert_fail "ROUTING_POLICY Level-Based Routing missing engineering-constraint"
fi

# ============================================================
# 55. CLAUDE.md has updated mandatory sequence with level classification
# ============================================================
if grep -q "root cause level\|Root Cause Level\|Classify root cause level" "$ROOT/CLAUDE.md"; then
  assert_pass
else
  assert_fail "CLAUDE.md mandatory sequence missing level classification"
fi
if grep -q "Escalation gate\|escalation gate" "$ROOT/CLAUDE.md"; then
  assert_pass
else
  assert_fail "CLAUDE.md mandatory sequence missing escalation gate"
fi
if grep -qF "1-8A" "$ROOT/CLAUDE.md"; then
  assert_pass
else
  assert_fail "CLAUDE.md should reference steps 1-8A"
fi

# ============================================================
# 56. debug-case-example has Root Cause Level and Validation Gate
# ============================================================
EX="$ROOT/docs/examples/debug-case-example.md"
if grep -qF "Root Cause Level:" "$EX"; then
  assert_pass
else
  assert_fail "debug-case-example missing Root Cause Level"
fi
if grep -qF "Root Cause Validation Gate" "$EX"; then
  assert_pass
else
  assert_fail "debug-case-example missing Validation Gate"
fi

# ============================================================
# 57. Implementation SKILL acknowledges level-based handoff
# ============================================================
IS="$ROOT/.claude/skills/implementation/SKILL.md"
if grep -q "code.*or.*module.*level handoff\|handoff from Debug" "$IS"; then
  assert_pass
else
  assert_fail "Implementation SKILL should mention level-based handoff from Debug"
fi
if grep -q "cross-module.*engineering-constraint.*architecture.*baseline" "$IS"; then
  assert_pass
else
  assert_fail "Implementation SKILL should list levels that require upstream roles first"
fi

# ============================================================
# 58. --validate output includes Staleness section
# ============================================================
T_VAL="$(mktemp_tracked)"
bash "$ROOT/scripts/bootstrap-project.sh" --target "$T_VAL" --platform claude >/dev/null
VAL_OUTPUT="$(timeout 60 bash "$ROOT/scripts/bootstrap-project.sh" --target "$T_VAL" --validate 2>&1)"
if echo "$VAL_OUTPUT" | grep -q "Derivation Staleness"; then
  assert_pass
else
  assert_fail "validate should include Staleness section"
fi

# ============================================================
# 59. --validate output includes Governance Mode section
# ============================================================
if echo "$VAL_OUTPUT" | grep -qi "Governance Mode"; then
  assert_pass
else
  assert_fail "validate should include Governance Mode section"
fi

# ============================================================
# 60. --validate output includes deterministic Verdict
# ============================================================
if echo "$VAL_OUTPUT" | grep -qE "Verdict:"; then
  assert_pass
else
  assert_fail "validate should include deterministic Verdict"
fi
if echo "$VAL_OUTPUT" | grep -qE "PASS|FAIL"; then
  assert_pass
else
  assert_fail "validate Verdict should be PASS or FAIL"
fi

# ============================================================
# 61. --validate detects expired governance mode
# ============================================================
T_EXP="$(mktemp_tracked)"
bash "$ROOT/scripts/bootstrap-project.sh" --target "$T_EXP" --platform claude >/dev/null
GM_FILE="$T_EXP/docs/agents/execution/GOVERNANCE_MODE.md"
if [[ -f "$GM_FILE" ]]; then
  sed -i.bak 's/current_mode:.*/current_mode: exploration/' "$GM_FILE"
  sed -i.bak 's/expiry_date:.*/expiry_date: "2020-01-01"/' "$GM_FILE"
  EXP_OUTPUT="$(timeout 60 bash "$ROOT/scripts/bootstrap-project.sh" --target "$T_EXP" --validate 2>&1)"
  if echo "$EXP_OUTPUT" | grep -q "EXPIRED"; then
    assert_pass
  else
    assert_fail "validate should detect expired governance mode"
  fi
else
  assert_fail "GOVERNANCE_MODE not created by bootstrap"
fi

# ============================================================
# 62. Architecture-level escalation mentions Tier 0.8
# ============================================================
if grep -q "Tier 0.8\|ARCHITECTURE_CHANGE_PROPOSAL" "$DS"; then
  assert_pass
else
  assert_fail "Debug SKILL architecture escalation should reference Tier 0.8"
fi

# ============================================================
# 63. Phase 1.5 — .governance/ directory is created
# ============================================================
test -d "$T/.governance" && assert_pass || assert_fail ".governance/ directory not created by bootstrap"

# ============================================================
# 64. Phase 1.5 — .gitignore contains governance exclusions
# ============================================================
if grep -qF ".governance/audit/" "$T/.gitignore" 2>/dev/null; then
  assert_pass
else
  assert_fail ".gitignore missing .governance/audit/"
fi
if grep -qF ".governance/sessions/" "$T/.gitignore" 2>/dev/null; then
  assert_pass
else
  assert_fail ".gitignore missing .governance/sessions/"
fi
if grep -qF ".governance/steps/" "$T/.gitignore" 2>/dev/null; then
  assert_pass
else
  assert_fail ".gitignore missing .governance/steps/"
fi
if grep -qF ".governance/current-task.json" "$T/.gitignore" 2>/dev/null; then
  assert_pass
else
  assert_fail ".gitignore missing .governance/current-task.json"
fi

# ============================================================
# 65. Phase 1.5 — .gitignore entries are idempotent (no duplicates)
# ============================================================
bash "$ROOT/scripts/bootstrap-project.sh" --target "$T" --platform claude >/dev/null
AUDIT_COUNT=$(grep -cF ".governance/audit/" "$T/.gitignore" 2>/dev/null || echo 0)
if [[ "$AUDIT_COUNT" -eq 1 ]]; then
  assert_pass
else
  assert_fail ".gitignore has duplicate .governance/audit/ entries ($AUDIT_COUNT)"
fi

# ============================================================
# 66. Phase 1.5 — enforcement scripts copied to target
# ============================================================
for script in check-commit-governance.sh check-module-contract.sh check-escalation-block.sh check-bug-evidence.sh; do
  if [[ -f "$T/scripts/$script" ]]; then
    assert_pass
  else
    assert_fail "enforcement script not copied: $script"
  fi
done

# ============================================================
# 67. Phase 1.5 — --validate detects missing .governance/
# ============================================================
T_GOV="$(mktemp_tracked)"
bash "$ROOT/scripts/bootstrap-project.sh" --target "$T_GOV" --platform claude >/dev/null
rm -rf "$T_GOV/.governance"
GOV_VAL_OUTPUT="$(timeout 60 bash "$ROOT/scripts/bootstrap-project.sh" --target "$T_GOV" --validate 2>&1)"
if echo "$GOV_VAL_OUTPUT" | grep -q "MISSING.*\.governance"; then
  assert_pass
else
  assert_fail "validate should report MISSING .governance/ directory"
fi

# ============================================================
# Results
# ============================================================
echo ""
echo "Results: $PASS passed, $FAIL failed"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
echo "PASS"
