---
artifact_type: verification-oracle
status: proposed
owner_role: verification
scope: verification
downstream_consumers: [implementation]
last_reviewed: 2026-03-20
derived_from_baseline_version: "v0.0"
derivation_type: structural
verified: pending
derived_sections: []
---

# VERIFICATION_ORACLE: [module-name]

**Status:** proposed
**Owner:** Verification Agent
**Last Updated:** YYYY-MM-DD
**Derived From:** MODULE_CONTRACT.md, MODULE_BOUNDARY.md, SYSTEM_INVARIANTS.md, ACCEPTANCE_RULES.md (all ultimately traceable to PROJECT_BASELINE and BASELINE_INTERPRETATION_LOG)

> ⚠ This is a **derived document**. Oracle items map to contract obligations which trace back to BASELINE.
> To change verification checks, update the upstream contract or invariant and re-derive.
> Oracle items tied to business acceptance semantics require the confirmed interpretation from BASELINE_INTERPRETATION_LOG.

---

## 1. Scope

This oracle maps contract obligations from `MODULE_CONTRACT: [module-name]` to explicit verification checks.

## 2. Oracle Items

> Oracle items fall into two categories:
> - **Business-semantic checks**: tied to ACCEPTANCE_RULES Layer 1 (business acceptance semantics). These verify that the confirmed business meaning is achieved.
> - **Technical obligation checks**: tied to ACCEPTANCE_RULES Layer 2 (technical verification gates). These verify contract compliance.

### [ID]-O1: [Contract Obligation Name]

**Contract Source:** MODULE_CONTRACT §X
**Oracle Type:** business-semantic | technical-obligation
**What to Verify:**
<!-- Specific observable behavior that proves the obligation is met -->

**Failure Signals:**
<!-- What would prove the obligation is NOT met? -->

**Evidence Required:**
<!-- What kind of proof? Test output, runtime log, diagnostic event? -->

### [ID]-O2: [Contract Obligation Name]

<!-- Repeat for each major contract obligation -->

<!-- TIP: Every oracle item should be independently verifiable. -->
<!-- If you can't describe what failure looks like, the oracle item is too vague. -->
