# Production Contract Patterns

This guide explains which governance patterns were distilled from a real, long-running AI-assisted production system, how they differ from the original open-source templates, and how to reuse them without copying product-specific architecture.

## The Convergence

The original framework correctly separated baseline, contracts, implementation, and verification, but it treated the role chain as universal ceremony. The production system evolved a more precise rule:

> Context gates are mandatory. Process-heavy roles and artifacts are triggered by risk.

| Concern | Earlier generic rule | Production-proven rule | Reusable contract |
|---|---|---|---|
| Task entry | Route by task label | Load system truth first; load module truth for concrete modules | `ROUTING_POLICY` context gates |
| Bug work | Every bug creates a DEBUG_CASE and ends in formal Verification | A local, low-risk bug may execute directly after its root cause is proven; cross-stage or ambiguous incidents use formal Debug | `debug_required` plus routing reason |
| Evidence | Facts, inference, and disproven ideas are separated | Root cause also needs an authoritative design anchor and an observed code/log/test anchor | Double-Anchor Rule |
| Architecture drift | Code is evidence, not truth | Observed state must not be promoted into identity, ownership, lifecycle, or canonical truth | Authority Diff |
| Scope | Record in/out of scope | Every changed behavior must trace to the authorized outcome; delete adjacent design | Scope Lock and Scope Diff |
| New blockers | Fail closed for safety | A blocker is legal only when removing it would produce a proven incorrect or unsafe outcome | Blocking Gate Proof and Deletion Counterfactual |
| Repeated bugs | Register reusable bug classes | Fix the failure family at its owning layer; do not accumulate instance-specific branches | Family-Level Fix Scope Gate |
| Verification | One formal final role for every task | Evidence is always required; formal Verification is triggered for release, deploy, security, cross-module, live, or explicit acceptance | Layered evidence strategy |

## Minimum Governed Architecture

A project does not need every template on day one. It needs a small core whose authority is explicit:

1. **Project baseline** — product purpose, business rules, success, and exclusions.
2. **Authority map** — which artifact wins when sources disagree.
3. **System invariants** — truths implementation convenience may not violate.
4. **Module contracts** — ownership, inputs, outputs, observation-only data, and forbidden authority promotions.
5. **Scope lock** — the one authorized outcome, permitted change surface, and exclusions.
6. **Verification oracle** — observable evidence that proves the requested outcome.

The governing question is not only “What information can the agent see?” It is:

> What is this role authorized to decide, and what new authority would this solution introduce?

## Authority Model

Use three lanes in every non-trivial design or incident:

| Lane | Examples | What it may do | What it may not do |
|---|---|---|---|
| Canonical truth | baseline, invariant, architecture decision, module contract | Define meaning, ownership, legal states, and boundaries | Be silently rewritten by downstream implementation |
| Observation | code, logs, tests, screenshots, DOM, runtime measurements | Locate failure, falsify hypotheses, prove conformance or drift | Become canonical identity or architecture merely because it is convenient |
| Execution authority | active role and task scope | Choose an implementation inside its contract | Invent ownership, state, gates, or requirements outside its authority |

When code does not match an active contract, investigate implementation drift first. Do not invent a story that makes the code authoritative.

## Proportionate Routing

The default route is context loading, not a mandatory procession of agents:

```text
System context
    -> Module context, when a concrete module is involved
        -> direct execution for routine, locally proven work
        -> Debug for cross-stage, production, repeated, or ambiguous failures
        -> formal Verification for release, deploy, security, cross-module, live, or explicit acceptance
```

A bug may use the routine path only when all of these are true:

- the owning module and contract are clear;
- the root cause is directly supported by a cited observation;
- no canonical truth or module boundary needs reinterpretation;
- the change is local and low risk;
- proportionate tests can prove the result.

An unclassified bug defaults to formal Debug. A downgrade is an explicit governance decision, never an accidental omission.

## Debug Proof Contract

Formal Debug begins with an Active Baseline Lock:

- active authoritative constraints;
- retired or non-authoritative concepts;
- observed facts;
- inference;
- disproven hypotheses;
- allowed root-cause search space.

A confirmed root cause requires two independent anchors:

1. **Authority anchor** — the contract, invariant, or approved design that defines expected behavior.
2. **Observation anchor** — code, log, test, runtime, or rendered evidence showing the actual failure.

Neither anchor is sufficient alone. A document-only explanation may not prove the implementation failed. A code-only explanation may merely rationalize architectural drift.

## Blocking Gate Proof

Before adding a validator, retry, fail-closed branch, admission rule, or new lifecycle state, write:

1. the exact correct user or business outcome it protects;
2. the concrete incorrect or unsafe result without the blocker;
3. evidence that the failure is reachable;
4. why a warning, log, ignore rule, or existing downstream owner is insufficient;
5. why this stage owns the decision.

Then remove the proposed blocker on paper and trace the minimum successful path. If the result remains correct, the condition is diagnostic or warning-level—not blocking.

## Layered Verification Evidence

Choose evidence according to the claim:

- **localized change:** focused regression test and the relevant existing suite;
- **repeated failure class:** incident pin plus family/corpus replay where representative artifacts exist;
- **cross-module change:** contract checks at each affected handoff;
- **release or deploy:** build/package proof plus environment-specific acceptance;
- **reported live failure:** reproduce the exact user path in the affected environment after deployment.

Never use equal failure counts as proof. Compare failure identities, preserve exclusions explicitly, and label unavailable evidence as unavailable instead of silently dropping it.

## What Was Deliberately Not Generalized

The production system contains domain-specific identities, document modes, generated-artifact formats, runtime admission metrics, deployment tools, and corpus paths. Those are evidence that the generic patterns work; they are not portable contracts.

This framework therefore generalizes:

- authority and provenance lanes;
- risk-triggered routing;
- baseline locks and double anchors;
- scope and blocker proofs;
- failure-family repair;
- evidence selection.

It does not copy product names, internal data models, thresholds, URLs, or release commands into the reusable templates.
