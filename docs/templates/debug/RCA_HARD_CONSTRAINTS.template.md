---
artifact_type: rca-hard-constraints
status: proposed
owner_role: system-architect
scope: debug
downstream_consumers: [debug, implementation, verification]
last_reviewed: YYYY-MM-DD
---

# RCA Hard Constraints

Use this contract when the routing policy activates formal Debug. Routine, locally proven bugs do not require a DEBUG_CASE, but they still require a cited root-cause observation and proportionate evidence.

## 1. Active Baseline Lock

Record before declaring root cause:

- **Active authoritative constraints:** current contracts, invariants, architecture, and approved decisions.
- **Retired/non-authoritative concepts:** old plans, workarounds, stale docs, or superseded designs.
- **Observed facts:** code, logs, tests, runtime, screenshots, rendered state, or artifacts.
- **Inference:** plausible but unproven explanations.
- **Disproven hypotheses:** explanations falsified by evidence.
- **Allowed RCA space:** layers and decisions this role is authorized to investigate.

If current code conflicts with an active contract, test implementation drift first. Do not invent intent that promotes the code into architecture.

## 2. Double-Anchor Rule

`Confidence: confirmed` requires both:

1. **Authority anchor:** an exact active contract, invariant, or approved design reference that defines expected behavior.
2. **Observation anchor:** code, log, test, runtime, or rendered evidence proving the actual behavior and failing hop.

Document-only and observation-only conclusions remain inference.

## 3. Authority Diff

Every proposed fix must state:

- authority owners before the change;
- authority owners after the change;
- whether observation becomes identity, ownership, state, schema, eligibility, or canonical truth;
- whether a new source of truth, fallback owner, gate, or lifecycle state is introduced.

If authority changes, stop implementation and raise an architecture/contract proposal to the owning upstream role.

## 4. Family-Level Fix Scope Gate

Before approving a local repair:

- list the observed failure shapes;
- state the shared violated invariant or prove they are different bugs;
- identify the owning layer;
- reject production branching on incidental labels, wrapper names, item positions, or individual examples when a deterministic invariant can repair the family;
- add a recurrence test or bug-class rule when the failure pattern is reusable.

## 5. Blocking Gate Proof

Before adding or strengthening a gate, validator, retry, fail-closed branch, or lifecycle state, record:

1. the exact correct user/business outcome protected;
2. the concrete incorrect or unsafe result without the blocker;
3. evidence proving the failure is reachable;
4. why warning, logging, ignoring stage-irrelevant data, or the existing downstream owner is insufficient;
5. why the selected stage owns the decision.

Run the **Deletion Counterfactual**: remove the blocker and trace the minimum successful path. If the result remains correct, the condition is debug or warning evidence—not blocking.

## 6. Evidence Labels

- `debug` — investigation evidence only;
- `warning` — an observable limitation that does not make the requested result incorrect;
- `blocking` — continuing produces a proven incorrect or unsafe result.

Do not promote between levels without new evidence and, for blocking, a completed Blocking Gate Proof.
