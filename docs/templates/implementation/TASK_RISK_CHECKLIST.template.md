---
artifact_type: task-risk-checklist
status: proposed
owner_role: implementation
scope: task
downstream_consumers: [verification]
last_reviewed: 2026-03-20
---

# TASK_RISK_CHECKLIST: [task-name]

**Date:** YYYY-MM-DD
**Task:** <!-- link to TASK_EXECUTION_PACK -->

---

## 1. Contract Risks

- [ ] Does this change respect the module contract's "excluded responsibilities"?
- [ ] Does this change require updating the module contract?
- [ ] Does this change affect any system invariant?

## 2. Boundary Risks

- [ ] Does this change stay within the module boundary?
- [ ] Does this change affect upstream or downstream module interfaces?
- [ ] Could this change introduce responsibility drift?

## 3. Regression Risks

- [ ] Have you checked the module's REGRESSION_MATRIX for matching regression classes?
- [ ] Does this change touch any code path listed in a known regression trigger?
- [ ] Are existing tests sufficient to detect regression, or do new tests need to be added?

## 4. Truth Artifact Risks

- [ ] Do any canonical workflow/dataflow maps need updating after this change?
- [ ] Does any system scenario map need updating?
- [ ] Does the verification oracle need a new check item?

## 5. Evidence Risks

- [ ] Is there a way to verify this change with runtime evidence (not just code reading)?
- [ ] Are there logs, diagnostics, or test outputs that will confirm correctness?
- [ ] If evidence is insufficient, what additional diagnostics should be added?

## 6. Rollback Plan

- [ ] Can this change be reverted without side effects?
- [ ] Is there a safe fallback if the change causes unexpected behavior?
