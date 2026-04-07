---
artifact_type: system-authority-map
status: proposed
owner_role: system-architect
scope: system
downstream_consumers: [module-architect, implementation, verification, debug, frontend-specialist]
last_reviewed: 2026-03-20
---

# SYSTEM_AUTHORITY_MAP

**Status:** proposed
**Owner:** System Architect Agent
**Last Updated:** YYYY-MM-DD

---

## 1. Usage Rules

1. When two documents disagree, the one at a higher tier wins
2. `active` documents are the current truth — `historical` documents are evidence only
3. New documents default to `proposed` until the System Architect promotes them
4. Code is evidence at tier 7 — it can inform decisions but never override design truth
5. **PROJECT_BASELINE is Tier 0 — the absolute root of all truth.** All other documents are derived from it, directly or transitively. When any document conflicts with BASELINE, BASELINE wins.
6. Derived documents (SYSTEM_GOAL_PACK, SYSTEM_INVARIANTS, MODULE_CONTRACT, ACCEPTANCE_RULES, VERIFICATION_ORACLE, ENGINEERING_CONSTRAINTS) must never be hand-edited to contradict their upstream source. Changes flow upstream through the derivation chain.
7. `MODULE_CONTRACT` is a system-maintained statement of approved module truth, not a mirror of current code. Code drift triggers audit or re-derivation rather than silent contract rewrites.

## 2. Tier 0 — Project Baseline (User-Owned Root)

<!-- The single document the user writes directly. All other documents derive from it. -->
| Document | Status | Notes |
|----------|--------|-------|
| PROJECT_BASELINE.md | active | User-owned root of all truth. Pure business language. ≤100 lines. |

## 2b. Tier 0.8 — Architecture Baseline (User-Owned)

<!-- User-owned architectural floor. Constrains the shape of the system without defining detailed architecture. -->
| Document | Status | Notes |
|----------|--------|-------|
| PROJECT_ARCHITECTURE_BASELINE.md | active | User-owned architectural floor. Agents propose changes via ARCHITECTURE_CHANGE_PROPOSAL. |

## 2.5. Tier 0.5 — Baseline Interpretation (User-Confirmed, SA-Owned)

<!-- User-confirmed business-semantic clarifications. Subordinate to BASELINE, superior to all technical translations. -->
| Document | Status | Derived From | Notes |
|----------|--------|-------------|-------|
| BASELINE_INTERPRETATION_LOG.md | active | PROJECT_BASELINE | Records user-confirmed interpretations of ambiguous business meaning. System Architect owns; user confirms entries. Cannot introduce meaning outside BASELINE envelope. |

## 3. Tier 1 — Final Goals (Derived from Baseline + Interpretations)

<!-- PRD, product vision, business requirements — derived from PROJECT_BASELINE and BASELINE_INTERPRETATION_LOG -->
| Document | Status | Derived From | Notes |
|----------|--------|-------------|-------|
| SYSTEM_GOAL_PACK.md | active | PROJECT_BASELINE + BASELINE_INTERPRETATION_LOG | Technical translation of business baseline and confirmed interpretations |

## 3.5. Tier 1.5 — Engineering Constraints (SA-Owned, Engineering Input)

<!-- Real-world engineering constraints that shape downstream contracts. Cannot override BASELINE but can influence technical approach. -->
| Document | Status | Source | Notes |
|----------|--------|--------|-------|
| ENGINEERING_CONSTRAINTS.md | active | Engineering team + System Architect | Shapes downstream contracts within BASELINE envelope. Authority: can constrain implementation approach, cannot change business meaning. |

## 4. Tier 2 — Top-Level Architecture

<!-- System architecture, core design decisions — derived from Tier 0.8 architecture baseline -->
| Document | Status | Derived From | Notes |
|----------|--------|-------------|-------|
| SYSTEM_ARCHITECTURE.md | active | PROJECT_ARCHITECTURE_BASELINE, PROJECT_BASELINE, SYSTEM_GOAL_PACK | Detailed architecture expanding the Tier 0.8 floor |

## 5. Tier 3 — System Constraints (Derived from Baseline §4 + Interpretations)

<!-- Hard rules derived from BASELINE business rules and confirmed interpretations -->
| Document | Status | Derived From | Notes |
|----------|--------|-------------|-------|
| SYSTEM_INVARIANTS.md | active | PROJECT_BASELINE §4 + BASELINE_INTERPRETATION_LOG | Technical invariants from business rules and confirmed interpretations |

## 6. Tier 4 — Active Baselines

<!-- Module-level active designs, contracts, implementation plans -->
| Document | Status | Notes |
|----------|--------|-------|
| <!-- Add active baseline docs --> | active | |

## 7. Tier 5 — Supporting Documents

<!-- Accepted extensions, narrow fixes, specs -->
| Document | Status | Notes |
|----------|--------|-------|

## 8. Tier 6 — Historical / Superseded

<!-- Documents that WERE active but are no longer authoritative -->
| Document | Status | Reason for Downgrade |
|----------|--------|---------------------|
| <!-- e.g., old-architecture-v1.md --> | historical | <!-- Superseded by X --> |

## 9. Artifact Consumption Order

Agents MUST read artifacts in this order:
1. `PROJECT_BASELINE.md` (Tier 0, user-owned root) — **System Architect only loads this directly**
2. `BASELINE_INTERPRETATION_LOG.md` (Tier 0.5, user-confirmed semantic clarifications) — **System Architect loads; downstream agents may reference by citation**
3. `docs/agents/` (persistent truth) — derived documents
4. `ENGINEERING_CONSTRAINTS.md` (Tier 1.5, engineering reality) — Module Architect, Implementation, and Debug agents consume
5. Active baseline documents from tiers 2-4
6. Supporting documents from tier 5 — only when task requires
7. Historical documents — only for context, never as design truth
8. Code — as evidence, never as override

**Downstream agents** (Module Architect, Debug, Implementation, Verification, Frontend Specialist) do NOT load PROJECT_BASELINE directly. They consume the baseline constraints extracted by the System Architect and passed downstream through SYSTEM_GOAL_PACK, SYSTEM_INVARIANTS, and cited BASELINE_INTERPRETATION_LOG entries.

## 10. Meta-Artifacts (Outside Tier Chain)

The following artifacts support the governance process but do not participate in the authority tier hierarchy:

| Document | Owner | Purpose |
|----------|-------|---------|
| DERIVATION_REGISTRY.md | System Architect | Tracks last-known-good derivation state for each derived document. Provides rollback path and comparison baseline for re-derivation. |
