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
---

# ACCEPTANCE_RULES

**Status:** proposed
**Owner:** Verification Agent
**Last Updated:** YYYY-MM-DD
**Derived From:** PROJECT_BASELINE §5 (Success Criteria) via SYSTEM_GOAL_PACK and MODULE_CONTRACT

> ⚠ This is a **derived document**. Acceptance criteria are derived from upstream contracts and baseline success criteria.
> To change acceptance rules, update the upstream source (BASELINE, MODULE_CONTRACT) and re-derive.

---

## 1. Pass

ALL of the following must be true simultaneously:
1. All contract obligations from MODULE_CONTRACT are met
2. Verification evidence is present (not just "code looks right")
3. No blocking risks identified
4. Regression matrix checked — no regressions triggered

## 2. Pass with Risk

1. Core contract obligations are met
2. Residual risk is explicitly documented and tracked
3. Risk does not violate any system invariant
4. Risk owner is identified

## 3. Fail

ANY of the following is a blocking failure:
1. A contract obligation is not met
2. A system invariant is violated
3. Tests pass but contract is not satisfied (tests don't cover the contract)
4. Fail-closed behavior is bypassed
5. Source of truth ownership is breached

## 4. Insufficient Evidence

1. No clear proof that the contract is satisfied OR violated
2. Code reading alone is not sufficient evidence — need runtime proof
3. Must escalate for additional evidence collection or contract clarification

## 5. Evidence Rules

1. **No evidence = no completion claim** — "I think it works" is not evidence
2. **Code reading supplements but doesn't replace runtime evidence**
3. **Tests must map to contract items** — untargeted test suites don't prove contract satisfaction
