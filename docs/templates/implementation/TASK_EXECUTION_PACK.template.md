---
artifact_type: task-execution-pack
status: proposed
owner_role: implementation
scope: task
downstream_consumers: [verification]
last_reviewed: 2026-03-20
---

# TASK_EXECUTION_PACK: [task-name]

**Status:** proposed
**Owner:** Implementation Agent
**Date:** YYYY-MM-DD
**Module:** <!-- target module name -->
**Upstream Artifacts:**
- <!-- MODULE_CONTRACT.md reference -->
- <!-- DEBUG_CASE reference (when formal Debug was triggered) -->

---

## 1. Task Summary

<!-- One paragraph: what needs to be done and why -->

## 2. Scope

### Scope Lock

- **Authorized outcome:** <!-- The one result requested -->
- **Allowed change surface:** <!-- Files/modules/data/behaviors allowed to change -->
- **Explicit exclusions:** <!-- Report-only or unchanged items -->
- **Smallest owning-layer change:** <!-- The minimum change that fully achieves the outcome -->

### In Scope
<!-- Specific changes to make -->
1. <!-- Change 1 -->
2. <!-- Change 2 -->

### Out of Scope
<!-- What this task explicitly does NOT include -->
1. <!-- Exclusion 1 -->

## 3. Contract Alignment

<!-- Which module contract items does this task address? -->
- CONTRACT §X: <!-- how this task satisfies it -->
- INVARIANT INV-00X: <!-- how this task respects it -->

### Authority Model

- **Canonical truth consulted:** <!-- Baseline/architecture/module contract -->
- **Observation-only evidence:** <!-- Code/log/test/runtime/UI inputs -->
- **Decisions this task may make:** <!-- Implementation choices inside the contract -->
- **Forbidden authority promotions:** <!-- Observation must not become identity/ownership/state/schema/truth -->

### Proposed Authority Diff

- **New source of truth introduced?:** no | yes — <!-- if yes, stop and escalate -->
- **Ownership/state/identity/gate changes?:** no | yes — <!-- if yes, cite approved upstream proposal -->

## 4. Implementation Steps

1. <!-- Step 1: specific file + function + change -->
2. <!-- Step 2 -->
3. <!-- Step 3 -->

## 5. Verification Targets

<!-- What must be verified after implementation? -->
1. <!-- Target 1: what to test, how to test -->
2. <!-- Target 2 -->

## 6. Risk Assessment

<!-- What could go wrong? -->
- **Risk 1:** <!-- description --> → **Mitigation:** <!-- how to prevent -->

### Blocking Gate Proof (only when adding a blocker)

- **Correct outcome protected:** <!-- -->
- **Concrete incorrect/unsafe result without it:** <!-- -->
- **Reachability evidence:** <!-- -->
- **Why warning/ignore/existing downstream owner is insufficient:** <!-- -->
- **Deletion Counterfactual:** <!-- Remove it and trace the minimum successful path -->

## 7. Required Truth Updates

<!-- Do any artifacts need updating after this task? -->
- [ ] Module canonical workflow/dataflow maps
- [ ] System scenario map
- [ ] Verification oracle
- [ ] None required

## 8. Scope Diff Before Completion

- **Changed concepts/files:** <!-- Exact list -->
- **Removed as adjacent/speculative:** <!-- Anything excluded before delivery -->
- **Every remaining change traces to:** user outcome | confirmed root cause | higher-authority requirement
