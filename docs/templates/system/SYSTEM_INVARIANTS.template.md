---
artifact_type: system-invariants
status: proposed
owner_role: system-architect
scope: system
downstream_consumers: [module-architect, implementation, verification, debug, frontend-specialist]
last_reviewed: 2026-03-20
derived_from_baseline_version: "v0.0"
derivation_type: interpretive
verified: pending
derived_sections: []
---

# SYSTEM_INVARIANTS

**Status:** proposed
**Owner:** System Architect Agent
**Last Updated:** YYYY-MM-DD
**Derived From:** PROJECT_BASELINE §4 (Business Rules)

> ⚠ This is a **derived document**. Invariants are translated from BASELINE business rules.
> Structural derivations are auto-verified. Interpretive derivations require user confirmation.
> To change invariants, update PROJECT_BASELINE §4 and re-derive.

---

## 1. Purpose

Hard rules that no agent, no document, no code change may violate. If an invariant needs to change, only the System Architect can approve it — and the change must be recorded in the Conflict Register.

## 2. Invariants

### INV-001: [Name]

- **Baseline Source:** PROJECT_BASELINE §4.X
- **Derivation Type:** structural | interpretive
- **Verified:** auto | user_confirmed
- **Invariant:** <!-- State the invariant clearly and concisely. One sentence if possible. -->
<!-- Example: "All features must ship at production quality. No MVP, POC, or prototype shortcuts." -->

### INV-002: [Name]

- **Baseline Source:** PROJECT_BASELINE §4.X
- **Derivation Type:** structural | interpretive
- **Verified:** auto | user_confirmed
- **Invariant:** <!-- "Code is evidence, not truth." -->

### INV-003: [Name]

- **Baseline Source:** PROJECT_BASELINE §4.X
- **Derivation Type:** structural | interpretive
- **Verified:** auto | user_confirmed
- **Invariant:** <!-- "Downstream agents may not silently rewrite upstream truth." -->

<!-- Add more invariants as needed. Keep the list short and non-negotiable. -->
