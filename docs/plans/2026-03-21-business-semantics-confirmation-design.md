# Business Semantics Confirmation Layer Design

**Date:** 2026-03-21
**Status:** Proposed
**Scope:** Refine Context Governance so user confirmation applies only to business-semantics interpretation, while agents retain ownership of technical translation and implementation design.

## 1. Problem

The current framework already establishes `PROJECT_BASELINE` as the root business truth and requires user confirmation for interpretive derivations. However, the confirmation boundary is still too coarse. The design does not yet clearly distinguish:

- business-semantics clarification that only the user may confirm
- technical translation and architecture design that agents may derive
- technical choices that must be escalated because they would change business meaning

Without this distinction, the system risks drifting in one of two wrong directions:

- `PROJECT_BASELINE` expands into a hidden PRD or architecture document
- downstream derived artifacts become de facto truth sources for unresolved business meaning

The framework needs an explicit business-semantics confirmation layer between `PROJECT_BASELINE` and the technical derivation chain.

## 2. Goal

The revised architecture must enforce four conditions:

1. `PROJECT_BASELINE` remains short, business-only, and user-owned.
2. Users participate only in clarifying business meaning, boundaries, and success semantics.
3. Agents derive technical translation, module design, interfaces, and implementation approach without requiring user approval for routine technical decisions.
4. Any technical decision that would alter business meaning, scope, or success semantics must be escalated back to the user.

## 3. Non-Goals

This revision does not aim to:

- turn `PROJECT_BASELINE` into a full PRD
- require user approval for normal technical design decisions
- let users define low-level architecture or implementation details
- let downstream artifacts introduce new business truth without traceability
- replace runtime controls such as approvals, hooks, CI, or branch protections

## 4. Authority Model

### 4.1 Revised authority chain

The governance chain becomes:

1. `PROJECT_BASELINE` (Tier 0)
2. `BASELINE_INTERPRETATION_LOG` (Tier 0.5)
3. `SYSTEM_GOAL_PACK` (Tier 1)
4. `SYSTEM_INVARIANTS`
5. `MODULE_CONTRACT`
6. `ACCEPTANCE_RULES` and `VERIFICATION_ORACLE`
7. task-scoped implementation and verification evidence

`Tier 0.5` is intentionally a sub-tier rather than a second root. It exists to record user-confirmed business-semantic interpretations that remain subordinate to `PROJECT_BASELINE` and superior to all technical translations derived from it.

### 4.2 Authority responsibilities

`PROJECT_BASELINE` owns:

- product definition
- target users
- core capabilities
- non-negotiable business rules
- success criteria
- explicit out-of-scope boundaries

`BASELINE_INTERPRETATION_LOG` owns:

- user-confirmed interpretations of ambiguous baseline meaning
- user-confirmed resolution of business-semantic forks
- clarification of business scope or success semantics that cannot be derived mechanically

It does **not** own technical design.
It is owned by `System Architect`, not by the user directly. The user confirms entries, but the artifact remains part of the derived governance chain rather than becoming a second user-maintained root document.

`SYSTEM_GOAL_PACK` owns:

- technical translation of baseline and interpretation decisions
- system direction expressed in engineering language

It does **not** own independent business meaning.

Downstream artifacts own:

- technical obligations
- module boundaries
- verification structure
- implementation constraints

They do **not** own business truth.

## 5. Decision Boundary

### 5.1 User-confirmed decisions

The user must confirm only when the system encounters unresolved business semantics, including:

- ambiguous meaning of a core capability
- conflicting interpretations of a business rule
- scope inclusion vs exclusion decisions
- acceptance meaning that changes what counts as success or failure
- business-facing degradation choices

Examples:

- Does "real-time collaboration" mean sub-second visibility or eventual sync within a work session?
- Does "must never lose user data" allow delayed writes with replay, or is acknowledged durability required before success is shown to users?
- Does "system stays usable when one backend component is down" mean read-only operation is acceptable, or must writes continue too?

### 5.2 Agent-derived decisions

Agents may derive without user confirmation:

- module decomposition
- internal service boundaries
- interface shape
- state and data flow
- implementation patterns
- testing strategy
- observability and verification mechanisms

These remain valid as long as they do not modify business meaning.

### 5.3 Mandatory escalation rule

If a technical choice would change:

- the business promise
- the scope boundary
- the meaning of success
- the meaning of failure handling

then the choice is no longer purely technical and must be escalated as a business-semantics question.

## 6. Artifact Changes

### 6.1 New artifact: `BASELINE_INTERPRETATION_LOG.md`

Add a new system-level artifact between `PROJECT_BASELINE` and `SYSTEM_GOAL_PACK`.

Proposed metadata:

- `artifact_type: baseline-interpretation-log`
- `owner_role: system-architect`
- `authority_tier: 0.5`
- `requires_user_confirmation: true`

Each entry must contain:

- interpretation id
- baseline source section
- ambiguity or decision point
- candidate interpretations
- user-confirmed interpretation
- rationale in business language
- status
- effective baseline version

This artifact is derived from user interaction but remains governed by the baseline chain. It records clarified business meaning without turning the baseline into a large document.

### 6.2 `PROJECT_BASELINE.template.md`

No structural expansion is needed. The template is already aligned with the short-baseline principle.

The only required change is documentation language clarifying:

- this document is not a PRD
- detailed technical implementation must not be placed here
- ambiguous business meaning is clarified through `BASELINE_INTERPRETATION_LOG`

### 6.3 `SYSTEM_GOAL_PACK.template.md`

Restrict this artifact to technical translation only.

Required changes:

- remove or relocate sections that can become independent business truth
- add per-section source metadata referencing either `PROJECT_BASELINE` or `BASELINE_INTERPRETATION_LOG`
- forbid introduction of new business semantics not traceable upstream

`Current Direction` should move to a dedicated project-wide execution artifact such as `CURRENT_DIRECTION.md`, not to `GOVERNANCE_PROGRESS`.

The distinction matters:

- `CURRENT_DIRECTION.md` is project-wide phase context: what the project is currently prioritizing, building, or stabilizing
- `GOVERNANCE_PROGRESS` remains task-scoped execution tracking for one governance task

The framework should not overload a per-task progress tracker with project-wide directional state.

### 6.4 `SYSTEM_INVARIANTS.template.md`

The template already supports `derivation_type: interpretive` and `verified: user_confirmed`. The change here is not a new confirmation mechanism, but an expansion of allowed upstream sources:

- `PROJECT_BASELINE`
- `BASELINE_INTERPRETATION_LOG`

Each invariant must show whether its meaning depends on a user-confirmed semantic interpretation.

### 6.5 `MODULE_CONTRACT.template.md`

Change the model from "purely structural derivation" to "technical derivation under business-semantic guardrails."

Add fields such as:

- upstream_business_sources
- business_semantics_impact: `none | low | high`

If a proposed module boundary or contract would materially reinterpret a capability or business rule, the module artifact must escalate rather than silently finalize the decision.

`escalation_required` should not be stored as an independent field. It is implied by the mandatory escalation rule plus the proposed impact classification, and storing both would create avoidable inconsistency.

### 6.6 `ACCEPTANCE_RULES.template.md`

Split the artifact into two layers:

1. `Business Acceptance Semantics`
2. `Technical Verification Gates`

The first layer may only derive from:

- `PROJECT_BASELINE`
- `BASELINE_INTERPRETATION_LOG`

The second layer may derive from:

- `SYSTEM_GOAL_PACK`
- `SYSTEM_INVARIANTS`
- `MODULE_CONTRACT`

This preserves the distinction between "what success means" and "how verification proves it."

### 6.7 `ROUTING_POLICY.template.md`

The template already contains a partial version of this boundary in its confidence and confirmation rules. The required revision is to tighten and clarify the existing language so the system asks the user only for:

- business ambiguity
- business conflict
- scope ambiguity
- success-semantics ambiguity
- business-impacting branch decisions

The route must explicitly state that normal technical design should not be blocked on user confirmation.

### 6.8 `SYSTEM_AUTHORITY_MAP.template.md`

Update the authority map so the formal tier registry matches the revised derivation chain.

Required changes:

- add `BASELINE_INTERPRETATION_LOG.md` as `Tier 0.5`
- define `Tier 0.5` as user-confirmed business-semantic interpretation, subordinate to `PROJECT_BASELINE`
- update the consumption order so downstream artifacts may inherit semantics from either `PROJECT_BASELINE` transitively or `BASELINE_INTERPRETATION_LOG`
- clarify that `Tier 0.5` cannot introduce business meaning outside the envelope of `Tier 0`

Without this change, the plan would add a real authority source that the canonical authority registry does not know about.

### 6.9 `BOOTSTRAP_READINESS.template.md`

Update readiness checks to account for the new artifact in the derivation chain.

Required changes:

- add `BASELINE_INTERPRETATION_LOG` to universal prerequisites when business-semantic clarifications exist
- mark it as optional when no interpretation entries are needed yet
- update System Architect readiness notes so the role is not considered fully ready until both baseline derivation and required interpretation confirmations are complete

This prevents the framework from claiming readiness while a required semantic-confirmation layer is still missing.

## 7. Derivation Workflow

### 7.1 Initial baseline workflow

1. User writes `PROJECT_BASELINE`.
2. System Architect checks for business ambiguity, omissions, or contradictions.
3. Ambiguous business meaning is resolved through targeted user questions.
4. Confirmed decisions are stored in `BASELINE_INTERPRETATION_LOG`.
5. `SYSTEM_GOAL_PACK` is derived from baseline plus interpretation log.
6. Downstream technical artifacts are derived from that combined upstream truth.

### 7.2 Ongoing task workflow

1. A task enters through routing.
2. Agents load active upstream truth.
3. Agents derive technical design and implementation choices autonomously.
4. If a choice would alter business meaning, they stop and escalate a business-semantics question.
5. User answer updates `BASELINE_INTERPRETATION_LOG`, not downstream artifacts directly.
6. Affected downstream artifacts are re-derived.

### 7.3 Baseline change workflow

1. User updates `PROJECT_BASELINE`.
2. System detects all impacted interpretation-log entries and derived artifacts.
3. Obsolete interpretations are reviewed.
4. Technical artifacts are re-derived from the new upstream truth.
5. Stale downstream truth never survives as an independent authority source.

## 8. Success Criteria For This Revision

This design revision is successful when:

- users are not asked to define ordinary technical implementation
- agents cannot silently invent business meaning downstream
- baseline stays short even as the project grows
- ambiguous business semantics are stored explicitly and traceably
- technical derivations remain autonomous unless they cross a business boundary

## 9. Recommended Next Step

Implement the revision in two stages:

1. Add `BASELINE_INTERPRETATION_LOG`, update `SYSTEM_AUTHORITY_MAP` to register `Tier 0.5`, update `BOOTSTRAP_READINESS` to gate readiness correctly, and tighten authority language in `PROJECT_BASELINE.template.md`.
2. Update `SYSTEM_GOAL_PACK`, `SYSTEM_INVARIANTS`, `MODULE_CONTRACT`, `ACCEPTANCE_RULES`, and `ROUTING_POLICY` to enforce the new decision boundary.
