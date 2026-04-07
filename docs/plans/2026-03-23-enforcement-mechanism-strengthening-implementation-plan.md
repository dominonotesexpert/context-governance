# Enforcement Mechanism Strengthening — Implementation Plan

**Date:** 2026-03-23
**Status:** Proposed
**Design:** `2026-03-23-enforcement-mechanism-strengthening-design.md`
**Scope:** 4 phases, 21 files, ~35-40 new test assertions

---

## Phase 1: Root Cause Level Classification & Debug Protocol Hardening (Issue Group A)

**Dependencies:** None
**Goal:** Introduce root cause level classification (including `engineering-constraint`), validation gate, prediction-observation loop, business-semantics escalation gate, governance-mode compatibility, level-based routing

### 1.1 Modify `docs/templates/debug/DEBUG_CASE_TEMPLATE.template.md`

In `## 5. Root Cause`, after existing `Disproven alternatives` field, append:

```markdown
- **Root Cause Level:** code | module | cross-module | engineering-constraint | architecture | baseline
- **Level Justification:** <!-- Why this level and not a lower/higher one -->
```

Root Cause Level definitions:
- `code` — bug in a single function/file, contract is correct
- `module` — module implementation doesn't match its contract
- `cross-module` — interaction between modules produces unexpected behavior
- `engineering-constraint` — root cause is a known engineering limitation (third-party defect, capacity limit, migration window) documented or documentable in ENGINEERING_CONSTRAINTS (Tier 1.5)
- `architecture` — system design doesn't account for this scenario
- `baseline` — business requirement is ambiguous or contradictory

Insert new section between `## 5. Root Cause` and `## 6. Fix Scope`:

```markdown
## 5A. Root Cause Validation Gate

All items MUST be checked before setting Confidence to `confirmed`:

- [ ] **Anti-falsification:** At least 2 alternative hypotheses proposed AND disproven with evidence
- [ ] **Prediction verified:** A specific prediction derived from hypothesis was confirmed by observation
- [ ] **All symptoms explained:** Root cause accounts for every observed symptom, not just the primary one
- [ ] **Open gaps empty:** No items remain in Evidence Ledger > Open Evidence Gaps

If ANY item unchecked, Confidence MUST remain `partial` or `hypothesis`.

Note: User confirmation is NOT part of this gate. This is the autonomous quality gate.
User escalation is governed by the business-semantics boundary (see Debug SKILL Step 8A).
```

### 1.2 Modify `.claude/skills/debug/SKILL.md`

**(a)** Insert after Step 6:

```markdown
### Step 6A: Upstream Boundary Check (Mandatory)
At each module hop in the trace, verify:
1. Does the input to this module match the upstream module's declared output contract?
2. Does the failure originate WITHIN this module, or was it passed a bad input from upstream?
3. If the failure crossed a module boundary, the Root Cause Level is at minimum `cross-module`.

Record boundary check results in the Evidence Ledger under Confirmed Evidence.
```

**(b)** Insert after Step 7 (UI/Handoff Checklist):

```markdown
### Step 7A: Prediction-Observation Validation
Before declaring root cause:
1. State a specific, falsifiable prediction derived from your root cause hypothesis
   - Example: "If the bug is caused by X, then doing Y should produce result Z"
2. Execute or verify the prediction (read code, run test, check logs)
3. Record prediction, expected result, and actual result in the Evidence Ledger
   - Prediction confirmed → record in Confirmed Evidence
   - Prediction failed → record in Disproven, return to Step 6 and investigate further
```

**(c)** In Step 8 (Output Root Cause), append requirements 6 and 7:

```markdown
6. Root Cause Level classification: `code` | `module` | `cross-module` | `engineering-constraint` | `architecture` | `baseline`
7. Root Cause Validation Gate — ALL 4 items in DEBUG_CASE §5A must be checked before Confidence = confirmed
```

**(d)** Insert after Step 8:

```markdown
### Step 8A: Business-Semantics Escalation Gate

After the validation gate (§5A) passes, determine whether the root cause level requires user escalation:

| Root Cause Level | User Escalation? | Rationale |
|-----------------|-------------------|-----------|
| `code` | No | Pure technical fix |
| `module` | No | Technical — within existing contract |
| `cross-module` | Only if contract gap has business-semantic implications | Technical unless it changes business meaning |
| `engineering-constraint` | No | Engineering fact, not business semantics |
| `architecture` | Yes, if fix requires Tier 0.8 change OR changes business semantics | Two triggers — see below |
| `baseline` | Always | This IS a business-semantics issue |

For `architecture` level, user escalation triggers on EITHER:
1. Fix would alter business meaning, scope, or success semantics (ROUTING_POLICY §5.1)
2. Fix requires modifying PROJECT_ARCHITECTURE_BASELINE (Tier 0.8 is user-owned; agents may not edit it directly — requires ARCHITECTURE_CHANGE_PROPOSAL + user approval per `2026-03-22-project-architecture-baseline-design.md` §8.3-§8.4)

If neither applies (resolvable within Tier 2 SYSTEM_ARCHITECTURE) → System Architect autonomous.

When user escalation IS required:
- Present: root cause summary, level classification, disproven alternatives, specific escalation trigger (business-semantic or Tier 0.8 structural)
- For Tier 0.8 changes: include ARCHITECTURE_CHANGE_PROPOSAL draft
- Receive explicit user confirmation before proceeding
- This IS a HARD-GATE for the specific levels that trigger it

When user escalation is NOT required:
- Proceed directly to level-based routing (Step 9)
- Record the root cause and level in the DEBUG_CASE for audit trail

### Governance Mode Compatibility

| Mode | Effect on Steps 6A/7A/8A |
|------|-------------------------|
| `steady-state` | Full enforcement |
| `exploration` | Validation gate (§5A) is advisory — flags but doesn't block |
| `incident` | Steps 6A/7A/8A are DEFERRED to post-incident review. Incident routing (System → Implementation → post-incident review) takes precedence per ROUTING_POLICY §8. Deferred steps become mandatory during post-incident review. |
| `migration` | Full enforcement within declared scope |
| `exception` | Only declared suspended rules are relaxed |
```

**(e)** In Step 10 (Hand Off to Implementation), append level-based routing:

```markdown
Route the handoff based on confirmed Root Cause Level:
- `code` → Implementation Agent (standard fix)
- `module` → Implementation Agent + Module Architect review of fix scope
- `cross-module` → Module Architect must review both modules' contracts before Implementation
- `engineering-constraint` → System Architect (update or create ENGINEERING_CONSTRAINTS entry) → then downstream route based on constraint impact
- `architecture` → System Architect must evaluate architectural impact before any code change
- `baseline` → Escalate to User — BASELINE may need updating; no code change until resolved
```

**(f)** In Escalation section, append:

```markdown
- Root cause level = `cross-module` → escalate to Module Architect for both modules
- Root cause level = `engineering-constraint` → escalate to System Architect (ENGINEERING_CONSTRAINTS update)
- Root cause level = `architecture` → escalate to System Architect
- Root cause level = `baseline` → escalate to User (BASELINE ambiguity or error)
```

### 1.3 Modify `CLAUDE.md`

Replace the MANDATORY SEQUENCE (steps 1-10) under "For Bug Tasks Specifically" with:

```
MANDATORY SEQUENCE:
1. Create DEBUG_CASE (before reading code)
2. If regression, establish Last Known Good / First Known Bad / Behavior Delta
3. Select System Scenario Map (match trigger to scenario)
4. Drill down to Module Canonical Maps (trace the failure path)
5. For UI/runtime handoff bugs, prove which layer is hidden, mounted, visible, and owning the user-visible surface
6. Upstream boundary check at each module hop
7. Confirm root cause with evidence + Prediction-observation validation
8. Complete Root Cause Validation Gate (4 items) + Classify root cause level
8A. Escalation gate: if level = baseline, or architecture requiring Tier 0.8 change or business-semantic impact → user confirmation required. Otherwise proceed autonomously.
9. Route by level: code→Implementation, module→Impl+MA review, cross-module→MA, engineering-constraint→SA(EC update), architecture→SA, baseline→User
10. Implement fix (only after routing gate clears)
11. Verify with evidence
```

Change "Do NOT skip steps 1-8" to "Do NOT skip steps 1-8A".

Note: In `incident` governance mode, steps 6-8A are deferred to post-incident review per ROUTING_POLICY §8.

### 1.4 Modify `AGENTS.md`

In Debug Agent section, after "Confirm root cause with evidence", add:
- Classify root cause level: code | module | cross-module | engineering-constraint | architecture | baseline
- Complete Root Cause Validation Gate (4 autonomous items) before setting confidence to confirmed
- Escalation gate: user confirmation for baseline, or architecture requiring Tier 0.8 change or business-semantic impact
- Route handoff by root cause level (engineering-constraint → System Architect for EC update)

### 1.5 Modify `docs/templates/system/ROUTING_POLICY.template.md`

Append to §4 Debug Agent subsection:

```markdown
### Debug Agent Level-Based Routing

After root cause confirmation (Step 8A), Debug Agent routes based on root cause level:

| Root Cause Level | Routing Target | User Escalation? | Rationale |
|-----------------|----------------|------------------|-----------|
| `code` | Implementation Agent | No | Single-point fix within one module |
| `module` | Implementation Agent + Module Architect review | No | Fix may affect module contract |
| `cross-module` | Module Architect (both modules) → Implementation | Only if business-semantic | Contract boundary violation |
| `engineering-constraint` | System Architect (EC update) → downstream route | No | Engineering fact, not business semantics |
| `architecture` | System Architect → Module Architect → Implementation | Only if business-semantic | Systemic architectural issue |
| `baseline` | User → System Architect re-derivation → standard route | Always | Upstream truth issue |

Debug Agent MUST NOT hand off directly to Implementation for `cross-module`, `engineering-constraint`, `architecture`, or `baseline` level bugs.

### Governance Mode Compatibility

When GOVERNANCE_MODE = `incident`, the above level-based routing is DEFERRED. Incident mode routing (System → Implementation → post-incident review) takes precedence per ROUTING_POLICY §8. Level-based routing becomes mandatory during post-incident review.
```

### 1.6 Modify `.claude/skills/implementation/SKILL.md`

- In "When You Activate": add receiving `code` or `module` level handoff from Debug
- In "When NOT to Activate": add `cross-module`/`engineering-constraint`/`architecture`/`baseline` level bugs must go through upstream roles first

### 1.7 Modify `docs/examples/debug-case-example.md`

After `Defect type` field, append:
```markdown
- **Root Cause Level:** module
- **Level Justification:** Defect is in module-level configuration (default maxOutputTokens), affecting all complex-form paths within this module. Not a single code line fix (code), does not cross module boundaries (cross-module).
```

Insert §4A Root Cause Validation Gate between Root Cause and Fix Scope sections (all items checked).

### 1.8 Modify `docs/templates/debug/DEBUG_BOOTSTRAP_PACK.template.md`

In Role Memory Summary, append:
- Root cause levels definition (code → module → cross-module → engineering-constraint → architecture → baseline)
- Validation gate requirements
- Level routing rules

In Task Activation Requirements, append:
- Root Cause Level classification understood
- Root Cause Validation Gate checklist available

### 1.9 Tests (~15-18 new assertions)

- Template has `Root Cause Level` field with all 6 levels (including `engineering-constraint`)
- Template has `Root Cause Validation Gate` section with 4 autonomous gate items (NOT 5 — no user confirmation in gate)
- Debug SKILL has `Upstream Boundary Check`, `Prediction-Observation Validation`, `Business-Semantics Escalation Gate`
- Debug SKILL has level-based routing table with all 6 levels
- Debug SKILL has `Governance Mode Compatibility` section
- ROUTING_POLICY has `Level-Based Routing` section with `engineering-constraint` row
- CLAUDE.md has level classification and business-semantics escalation gate (not blanket user confirmation)
- Example has `Root Cause Level` and Validation Gate

---

## Phase 2: HARD-GATE Document Loading Validation Script (Issue Group B)

**Dependencies:** None (parallel with Phase 1)
**Goal:** Executable script to validate role prerequisites exist

### 2.1 Create `scripts/check-hardgate.sh`

```
Usage: scripts/check-hardgate.sh --role <role> --target <path> [--module <name>]
```

**Authority source:** The script reads `required_files` from each role's Bootstrap Pack frontmatter in the target project. Bootstrap Packs are the machine-readable encoding of ROUTING_POLICY §4. This prevents mapping drift — when ROUTING_POLICY changes and Bootstrap Packs are updated, the script automatically picks up the change.

**Lookup order:**
1. Read `docs/agents/<namespace>/<ROLE>_BOOTSTRAP_PACK.md` frontmatter `required_files` field
2. Map paths relative to `docs/agents/` → absolute paths under `$TARGET/docs/agents/`
3. If Bootstrap Pack doesn't exist or lacks `required_files` → fall back to hardcoded defaults with a warning

**Bootstrap Pack → role mapping:**
- `system-architect` → `docs/agents/system/SYSTEM_BOOTSTRAP_PACK.md`
- `module-architect` → `docs/agents/modules/<module>/MODULE_BOOTSTRAP_PACK.md`
- `debug` → `docs/agents/debug/DEBUG_BOOTSTRAP_PACK.md`
- `verification` → `docs/agents/verification/<module>/VERIFICATION_BOOTSTRAP_PACK.md` (per-module, per `docs/templates/verification/README.md`)
- `implementation` → no dedicated pack; uses hardcoded defaults from ROUTING_POLICY §4

**`--module` handling:** When provided, additionally check `docs/agents/modules/<name>/MODULE_CONTRACT.md` (required by debug, module-architect, implementation, verification roles per ROUTING_POLICY §4).

Output format:
```
HARDGATE Check: role=debug target=/path/to/project (source: DEBUG_BOOTSTRAP_PACK)
  OK       docs/agents/system/SYSTEM_GOAL_PACK.md
  MISSING  docs/agents/system/SYSTEM_SCENARIO_MAP_INDEX.md
  OK       docs/agents/debug/DEBUG_CASE_TEMPLATE.md

1 MISSING file(s). HARD-GATE FAILED.
```

Exit code: 0 = all present, 1 = any missing, 2 = invalid arguments.

Script structure follows `bootstrap-project.sh` patterns: `set -euo pipefail`, `while/case` arg parsing.

### 2.2 Upgrade Bootstrap Pack template frontmatter

Add `required_files:` list to all 4 Bootstrap Pack templates (paths relative to `docs/agents/`).

### 2.3 Update `README.md`

Add Enforcement Scripts subsection with usage examples.

### 2.4 Tests (~8-10 new assertions)

- Script exists and is executable
- Passes for fully bootstrapped project (debug role)
- Fails for empty directory with MISSING in output
- Passes for system-architect role on bootstrapped project
- Rejects invalid role name
- Bootstrap Pack frontmatter has `required_files`

---

## Phase 3: Derivation Chain Staleness Detection & Derived Document Protection (Issue Groups C + D)

**Dependencies:** None (parallel with Phases 1 and 2)
**Goal:** Detect stale derivations, prevent direct edits to derived documents

### 3.1 Create `scripts/check-staleness.sh`

```
Usage: scripts/check-staleness.sh --target <path>
```

Logic:
1. Scan `.md` files with `derivation_context:` in frontmatter
2. Extract `upstream_hash` value
3. If empty → report `NO_HASH` (warning only)
4. Read the document's own `upstream_sources` frontmatter field to determine its upstream files
5. If `upstream_sources` is not present → fall back to hardcoded defaults with a warning
6. If target is git repo → compute current combined hash of upstream files → compare against `upstream_hash`
7. Match → `FRESH`, mismatch → `STALE`

**Authority source:** Each derived document's frontmatter `upstream_sources` field declares its own upstream. This is self-describing — no separate mapping table. The `upstream_sources` field is added to each derived template as part of this plan (see §2.2 below).

**Correct upstream mappings** (per `2026-03-22-project-architecture-baseline-design.md` §7.2 and §12):
- SYSTEM_GOAL_PACK → PROJECT_BASELINE, BASELINE_INTERPRETATION_LOG
- SYSTEM_INVARIANTS → PROJECT_BASELINE, BASELINE_INTERPRETATION_LOG
- SYSTEM_ARCHITECTURE → PROJECT_BASELINE, BASELINE_INTERPRETATION_LOG, PROJECT_ARCHITECTURE_BASELINE, SYSTEM_GOAL_PACK, ENGINEERING_CONSTRAINTS
- MODULE_CONTRACT → SYSTEM_GOAL_PACK, SYSTEM_ARCHITECTURE, SYSTEM_INVARIANTS, ENGINEERING_CONSTRAINTS
- ACCEPTANCE_RULES → SYSTEM_GOAL_PACK, SYSTEM_INVARIANTS, MODULE_CONTRACT
- VERIFICATION_ORACLE → ACCEPTANCE_RULES, MODULE_CONTRACT

Exit code: 0 = no STALE, 1 = any STALE. NO_HASH is warning only.
Non-git directories handled gracefully (skip with message).

### Additional: Add `upstream_sources` to derived templates

Add `upstream_sources` field to frontmatter of these templates:
- `docs/templates/system/SYSTEM_GOAL_PACK.template.md`
- `docs/templates/system/SYSTEM_INVARIANTS.template.md`
- `docs/templates/system/SYSTEM_ARCHITECTURE.template.md`
- `docs/templates/modules/MODULE_CONTRACT.template.md`
- `docs/templates/verification/ACCEPTANCE_RULES.template.md`
- `docs/templates/verification/VERIFICATION_ORACLE.template.md`

Example (SYSTEM_ARCHITECTURE):
```yaml
upstream_sources:
  - "PROJECT_BASELINE.md"
  - "system/BASELINE_INTERPRETATION_LOG.md"
  - "PROJECT_ARCHITECTURE_BASELINE.md"
  - "system/SYSTEM_GOAL_PACK.md"
  - "system/ENGINEERING_CONSTRAINTS.md"
```

Paths are relative to `docs/agents/`.

### 3.2 Create `scripts/check-derived-edits.sh`

```
Usage: scripts/check-derived-edits.sh [--strict]
```

Logic:
1. Get staged files: `git diff --cached --name-only`
2. For each staged `.md` file with `derivation_type:` in frontmatter:
   - Compare the staged version's `derivation_context` block against the committed version
   - If `derivation_context.derivation_timestamp` or `upstream_hash` has changed → legitimate re-derivation → ALLOW
   - If content changed but `derivation_context` is unchanged → direct edit without re-derivation → WARN/BLOCK
3. `--strict` → exit 1 on any unauthorized direct edit, otherwise warning only

**Why this heuristic:** A proper re-derivation always updates `derivation_context` (timestamp, upstream_hash, model_id) per the DERIVATION_REGISTRY protocol. Checking derivation_context is the correct legitimacy signal — not whether upstream files happen to be staged in the same commit.

### 3.3 Create `.githooks/pre-commit`

Example hook calling `check-derived-edits.sh --strict`.

### 3.4 Tests (~6-8 new assertions)

- Both scripts exist
- `check-staleness.sh` reports NO_HASH for fresh bootstrap
- `check-staleness.sh` handles non-git directory gracefully
- `.githooks/pre-commit` exists

---

## Phase 4: `--validate` Enhancement (Issue Group E)

**Dependencies:** Phase 3 (needs `check-staleness.sh`)
**Goal:** Enhance bootstrap validation with staleness, mode expiry, and deterministic pass/fail verdict

### 4.1 Modify `scripts/bootstrap-project.sh` validate mode

**(a) Staleness integration:** Call `check-staleness.sh` when available, count STALE as issues.

**(b) Governance mode expiry:** Read `GOVERNANCE_MODE.md`, check `current_mode` and `expiry_date`. If non-steady-state and past expiry → EXPIRED (counted as issue).

**(c) Interpretation log cross-check:** If derived documents reference INT-XXX entries that are still pending → WARN.

**(d) Deterministic verdict:** Each check produces `PASS` or `FAIL` with a specific reason. Final output:
- All checks pass → `Verdict: PASS`
- Any check fails → `Verdict: FAIL` + list of failed checks

No gradient scores, no percentages. This follows the project's deterministic pass/fail model (`README.md:180`).

### 4.2 Tests (~5-7 new assertions)

- Validate output contains Staleness section
- Validate output contains Governance Mode section
- Validate output contains `Verdict: PASS` or `Verdict: FAIL` (deterministic, no gradient)
- Manually expired governance mode is detected as EXPIRED (FAIL)

---

## Implementation Order

```
Phase 1 (Root Cause Level)  ─┐
Phase 2 (HARD-GATE script)  ─┼──→ Phase 4 (--validate enhancement)
Phase 3 (Staleness + Protection) ─┘     (depends on Phase 3's check-staleness.sh)
```

Phases 1, 2, 3 have no inter-dependencies — can be implemented in parallel.

## Files Summary

| File | Change | Phase |
|------|--------|-------|
| `docs/templates/debug/DEBUG_CASE_TEMPLATE.template.md` | Modify | 1 |
| `.claude/skills/debug/SKILL.md` | Modify (most complex) | 1 |
| `CLAUDE.md` | Modify | 1 |
| `AGENTS.md` | Modify | 1 |
| `docs/templates/system/ROUTING_POLICY.template.md` | Modify | 1 |
| `.claude/skills/implementation/SKILL.md` | Modify | 1 |
| `docs/examples/debug-case-example.md` | Modify | 1 |
| `docs/templates/debug/DEBUG_BOOTSTRAP_PACK.template.md` | Modify | 1, 2 |
| `scripts/check-hardgate.sh` | Create | 2 |
| `scripts/check-staleness.sh` | Create | 3 |
| `scripts/check-derived-edits.sh` | Create | 3 |
| `.githooks/pre-commit` | Create | 3 |
| `docs/templates/system/SYSTEM_GOAL_PACK.template.md` | Modify (add `upstream_sources`) | 3 |
| `docs/templates/system/SYSTEM_INVARIANTS.template.md` | Modify (add `upstream_sources`) | 3 |
| `docs/templates/system/SYSTEM_ARCHITECTURE.template.md` | Modify (add `upstream_sources`) | 3 |
| `docs/templates/modules/MODULE_CONTRACT.template.md` | Modify (add `upstream_sources`) | 3 |
| `docs/templates/verification/ACCEPTANCE_RULES.template.md` | Modify (add `upstream_sources`) | 3 |
| `docs/templates/verification/VERIFICATION_ORACLE.template.md` | Modify (add `upstream_sources`) | 3 |
| `scripts/bootstrap-project.sh` | Modify | 4 |
| `tests/bootstrap-project.test.sh` | Modify | 1-4 |
| `README.md` | Modify | 2 |

## Test Increment

| Phase | New Assertions | Cumulative (baseline ~229) |
|-------|---------------|---------------------------|
| 1 | ~15-18 | ~244-247 |
| 2 | ~8-10 | ~252-257 |
| 3 | ~6-8 | ~258-265 |
| 4 | ~5-7 | ~263-272 |

## Verification Per Phase

1. `bash tests/bootstrap-project.test.sh` — all existing + new tests pass
2. Manual run of new scripts on bootstrapped project — verify output format
3. Backward compatibility: old bootstrapped projects don't break (missing new fields = UNFILLED, not error)
