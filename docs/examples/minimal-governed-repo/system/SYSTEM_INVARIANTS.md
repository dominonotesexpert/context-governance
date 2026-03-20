---
artifact_type: system-invariants
status: active
owner_role: system-architect
scope: system
downstream_consumers: [module-architect, implementation, verification, debug]
last_reviewed: 2026-03-20
derived_from_baseline_version: "v1.0"
derivation_type: interpretive
verified: user_confirmed
derived_sections:
  - baseline_section: "§4.1"
    target_section: "INV-001"
    derivation_type: interpretive
    verified: user_confirmed
  - baseline_section: "§4.3"
    target_section: "INV-002"
    derivation_type: interpretive
    verified: user_confirmed
---

# SYSTEM_INVARIANTS

**Status:** active
**Derived From:** PROJECT_BASELINE §4 (Business Rules)

> ⚠ This is a **derived document**. Invariants are translated from BASELINE business rules.
> To change invariants, update PROJECT_BASELINE §4 and re-derive.

## 1. Purpose
Hard rules that no agent, no document, no code change may violate.

## 2. Invariants

### INV-001: Fail-Closed Authentication

- **Baseline Source:** PROJECT_BASELINE §4 "People without permission must never see or modify other people's content"
- **Derivation Type:** interpretive
- **Verified:** user_confirmed
- **Invariant:** All authentication checks must fail-closed. If the auth service is unavailable or returns an ambiguous response, deny access.

### INV-002: Input Validation at Boundaries

- **Baseline Source:** PROJECT_BASELINE §4 "When something goes wrong, tell the user clearly"
- **Derivation Type:** interpretive
- **Verified:** user_confirmed
- **Invariant:** All external input (API requests, WebSocket messages) must be validated before processing. No raw user input reaches business logic.

### INV-003: Code is Evidence, Not Truth

- **Baseline Source:** (governance framework invariant, not project-specific)
- **Derivation Type:** structural
- **Verified:** auto
- **Invariant:** When code contradicts docs/agents/ artifacts, the artifacts are authoritative. Code shows what IS, not what SHOULD BE.

### INV-004: Downstream Never Rewrites Upstream

- **Baseline Source:** (governance framework invariant, not project-specific)
- **Derivation Type:** structural
- **Verified:** auto
- **Invariant:** If implementation discovers a contract gap, escalate to Module Architect. Do not silently "fix" the truth in code.
