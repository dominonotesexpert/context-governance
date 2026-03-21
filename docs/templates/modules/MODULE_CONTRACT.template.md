---
artifact_type: module-contract
status: proposed
owner_role: module-architect
scope: module
module: "[module-name]"
downstream_consumers: [implementation, verification, debug]
last_reviewed: 2026-03-20
derived_from_baseline_version: "v0.0"
derivation_type: structural
verified: pending
derived_sections: []
upstream_business_sources: []
business_semantics_impact: none
---

# MODULE_CONTRACT: [module-name]

**Status:** proposed
**Owner:** Module Architect Agent
**Last Updated:** YYYY-MM-DD
**Derived From:** PROJECT_BASELINE §3 (Core Capabilities) via SYSTEM_GOAL_PACK

> ⚠ This is a **derived document**. Module responsibilities map to BASELINE core capabilities.
> To change module scope, update PROJECT_BASELINE §3 and re-derive through the chain.
> If a proposed boundary or contract would reinterpret a capability or business rule, escalate as a business-semantics question rather than silently finalizing the decision.

---

## 1. Responsibility

<!-- One sentence: what does this module provide to the system? -->

## 2. Boundaries

<!-- What this module owns and what it does NOT own -->
<!-- - Owns: ... -->
<!-- - Does NOT own: ... -->
<!-- - Peer modules: ... -->

## 3. Inputs

<!-- Exhaustive list of what flows into this module -->
<!-- - Source A: description -->
<!-- - Source B: description -->

## 4. Outputs

<!-- Exhaustive list of what this module produces -->
<!-- - Output A: description + who consumes it -->
<!-- - Output B: description + who consumes it -->

## 5. Upstream Dependencies

<!-- What this module depends on -->
<!-- - Module/service A: provides X -->
<!-- - Module/service B: provides Y -->

## 6. Downstream Consumers

<!-- Who depends on this module's outputs? -->
<!-- - Consumer A: uses Output X for purpose Y -->

## 7. Shared Interfaces

<!-- Data structures, APIs, or contracts shared with other modules -->
<!-- - InterfaceName: shared between this module and Module X -->
<!-- If none, state "No shared interfaces" -->

## 8. Invariants

<!-- Module-specific rules that must never be violated -->
<!-- Reference system invariants where applicable (e.g., INV-001) -->

## 9. Breaking Change Policy

<!-- What constitutes a breaking change for this module's consumers? -->
<!-- Who must be notified? What coordination is required? -->

## 10. Verification Expectations

<!-- What should verification focus on for this module? -->
<!-- - Key test scenarios -->
<!-- - Critical failure paths -->
<!-- - Evidence types needed -->
