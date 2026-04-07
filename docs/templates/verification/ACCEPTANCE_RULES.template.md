---
artifact_type: acceptance-rules
status: proposed
owner_role: verification
scope: verification
downstream_consumers: [implementation, debug]
last_reviewed: 2026-03-20
derived_from_baseline_version: "v0.0"
derivation_type: mixed
verified: pending
derived_sections: []
upstream_sources:
  - "system/SYSTEM_GOAL_PACK.md"
  - "system/SYSTEM_INVARIANTS.md"
derivation_context:
  model_id: ""
  context_window: ""
  prompt_version: ""
  derivation_timestamp: ""
  upstream_hash: ""
---

# ACCEPTANCE_RULES

**Status:** proposed
**Owner:** Verification Agent
**Last Updated:** YYYY-MM-DD
**Derived From:** PROJECT_BASELINE §5 (Success Criteria), BASELINE_INTERPRETATION_LOG, SYSTEM_GOAL_PACK, and MODULE_CONTRACT

> ⚠ This is a **derived document**. Acceptance criteria are derived from upstream contracts and baseline success criteria.
> To change acceptance rules, update the upstream source (BASELINE, BASELINE_INTERPRETATION_LOG, MODULE_CONTRACT) and re-derive.

---

## Layer 1: Business Acceptance Semantics

> This layer defines what "success" means in business terms.
> It may only derive from PROJECT_BASELINE and BASELINE_INTERPRETATION_LOG.
> Agents cannot modify these criteria without user confirmation.

### BA-1. Business Success

The implementation achieves the business outcomes described in PROJECT_BASELINE §5 (Success Criteria). If any success criterion required semantic interpretation, the confirmed interpretation from BASELINE_INTERPRETATION_LOG applies.

### BA-2. Business Rules Preserved

No non-negotiable business rule from PROJECT_BASELINE §4 is violated. The implementation respects the user-confirmed meaning of each rule, not just the literal text.

### BA-3. Scope Respected

The implementation does not exceed the boundaries defined in PROJECT_BASELINE §6 (Out of Scope). If scope boundaries required clarification, the confirmed interpretation applies.

---

## Layer 2: Technical Verification Gates

> This layer defines how verification proves that business acceptance is met.
> It may derive from SYSTEM_GOAL_PACK, SYSTEM_INVARIANTS, and MODULE_CONTRACT.
> Agents may refine these gates without user confirmation, as long as they do not alter business meaning.

### 1. Pass

ALL of the following must be true simultaneously:
1. All contract obligations from MODULE_CONTRACT are met
2. Verification evidence is present (not just "code looks right")
3. No blocking risks identified
4. Regression matrix checked — no regressions triggered
5. Business acceptance semantics (Layer 1) are satisfied

### 2. Pass with Risk

1. Core contract obligations are met
2. Residual risk is explicitly documented and tracked
3. Risk does not violate any system invariant
4. Risk owner is identified

### 3. Fail

ANY of the following is a blocking failure:
1. A contract obligation is not met
2. A system invariant is violated
3. Tests pass but contract is not satisfied (tests don't cover the contract)
4. Fail-closed behavior is bypassed
5. Source of truth ownership is breached
6. A business acceptance semantic (Layer 1) is not met

### 4. Insufficient Evidence

1. No clear proof that the contract is satisfied OR violated
2. Code reading alone is not sufficient evidence — need runtime proof
3. Must escalate for additional evidence collection or contract clarification

### 5. Evidence Rules

1. **No evidence = no completion claim** — "I think it works" is not evidence
2. **Code reading supplements but doesn't replace runtime evidence**
3. **Tests must map to contract items** — untargeted test suites don't prove contract satisfaction
4. **Business acceptance requires periodic human review** — agent-driven checks verify technical compliance, not true business-goal alignment

### External Validation Signals

Business acceptance cannot be fully verified by agent-driven checks alone. The following external signal types provide evidence for or against business-goal alignment:

| Signal Type | Description | Maps To |
|-------------|-------------|---------|
| `user-feedback` | Direct user/stakeholder feedback on whether the system meets business intent | BA-* acceptance criteria |
| `business-metrics` | Quantitative business outcomes (revenue, conversion, adoption rates) | Product vision alignment |
| `customer-reports` | Customer-reported issues or feature requests that indicate intent mismatch | BA-* acceptance criteria |
| `stakeholder-review` | Formal periodic review by business stakeholders | Overall business acceptance |

**Recording:** External signals are recorded in FEEDBACK_LOG.md with signal type, date, source, and linked acceptance criteria.

**Escalation:** If an external signal contradicts a confirmed interpretation in BASELINE_INTERPRETATION_LOG, escalate to System Architect for re-evaluation — do not silently override.

### 6. Architectural Conformance

Implementation must conform to SYSTEM_ARCHITECTURE.md structural decisions. Architectural drift (implementation deviating from Tier 2 architecture) is a verification failure unless an ARCHITECTURE_CHANGE_PROPOSAL has been approved.

### 7. Mode-Aware Verification Gates

When GOVERNANCE_MODE ≠ steady-state, the following additional gates apply:

| Gate | Condition | Verification |
|------|-----------|-------------|
| Tier 0/0.5/0.8 integrity | Any non-steady-state mode | Verify no artifact at Tier 0, 0.5, or 0.8 was modified or bypassed during the mode window |
| Exploration artifact status | mode = exploration | Verify no new artifact has status: `active` (only `draft` or `proposed` allowed) |
| Exception renewal limit | mode = exception | Verify renewal count ≤ 2 in MODE_TRANSITION_LOG |
| Post-incident review | mode = incident (after revert) | Verify post-incident review was completed and documented |
