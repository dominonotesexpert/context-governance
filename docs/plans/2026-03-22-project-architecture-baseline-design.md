# Project Architecture Baseline Design

**Date:** 2026-03-22
**Status:** Proposed
**Depends on:** `2026-03-21-business-semantics-confirmation-design.md`, `2026-03-21-open-risks-validation-design.md`, `2026-03-22-open-risks-implementation-plan.md`
**Scope:** Add a user-owned architectural baseline that constrains top-level system structure, while preserving Tier 2 as a derived detailed architecture layer rather than replacing it.

## 1. Problem

The framework currently has a real structural gap:

- `PROJECT_BASELINE` is user-owned business truth
- downstream artifacts are technical derivations
- `SYSTEM_AUTHORITY_MAP` reserves Tier 2 for top-level architecture, but no authoritative upstream architecture source exists yet

That means the most unstable layer in the system is still mostly open-ended:

- different models can derive different system topologies from the same business baseline
- module boundaries can drift because nothing upstream fixes the architectural floor
- canonical workflows and dataflows can become downstream guesses instead of constrained derivations
- users cannot specify "this system must basically be shaped like this" without polluting `PROJECT_BASELINE` with technical design

This is not a minor gap. It is a direct expression of Risk 3.1 (`derivation instability`) from the open-risks design: the same upstream truth can yield materially different technical derivations unless the derivation envelope is tightened.

## 2. Decision Summary

This design adopts the following model:

1. Add `PROJECT_ARCHITECTURE_BASELINE.md` as a new **Tier 0.8** user-owned structural truth artifact
2. Keep **Tier 2** as the architecture layer, but define it explicitly as a **derived** artifact:
   - `SYSTEM_ARCHITECTURE.md`
3. Require `SYSTEM_ARCHITECTURE.md` to derive from:
   - `PROJECT_BASELINE`
   - `BASELINE_INTERPRETATION_LOG`
   - `PROJECT_ARCHITECTURE_BASELINE`
   - `SYSTEM_GOAL_PACK`
   - `ENGINEERING_CONSTRAINTS`
4. Forbid downstream agents from directly rewriting `PROJECT_ARCHITECTURE_BASELINE`
5. Allow agents to challenge the architecture baseline only through an explicit proposal mechanism requiring user confirmation

This resolves the Tier 0.8 vs Tier 2 conflict by giving each tier a distinct role:

- Tier 0.8 = user-owned architectural floor
- Tier 2 = detailed architecture derived inside that floor

## 3. Authority Model

### 3.1 Revised authority chain

The upstream chain becomes:

1. `PROJECT_BASELINE` (Tier 0)
2. `BASELINE_INTERPRETATION_LOG` (Tier 0.5)
3. `PROJECT_ARCHITECTURE_BASELINE` (Tier 0.8)
4. `SYSTEM_GOAL_PACK` (Tier 1)
5. `ENGINEERING_CONSTRAINTS` (Tier 1.5)
6. `SYSTEM_ARCHITECTURE` (Tier 2)
7. `SYSTEM_INVARIANTS` (Tier 3)
8. `MODULE_CONTRACT` and module canonical artifacts (Tier 4)
9. verification artifacts and implementation evidence downstream

### 3.2 Authority responsibilities

`PROJECT_BASELINE` owns:

- product definition
- target users
- core capabilities
- non-negotiable business rules
- success criteria
- out-of-scope boundaries

`BASELINE_INTERPRETATION_LOG` owns:

- user-confirmed clarification of ambiguous business semantics
- resolution of business forks that cannot be derived mechanically

`PROJECT_ARCHITECTURE_BASELINE` owns:

- system topology
- key architectural decisions
- non-negotiable structural boundaries
- a very small number of canonical workflows
- a very small number of canonical data flows

It does **not** own:

- detailed module contracts
- implementation-level interface definitions
- file/class/function structure
- detailed runtime diagnostics
- dependency/version pinning
- migration instructions

`SYSTEM_ARCHITECTURE` owns:

- the detailed, derived architecture expansion of the user's structural baseline
- explicit architectural decomposition under the upstream envelope
- architecture-level implications of engineering constraints
- architecture-level traceability for downstream module derivation

It is **not** user-owned root truth. It is derived architecture and may be re-derived when upstream changes.

## 4. Why Tier 0.8 and Tier 2 Both Exist

This design rejects both extremes:

- putting user architecture directly into Tier 2
- replacing Tier 2 entirely with a user document

Those options collapse two different concerns into one artifact:

- the user's architectural floor
- the system's detailed technical expansion

That collapse would either:

- force the user to maintain too much detail, or
- let the AI reclaim too much freedom

The correct split is:

- `PROJECT_ARCHITECTURE_BASELINE` = simple, durable, authoritative
- `SYSTEM_ARCHITECTURE` = derived, detailed, traceable, reviewable

This preserves the value of the existing Tier 2 slot in `SYSTEM_AUTHORITY_MAP` while fixing the missing upstream source problem.

## 5. Boundary Rules

### 5.1 `PROJECT_ARCHITECTURE_BASELINE` allowed content

It may contain only:

1. `System Topology`
   - one high-level Mermaid system diagram
2. `Key Architectural Decisions`
   - 3 to 7 structural choices
3. `Non-Negotiable Structural Boundaries`
   - 3 to 7 rules
4. `Canonical Workflows`
   - 1 to 3 critical workflows
5. `Canonical Data Flows`
   - 1 to 3 critical data flows

### 5.2 forbidden content

It must not contain:

- detailed API contracts
- code-level interfaces
- files, functions, classes, or line references
- migration plans
- dependency or version pinning
- low-level implementation details
- exhaustive architecture narrative

### 5.3 enforcement mechanism for lightness

The lightness constraint must be enforced by mechanism, not advice.

The framework must therefore add a validation rule:

1. `bootstrap-project.sh --validate` checks `PROJECT_ARCHITECTURE_BASELINE.md`
2. the validator counts:
   - non-frontmatter, non-empty body lines
   - Mermaid blocks
3. the validator fails if:
   - body content exceeds 50 lines
   - Mermaid block count exceeds 2
4. `BOOTSTRAP_READINESS` marks the project `blocked` for architectural derivation if the artifact exceeds these limits
5. System Architect must not derive `SYSTEM_ARCHITECTURE` from an invalid architecture baseline

This directly resolves the criticism that a `<= 50 lines` rule would otherwise be wishful documentation.

## 6. Conflict Rules

### 6.1 `PROJECT_BASELINE` vs `PROJECT_ARCHITECTURE_BASELINE`

If they conflict, `PROJECT_BASELINE` wins.

Reason:

- business truth outranks structure truth
- structure cannot narrow or redefine product meaning by itself

### 6.2 `BASELINE_INTERPRETATION_LOG` vs `PROJECT_ARCHITECTURE_BASELINE`

This boundary must be precise.

Use the following classification rule:

If the disputed clause changes or implies:

- capability meaning
- scope inclusion/exclusion
- success criteria meaning
- failure-handling promise
- business-facing degradation semantics

then it is a **business-semantic issue**, and Tier 0 / 0.5 wins.

If the disputed clause only constrains:

- topology
- component decomposition
- allowed call paths
- allowed data paths
- structural separation of responsibilities

then it is a **structural issue**, and Tier 0.8 wins downstream.

If a clause mixes business semantics and structure in one statement, the clause is malformed and must be split. System Architect must not silently choose one interpretation. The user must confirm the split through the normal clarification / proposal path.

This resolves the earlier ambiguity around "business-semantic meaning wins" by defining a concrete classification rule instead of a vague override slogan.

### 6.3 `ENGINEERING_CONSTRAINTS` vs `PROJECT_ARCHITECTURE_BASELINE`

`ENGINEERING_CONSTRAINTS` may prove that the architecture baseline is:

- infeasible
- too risky
- contradictory with external realities

But it may not rewrite Tier 0.8 directly.

Required behavior:

1. detect conflict
2. raise an architecture change proposal
3. present evidence and options
4. wait for user confirmation before editing the architecture baseline

### 6.4 code vs architecture truth

Code remains evidence only.

If runtime behavior differs from `PROJECT_ARCHITECTURE_BASELINE` or `SYSTEM_ARCHITECTURE`, that is:

- architectural drift
- or a candidate upstream error

It is not automatic proof that the upstream architecture truth should be rewritten.

## 7. Derived Tier 2 Artifact: `SYSTEM_ARCHITECTURE.md`

### 7.1 purpose

Add a new Tier 2 artifact:

`SYSTEM_ARCHITECTURE.md`

This document is the detailed architecture expansion of upstream truth. It exists so the system can:

- preserve user control over the architectural floor
- still generate the richer structure needed by downstream roles

### 7.2 derivation sources

`SYSTEM_ARCHITECTURE.md` derives from:

- `PROJECT_BASELINE`
- `BASELINE_INTERPRETATION_LOG`
- `PROJECT_ARCHITECTURE_BASELINE`
- `SYSTEM_GOAL_PACK`
- `ENGINEERING_CONSTRAINTS`

Notably:

- `SYSTEM_GOAL_PACK` remains a business-to-technical goal translation artifact
- it does **not** become the owner of architecture-baseline meaning
- architecture truth is injected at Tier 2, not silently back-propagated into Tier 1

This resolves the earlier design flaw where `SYSTEM_GOAL_PACK` was implicitly gaining a third upstream source without clear derivation or staleness implications.

### 7.3 metadata and staleness

Because `SYSTEM_ARCHITECTURE.md` is a derived artifact, it must participate fully in the derivation-fingerprinting model:

- `derivation_context`
- staleness detection
- `DERIVATION_REGISTRY`
- visible diff review on re-derivation

In addition to the existing derivation metadata pattern, `SYSTEM_ARCHITECTURE.md` must record both:

- `derived_from_baseline_version`
- `derived_from_architecture_baseline_version`

Staleness for Tier 2 must trigger when any of its upstreams change, including Tier 0.8.

### 7.4 required frontmatter

The new artifacts must define `downstream_consumers` explicitly rather than leaving consumer scope implicit.

Required frontmatter for `PROJECT_ARCHITECTURE_BASELINE.md`:

```yaml
artifact_type: project-architecture-baseline
status: active
owner_role: user
scope: system
downstream_consumers: [system-architect]
authority_tier: 0.8
last_reviewed: YYYY-MM-DD
```

Required frontmatter for `SYSTEM_ARCHITECTURE.md`:

```yaml
artifact_type: system-architecture
status: proposed
owner_role: system-architect
scope: system
downstream_consumers: [module-architect, implementation, verification, debug, frontend-specialist]
last_reviewed: YYYY-MM-DD
derived_from_baseline_version: "v0.0"
derived_from_architecture_baseline_version: "v0.0"
derivation_context:
  model_id: ""
  context_window: ""
  prompt_version: ""
  derivation_timestamp: ""
  upstream_hash: ""
```

Required frontmatter for `ARCHITECTURE_CHANGE_PROPOSAL.md`:

```yaml
artifact_type: architecture-change-proposal
status: proposed
owner_role: system-architect
scope: system
downstream_consumers: [system-architect, module-architect, implementation, verification, debug]
last_reviewed: YYYY-MM-DD
```

## 8. Change Proposal Mechanism

### 8.1 new artifact

Add:

`ARCHITECTURE_CHANGE_PROPOSAL.md`

This artifact records proposed changes to `PROJECT_ARCHITECTURE_BASELINE`.

### 8.2 when it is required

It is mandatory when an agent finds:

- structural contradiction
- technical infeasibility
- engineering-constraint conflict
- inability to satisfy upstream goals within the current architectural floor

### 8.3 what agents may and may not do

Agents may:

- identify problems
- provide evidence
- present options
- recommend a change

Agents may not:

- directly edit `PROJECT_ARCHITECTURE_BASELINE`
- reinterpret its boundaries through downstream artifacts
- silently change Tier 2 or module contracts in ways that effectively rewrite Tier 0.8

### 8.4 update flow

1. Agent detects issue
2. Agent writes proposal entry
3. User approves or rejects
4. If approved, Tier 0.8 is updated
5. System Architect re-derives Tier 2 and affected downstream artifacts
6. `DERIVATION_REGISTRY` updates after verification

### 8.5 authority-map position

`ARCHITECTURE_CHANGE_PROPOSAL.md` must be registered in `SYSTEM_AUTHORITY_MAP` as a **meta-artifact outside the authority tier chain**, not as a tier participant.

Reason:

- it governs how architectural truth may be challenged
- it does not itself become architectural truth
- it must never outrank or silently replace Tier 0.8

It should sit alongside other process-support artifacts such as `DERIVATION_REGISTRY`, not inside Tier 0.8, Tier 2, or Tier 5 truth layers.

## 9. Governance Mode Rules

`PROJECT_ARCHITECTURE_BASELINE` is upstream truth and must be protected like Tier 0 and Tier 0.5.

Therefore:

- no governance mode may suspend Tier 0.8
- `exploration` may produce draft Tier 2 alternatives, but may not silently replace Tier 0.8
- `migration` may allow temporary Tier 2 / module-level deviations only inside declared scope
- any change to Tier 0.8 still requires proposal + user confirmation

The corresponding `GOVERNANCE_MODE.template.md` hard rule must therefore be written as:

- `HARD RULE: No mode may suspend Tier 0, Tier 0.5, or Tier 0.8.`

This resolves the earlier omission where governance-mode protections covered Tier 0 / 0.5 but not the new architecture baseline.

## 10. Routing And Consumption Rules

### 10.1 System Architect load order

System Architect must load upstream artifacts in this order:

1. `PROJECT_BASELINE`
2. `BASELINE_INTERPRETATION_LOG`
3. `PROJECT_ARCHITECTURE_BASELINE`
4. `SYSTEM_GOAL_PACK`
5. `ENGINEERING_CONSTRAINTS`
6. `SYSTEM_ARCHITECTURE`

This order is not stylistic. It is the required derivation order.

### 10.2 downstream roles

Downstream agents should not directly treat Tier 0.8 as a free-form design document.

They consume it through:

- `SYSTEM_ARCHITECTURE`
- cited structural constraints
- proposal/escalation decisions

This keeps the existing "System Architect mediates root truth" model intact instead of letting every role reinterpret user-owned architecture directly.

## 11. Bootstrap Readiness And Registry Effects

### 11.1 `BOOTSTRAP_READINESS` structure

`BOOTSTRAP_READINESS.template.md` must gain an explicit Tier 0.8 section, parallel to Tier 0 and Tier 0.5:

```md
## 3.8. Tier 0.8 — Architecture Baseline

| Artifact | State | Notes |
|----------|-------|-------|
| PROJECT_ARCHITECTURE_BASELINE.md | <!-- ready/not_started/blocked --> | <!-- User-owned structural truth. Must stay within size limits and be present before Tier 2 derivation. --> |
```

It must also define a Tier 2 readiness row or equivalent system-readiness note for `SYSTEM_ARCHITECTURE.md`, because downstream module derivation now depends on that artifact.

### 11.2 `DERIVATION_REGISTRY` structure

`DERIVATION_REGISTRY.md` must include an explicit row for `SYSTEM_ARCHITECTURE.md`, for example:

```md
| SYSTEM_ARCHITECTURE.md | 2026-03-22T10:00:00Z | model=gpt-x; upstream=baseline:v1 + arch:v1 | abc1234 | 2026-03-22 |
```

Without that row, the most important new derived artifact would sit outside the versioned re-derivation tracking chain.

## 12. Downstream Effects

The new layer changes downstream derivation in a specific way:

- `SYSTEM_GOAL_PACK` stays a translation of Tier 0 / 0.5 only
- `SYSTEM_ARCHITECTURE` becomes the main expansion layer for structure
- `SYSTEM_INVARIANTS` may cite Tier 0.8 only when a structural boundary creates a system-level invariant
- `MODULE_CONTRACT` derives from:
  - `SYSTEM_GOAL_PACK`
  - `SYSTEM_ARCHITECTURE`
  - `SYSTEM_INVARIANTS`
  - `ENGINEERING_CONSTRAINTS`
- `MODULE_CANONICAL_WORKFLOW` and `MODULE_CANONICAL_DATAFLOW` trace back to Tier 2 and, transitively, Tier 0.8
- verification artifacts gain architecture-conformance checks but do not rewrite architecture truth

## 13. Recommendation

Adopt the following final model:

- `PROJECT_ARCHITECTURE_BASELINE.md` at Tier `0.8`
- `SYSTEM_ARCHITECTURE.md` at Tier `2`, derived from `0 / 0.5 / 0.8 / 1 / 1.5`
- `ARCHITECTURE_CHANGE_PROPOSAL.md` as the mandatory change path

Do not:

- collapse user architecture truth directly into Tier 2
- replace Tier 2 entirely with a user-maintained document
- let downstream artifacts silently reinterpret the architecture baseline

The correct split is:

- user owns the structural floor
- System Architect derives the detailed architecture
- downstream roles consume that derived detail without rewriting the floor
