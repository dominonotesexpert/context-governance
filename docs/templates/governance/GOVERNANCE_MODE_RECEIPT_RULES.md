# Governance Mode × Receipt Interaction Rules

**Authority:** `docs/plans/2026-03-24-deerflow-inspired-governance-engine-plan.md` §3.7

---

## Purpose

Receipt validation must read the active governance mode as an input. Different modes alter which receipt claims are required, deferred, or suspended.

---

## Mode: `steady-state` (default)

All receipt rules apply as defined in `TASK_RECEIPT.schema.yaml`:

- Required claims per task type are enforced
- All evidence_refs must exist and be fresh
- Stale upstream artifacts block acceptance
- No exceptions

---

## Mode: `incident`

**Context:** Active incident requiring rapid response. Speed is prioritized.

Receipt rules:
- Receipt creation is **required** but may be partial
- Required claims may be **deferred** — receipt must record deferred items:
  ```yaml
  governance_claims:
    debug_case_present: false  # deferred to post-incident review
    module_contract_refs:
      - docs/agents/modules/auth/MODULE_CONTRACT.md
  deferred_claims:
    - debug_case_present
  deferred_reason: "Active incident P1-20260325, DEBUG_CASE deferred to post-incident review"
  ```
- Deferred items **must be completed** during post-incident review
- CI marks deferred claims as warnings, not blockers
- Post-incident review must produce a follow-up receipt or update the original

---

## Mode: `exploration`

**Context:** Investigating approaches before committing to a design direction.

Receipt rules:
- Receipts may reference `draft` or `proposed` artifacts
- Receipts must **not** treat draft artifacts as promoted `active` truth
- Evidence refs should include a note when pointing to draft material:
  ```yaml
  evidence_refs:
    - path: docs/agents/modules/search/MODULE_CONTRACT.md
      kind: module_contract
      upstream_hash: null
      note: "draft — not yet promoted to active truth"
  ```
- Work produced under exploration mode cannot merge to protected branches without mode transition to `steady-state` and evidence promotion

---

## Mode: `exception`

**Context:** A governance rule is intentionally suspended for a scoped reason.

Receipt rules:
- Receipts must explicitly record **which claims are absent** and **why**:
  ```yaml
  governance_claims:
    module_contract_refs: []
  exception_claims:
    - claim: module_contract_refs
      reason: "Module contract does not yet exist; approved exception per GOVERNANCE_MODE entry"
      governance_mode_ref: "docs/agents/execution/GOVERNANCE_MODE.md#exception-2026-03-25"
  ```
- Exception scope must match what `GOVERNANCE_MODE.md` declares
- CI validates that exception claims reference a valid governance mode entry
- Exception receipts cannot be used to bypass claims outside the declared exception scope

---

## Mode: `migration`

**Context:** Controlled transition between governance states (e.g., schema upgrade, authority restructuring).

Receipt rules:
- Receipts may record **scoped deviations** within the declared migration envelope:
  ```yaml
  migration_deviations:
    - deviation: "upstream_hash validation suspended for MODULE_CONTRACT during schema v1→v2 migration"
      migration_ref: "docs/agents/execution/GOVERNANCE_MODE.md#migration-2026-03-25"
      scope: "docs/agents/modules/*/MODULE_CONTRACT.md"
  ```
- Deviations must be scoped — cannot be blanket exceptions
- Migration envelope is defined in `GOVERNANCE_MODE.md`
- Deviations outside the declared envelope are treated as violations
- When migration completes, all deviations must be resolved

---

## Validation Logic for `check-task-receipt.sh`

```
1. Read governance mode from docs/agents/execution/GOVERNANCE_MODE.md
2. If mode = steady-state:
     enforce all required claims strictly
3. If mode = incident:
     allow deferred_claims if deferred_reason is present
     warn on deferred items, do not block
4. If mode = exploration:
     allow draft evidence_refs
     block merge to protected branches unless promoted
5. If mode = exception:
     allow exception_claims if governance_mode_ref exists and is valid
     block claims outside declared exception scope
6. If mode = migration:
     allow migration_deviations if migration_ref exists and scope matches
     block deviations outside declared migration envelope
```

---

## Principle

Governance modes modify the **enforcement timing and strictness** of receipt validation. They never eliminate the requirement for eventual compliance. Deferred, excepted, or migrating claims must ultimately be resolved.
