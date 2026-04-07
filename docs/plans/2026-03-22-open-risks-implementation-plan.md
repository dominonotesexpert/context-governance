# Open Risks Implementation Plan

**Date:** 2026-03-22
**Status:** Proposed
**Depends on:** `2026-03-21-open-risks-validation-design.md`, `2026-03-21-business-semantics-confirmation-design.md`
**Scope:** Implement remaining open-risk mitigations and validation experiments from the open-risks design doc.

## Current State

The business-semantics confirmation layer is fully implemented:
- BASELINE_INTERPRETATION_LOG (Tier 0.5) — template, bootstrap, example, tests
- All downstream templates updated with business-semantic source citations
- ROUTING_POLICY with confirmation boundary rules
- ACCEPTANCE_RULES split into Business/Technical layers
- Bootstrap script and 252 passing tests

What remains unimplemented falls into **five workstreams**:

1. Engineering Constraints input path (Risk 3.3)
2. Governance Modes (Risk 3.4)
3. Derivation Fingerprinting (Risk 3.1)
4. Validation Experiments (Section 5)
5. External Signal Loops (Risk 3.5)

---

## Workstream 1: Engineering Constraints Input Path

**Addresses:** Risk 3.3 — Missing engineering-truth input
**Principle:** Business truth and engineering constraints must both have first-class representation

### Task 1.1 — Design ENGINEERING_CONSTRAINTS template

Create `docs/templates/system/ENGINEERING_CONSTRAINTS.template.md`:

- Authority tier: **1.5** (below SYSTEM_GOAL_PACK at Tier 1, above architecture at Tier 2)
- Owner role: system-architect (with engineering team input)
- Cannot override or contradict PROJECT_BASELINE
- Can shape downstream contracts and implementation choices

Entry structure per constraint:
```
| ID | Category | Constraint | Source | Impact on Contracts | Expiry |
```

Categories:
- `dependency-limit` — version pins, API deprecations, library restrictions
- `migration-window` — time-bounded technical transitions
- `performance-ceiling` — known capacity or latency boundaries
- `compliance-detail` — technical implementation of compliance requirements
- `legacy-constraint` — existing system limitations that shape design
- `third-party-defect` — known bugs in external dependencies

### Task 1.2 — Register in authority hierarchy

Update `SYSTEM_AUTHORITY_MAP.template.md`:
- Add Tier 1.5 section between Tier 1 (SYSTEM_GOAL_PACK) and Tier 2 (Architecture)
- Define consumption rules: Module Architect and Implementation Agent read it; Debug Agent references it for root-cause context

Update `ROUTING_POLICY.template.md` §4:
- Add ENGINEERING_CONSTRAINTS to Module Architect and Implementation artifact loading lists

### Task 1.3 — Update bootstrap infrastructure

Update `scripts/bootstrap-project.sh`:
- Add ENGINEERING_CONSTRAINTS.md to system artifacts bootstrapped
- File starts empty (no entries) but structure is present

Update `docs/templates/BOOTSTRAP_READINESS.template.md`:
- Add Tier 1.5 readiness state (always bootstrapped, may have zero entries initially)

### Task 1.4 — Update downstream templates

Update `MODULE_CONTRACT.template.md`:
- Add `upstream_engineering_constraints: []` to frontmatter
- Add guidance: "If an engineering constraint shapes this module's boundary, cite it here"

Update `ACCEPTANCE_RULES.template.md`:
- Layer 2 (Technical Verification Gates) may cite ENGINEERING_CONSTRAINTS as source

### Task 1.5 — Add example and tests

Add example entry in `docs/examples/minimal-governed-repo/system/ENGINEERING_CONSTRAINTS.md`

Add bootstrap test expectations:
- File creation test
- Frontmatter validation (authority_tier: 1.5, owner_role)
- Downstream reference test (MODULE_CONTRACT template mentions ENGINEERING_CONSTRAINTS)

### Task 1.6 — Update platform entrypoints

Update CLAUDE.md, AGENTS.md, GEMINI.md:
- System Architect loading list includes ENGINEERING_CONSTRAINTS
- Module Architect and Implementation receive extracted constraints

---

## Workstream 2: Governance Modes

**Addresses:** Risk 3.4 — No governance mode model
**Principle:** Exception handling must be explicit, time-boxed, and auditable

### Task 2.1 — Design GOVERNANCE_MODE template

Create `docs/templates/execution/GOVERNANCE_MODE.template.md`:

- Not upstream truth (execution-layer, like CURRENT_DIRECTION)
- Owner: system-architect (activated by user request or escalation)

Mode definitions:
| Mode | Description | Default Constraints |
|------|-------------|-------------------|
| `steady-state` | Normal operation. Full governance chain active | All tiers enforced |
| `exploration` | Design/spike phase. Contracts are drafts, not enforced | Tier 0-1 enforced, Tier 2+ advisory |
| `migration` | Active system transition. Temporary contract deviations allowed | Must declare deviation scope and revert date |
| `incident` | Production emergency. Minimal governance overhead | Tier 0-0.5 enforced, Tier 1+ suspended. Post-incident review mandatory |
| `exception` | Named, time-boxed bypass of specific rules | Must declare: which rule, why, expiry, revert plan |

Required fields per mode activation:
```yaml
current_mode: steady-state
activated_by: [user | escalation]
activation_date: YYYY-MM-DD
expiry_date: YYYY-MM-DD | null
scope: [description of what is affected]
suspended_rules: []
revert_plan: [what happens when mode expires]
```

### Task 2.2 — Design expiry enforcement mechanism

Expiry rules alone are wishes; the "Constraints by mechanism, not expectation" principle (CLAUDE.md §Constraint Principle, AGENTS.md rule 7) requires an enforceable mechanism.

**Expiry rules** (declared in GOVERNANCE_MODE template):
- `exploration` expires after 14 days unless renewed
- `migration` expires on declared revert date
- `incident` expires after 72 hours unless renewed
- `exception` expires on declared expiry date

**Enforcement mechanism** — ROUTING_POLICY HARD-GATE:

Add a pre-routing check to ROUTING_POLICY template (§6 or new §7):
```
HARD-GATE: Mode Expiry Check
When: System Architect loads GOVERNANCE_MODE at routing start
Check: If current_mode ≠ steady-state AND today > expiry_date
Action: BLOCK all routing until one of:
  (a) User explicitly renews the mode (new expiry_date set)
  (b) System Architect reverts mode to steady-state and logs transition
This is a HARD-GATE, not advisory. No agent may proceed past routing with an expired non-steady-state mode.
```

Add to BOOTSTRAP_READINESS template:
- First, extend the readiness state model (§2) to include `blocked`:

  | State | Meaning |
  |-------|---------|
  | `ready` | Role scaffold + core artifacts exist and are status: active |
  | `partial` | Some artifacts exist, others pending |
  | `not_started` | Role defined in design but no artifacts created yet |
  | `blocked` | Prerequisites exist but a hard constraint prevents proceeding |

  > **Why add `blocked`?** The current model (ready/partial/not_started) only tracks artifact existence. It cannot express "artifacts exist but the system is in a state that prohibits work." Expired governance modes are the first case; future constraints (e.g., expired engineering constraints, unresolved authority conflicts) may reuse this state.

- Then add the mode-specific check: If GOVERNANCE_MODE exists and `current_mode ≠ steady-state AND today > expiry_date` → readiness state = `blocked`
- Blocked reason: "Governance mode '{mode}' expired on {expiry_date}. Renew or revert before proceeding."

Add to System Architect skill HARD-GATE loading list:
- GOVERNANCE_MODE must be loaded alongside ROUTING_POLICY
- If mode is expired, System Architect must resolve before any other work

This ensures expiry is checked at routing time by every session, not dependent on a human remembering to check.

### Task 2.3 — Integrate with ROUTING_POLICY

Update `ROUTING_POLICY.template.md`:
- Add §6: Governance Mode Effects
- Define which routing steps are modified per mode
- System Architect must load GOVERNANCE_MODE before routing decisions
- If mode is not `steady-state`, routing must note the active mode and its constraints

### Task 2.4 — Add mode transition logging

Create `docs/templates/execution/MODE_TRANSITION_LOG.template.md`:
- Append-only log of all mode changes
- Entry: date, from_mode, to_mode, activated_by, reason, expiry, scope
- Provides audit trail for governance reviews

### Task 2.5 — Anti-bypass safeguards

Add to GOVERNANCE_MODE template:
- HARD RULE: **No mode may suspend Tier 0 or Tier 0.5.** PROJECT_BASELINE and BASELINE_INTERPRETATION_LOG are always authoritative, including during `incident`. This is consistent with SYSTEM_AUTHORITY_MAP rule 5: "PROJECT_BASELINE is Tier 0 — the absolute root of all truth." Incident mode suspends Tier 1+ enforcement, not business truth itself.
- HARD RULE: `exception` mode may not be renewed more than twice without escalation to user
- HARD RULE: `exploration` may not produce artifacts at `active` status (only `draft` or `proposed`)

**Enforcement mechanism** for these rules:

Add to ACCEPTANCE_RULES template (Layer 2, Technical Verification Gates):
- Gate: "If GOVERNANCE_MODE ≠ steady-state, verify no artifact at Tier 0 or 0.5 was modified or bypassed during the mode window"
- Gate: "If mode = exploration, verify no new artifact has status: active"
- Gate: "If mode = exception, verify renewal count ≤ 2 in MODE_TRANSITION_LOG"

Add to ROUTING_POLICY HARD-GATE (§6):
- System Architect must check and enforce these rules at routing time, not defer to downstream agents

### Task 2.6 — Add example, bootstrap, and tests

Update bootstrap script to create GOVERNANCE_MODE.md (default: steady-state) and MODE_TRANSITION_LOG.md

Add example in minimal-governed-repo/execution/

Add tests:
- File creation
- Default mode is steady-state
- Frontmatter validation
- Mode transition log structure

---

## Workstream 3: Derivation Fingerprinting

**Addresses:** Risk 3.1 — Derivation instability
**Principle:** Explicit derivation, never silent regeneration

### Task 3.1 — Extend derivation metadata in template frontmatter

Add to all derived-document templates (SYSTEM_GOAL_PACK, SYSTEM_INVARIANTS, MODULE_CONTRACT, ACCEPTANCE_RULES, VERIFICATION_ORACLE):

> **Note:** VERIFICATION_ORACLE is explicitly listed as a derived document in SYSTEM_AUTHORITY_MAP rule 6 and its own template header (line 19: "Derived From: MODULE_CONTRACT.md, MODULE_BOUNDARY.md, SYSTEM_INVARIANTS.md, ACCEPTANCE_RULES.md"). Omitting it would leave a gap in the derivation chain where stale oracle checks go undetected.

```yaml
derivation_context:
  model_id: [model identifier used for derivation]
  context_window: [token count of context at derivation time]
  prompt_version: [hash or version of the skill/prompt that drove derivation]
  derivation_timestamp: [ISO 8601 timestamp]
  upstream_hash: [git hash of upstream documents at derivation time]
```

### Task 3.2 — Define re-derivation trigger rules

Add to SYSTEM_AUTHORITY_MAP template or a new section in ROUTING_POLICY:

A derived document is **stale** when any of:
1. `upstream_hash` does not match current upstream document hashes
2. `derivation_timestamp` is older than the latest upstream modification
3. `model_id` differs from the current session's model (advisory, not blocking)

When stale:
- System Architect must re-derive before downstream agents consume
- Re-derivation produces a diff against the previous version
- Diff is reviewed before the new version is accepted

### Task 3.3 — Add last-known-good snapshot tracking

Create `docs/templates/system/DERIVATION_REGISTRY.template.md`:

> **Why a new artifact, not GOVERNANCE_PROGRESS?** GOVERNANCE_PROGRESS is a per-task JSON state file (`GOVERNANCE_PROGRESS-{task_id}.json`) for tracking single-task cross-session execution state (see template line 12-13). Last-known-good derivation tracking is a system-level, long-lived registry that spans all tasks and all derived documents. Mixing these concerns would violate GOVERNANCE_PROGRESS's defined scope.

Structure:
```yaml
artifact_type: derivation-registry
status: proposed
owner_role: system-architect
scope: system
authority_tier: n/a  # meta-artifact, not in authority chain
```

Entry per derived document:
```
| Document | Last Verified Good | derivation_context snapshot | git commit | Verification Date |
```

Behavior:
- Updated by System Architect after each successful derivation + verification cycle
- If re-derivation produces unexpected changes, compare against last-known-good entry
- Provides rollback path: git commit field points to the exact version to restore
- Register in SYSTEM_AUTHORITY_MAP as a meta-artifact (not a tier participant)

### Task 3.4 — Update bootstrap and tests

Update bootstrap script:
- Derived documents start with empty `derivation_context` (populated on first derivation)

Add tests:
- Derived document templates include `derivation_context` fields
- Fields are present but empty in bootstrapped instances

---

## Workstream 4: Validation Experiments

**Addresses:** Section 5 of open-risks design — all four experiments
**Principle:** System claims must be gated by validation evidence, not architecture preference

### Task 4.1 — Build experiment harness

Create `scripts/run-experiment.sh`:
- Input: experiment ID (1-4), configuration file
- Output: structured results in `docs/experiments/results/`
- Leverages existing seed scenarios from `docs/templates/optimization/test-scenarios/`
- Records: inputs, outputs, pass/fail per success signal, notes

Create `docs/experiments/` directory structure:
```
docs/experiments/
├── README.md              (experiment index and status)
├── configs/               (experiment configuration files)
│   ├── exp1-multi-model.yaml
│   ├── exp2-baseline-change.yaml
│   ├── exp3-delayed-reentry.yaml
│   └── exp4-phase-drift.yaml
└── results/               (experiment execution results)
```

### Task 4.2 — Experiment 1: Multi-model derivation stability

Config (`exp1-multi-model.yaml`):
```yaml
experiment_id: 1
name: Multi-model derivation stability
baseline: docs/examples/minimal-governed-repo/PROJECT_BASELINE.md
interpretation_log: docs/examples/minimal-governed-repo/system/BASELINE_INTERPRETATION_LOG.md
target_artifacts:
  - SYSTEM_GOAL_PACK
  - SYSTEM_INVARIANTS
  - MODULE_CONTRACT (api-service)
models: [model-a, model-b, model-c]  # to be filled at execution time
comparison_criteria:
  - semantic_equivalence
  - tier_source_traceability
  - escalation_consistency
```

Execution steps:
1. Use the existing example baseline + interpretation log as input
2. Derive target artifacts with 3 different models (via autoresearch skill or manual)
3. Compare outputs using diff and semantic comparison checklist
4. Record results per success/failure signal from §5.1

### Task 4.3 — Experiment 2: Baseline change propagation

Config (`exp2-baseline-change.yaml`):
```yaml
experiment_id: 2
name: Baseline change propagation
setup: Clone minimal-governed-repo example as working copy
mutation: Modify one bounded rule in PROJECT_BASELINE
trigger: Re-derive all downstream artifacts
measurement:
  - artifacts_flagged_stale
  - sections_changed
  - blast_radius_proportionality
  - false_positives
  - missed_impacts
```

Execution steps:
1. Copy example repo to temp directory
2. Make a targeted baseline change (e.g., add a new non-negotiable obligation)
3. Run System Architect derivation flow
4. Record which artifacts changed and which didn't
5. Evaluate blast radius against expected impact

### Task 4.4 — Experiment 3: Delayed human re-entry

Config (`exp3-delayed-reentry.yaml`):
```yaml
experiment_id: 3
name: Delayed human re-entry
type: qualitative
setup:
  governed_repo: minimal-governed-repo example (with full governance chain)
  control_repo: equivalent project with only README, code, and git history
evaluation_questions:
  - What is this product?
  - What matters most?
  - What constraints are non-negotiable?
  - What is in scope vs out of scope?
measurement:
  - time_to_answer
  - accuracy_vs_original_intent
  - sources_consulted
```

This experiment requires human participation. The plan:
1. Prepare both repos (governed and control) in advance
2. After a waiting period, have a person unfamiliar with the project attempt recovery
3. Record time, accuracy, and methodology used
4. Compare results

### Task 4.5 — Experiment 4: Phase-change drift detection

Config (`exp4-phase-drift.yaml`):
```yaml
experiment_id: 4
name: Phase-change drift detection
setup: Minimal governed repo in steady-state mode
scenario: Project enters migration phase (e.g., switching database)
prior_contracts: Keep existing contracts unchanged
measurement:
  - does_governance_surface_mismatch
  - time_to_detect_vs_control
  - false_alarms
  - missed_mismatches
```

Execution steps:
1. Use example repo with active contracts in `steady-state` GOVERNANCE_MODE
2. Activate `migration` mode via GOVERNANCE_MODE (set `current_mode: migration`, declare scope and expiry) — this is the primary mechanism being tested, not CURRENT_DIRECTION alone
3. Update CURRENT_DIRECTION to reflect the new phase context (migration scenario)
4. Attempt implementation that conflicts with prior steady-state contracts
5. Observe whether:
   - The ROUTING_POLICY mode-effect rules (§6) modify routing behavior
   - The mode-aware ACCEPTANCE_RULES gates flag contract deviations outside declared scope
   - The BOOTSTRAP_READINESS check surfaces any mode-related issues
6. Compare against a repo without governance (just code + CI)
7. Additionally test the expiry path: let the migration mode expire without reverting, and verify the HARD-GATE blocks further work

**Dependency:** This experiment requires Workstream 2 (Governance Modes) to be fully implemented, as it tests the mode system's ability to surface phase mismatches through HARD-GATEs and routing effects — not just directional context updates.

---

## Workstream 5: External Signal Loops (Lightweight)

**Addresses:** Risk 3.5 — Business verification is not fully automatable
**Principle:** Business acceptance requires human review, not only automated checks

### Task 5.1 — Add external signal section to ACCEPTANCE_RULES template

Update Layer 1 (Business Acceptance Semantics):
- Add a section: "External Validation Signals"
- Define signal types: user feedback, business metrics, customer reports, stakeholder review
- Each signal maps to one or more acceptance criteria
- Signals are recorded in FEEDBACK_LOG (template already exists)

### Task 5.2 — Add periodic review checkpoint to FEEDBACK_LOG

> **Why FEEDBACK_LOG, not GOVERNANCE_PROGRESS?** GOVERNANCE_PROGRESS is a per-task JSON state file for single-task cross-session execution tracking (template line 12-13, instantiated as `GOVERNANCE_PROGRESS-{task_id}.json`). Periodic business alignment review is a system-level, recurring activity that spans all tasks. FEEDBACK_LOG (already existing at `docs/templates/verification/FEEDBACK_LOG.template.md`) is the correct home — it already captures user feedback and external signals across sessions.

Add a section to FEEDBACK_LOG template:
```
## Periodic Business Alignment Review

| Review Date | Reviewer | Baseline Version | Findings | Action Items | Next Scheduled |
|-------------|----------|-----------------|----------|-------------|----------------|
```

- Each review is appended as a new row
- Reviewer is the user or stakeholder, not an agent
- Findings link to specific BASELINE sections or INTERPRETATION_LOG entries
- Action items may trigger new interpretation entries or baseline updates

This provides a structured place for the human review that Risk 3.5 demands, without building complex automation.

---

## Execution Order and Dependencies

```
Phase A (independent, can be parallel):
├── Workstream 1: Engineering Constraints    [Tasks 1.1-1.6]
├── Workstream 3: Derivation Fingerprinting  [Tasks 3.1-3.4]
└── Workstream 5: External Signal Loops      [Tasks 5.1-5.2]

Phase B (depends on Phase A):
└── Workstream 2: Governance Modes           [Tasks 2.1-2.6]
    (benefits from Workstream 1 being in place for constraint-aware modes)

Phase C (depends on Phases A and B):
└── Workstream 4: Validation Experiments     [Tasks 4.1-4.5]
    (Experiments 1-3 can run after Phase A)
    (Experiment 4 requires Phase B governance modes)
```

## Implementation Pattern

Each workstream follows the same pattern established in the business-semantics implementation:

1. **Lock expectations with failing tests** — write test assertions before implementation
2. **Create/update templates** — add new artifacts or extend existing ones
3. **Update authority hierarchy** — register in SYSTEM_AUTHORITY_MAP, ROUTING_POLICY
4. **Update bootstrap** — ensure new artifacts are created by bootstrap script
5. **Add examples** — demonstrate in minimal-governed-repo
6. **Update platform entrypoints** — CLAUDE.md, AGENTS.md, GEMINI.md
7. **Verify all tests pass** — confirm with full test suite

## Estimated Scope

| Workstream | New Templates | Modified Templates | New Tests | Priority |
|-----------|--------------|-------------------|-----------|----------|
| 1. Engineering Constraints | 1 | 5 | ~15 | High |
| 2. Governance Modes | 2 | 5 (incl. ROUTING_POLICY HARD-GATE, SA skill, BOOTSTRAP_READINESS) | ~20 | High |
| 3. Derivation Fingerprinting | 1 (DERIVATION_REGISTRY) | 6 (incl. VERIFICATION_ORACLE) | ~12 | Medium |
| 4. Validation Experiments | 5+ configs | 0 | ~5 | Medium |
| 5. External Signal Loops | 0 | 2 (ACCEPTANCE_RULES, FEEDBACK_LOG) | ~5 | Low |

## Success Criteria

This plan is complete when:

1. `ENGINEERING_CONSTRAINTS` template exists and is registered at Tier 1.5 in SYSTEM_AUTHORITY_MAP
2. `GOVERNANCE_MODE` template exists with 5 defined modes, and expiry is enforced via ROUTING_POLICY HARD-GATE (not just documented as a rule)
3. All derived-document templates (SYSTEM_GOAL_PACK, SYSTEM_INVARIANTS, MODULE_CONTRACT, ACCEPTANCE_RULES, VERIFICATION_ORACLE) include `derivation_context` metadata
4. `DERIVATION_REGISTRY` template exists for system-level last-known-good tracking
5. Experiment harness exists and all four experiments (§5.1-5.4) have been executed with results recorded — per the open-risks design doc §7 (Recommended Next Step): "avoid claiming full business-alignment success until at least the four experiments have been run"
6. ACCEPTANCE_RULES Layer 1 includes external validation signal structure
7. FEEDBACK_LOG includes periodic business alignment review section
8. All existing tests continue to pass (no regressions)
9. Bootstrap script creates all new artifacts (ENGINEERING_CONSTRAINTS, GOVERNANCE_MODE, MODE_TRANSITION_LOG, DERIVATION_REGISTRY)
10. Minimal-governed-repo example demonstrates all new features
