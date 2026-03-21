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
6. Derived documents (SYSTEM_GOAL_PACK, SYSTEM_INVARIANTS, MODULE_CONTRACT, ACCEPTANCE_RULES, VERIFICATION_ORACLE) must never be hand-edited to contradict their upstream source. Changes flow upstream through the derivation chain.
7. `MODULE_CONTRACT` is a system-maintained statement of approved module truth, not a mirror of current code. Code drift triggers audit or re-derivation rather than silent contract rewrites.

## 2. Tier 0 — Project Baseline (User-Owned Root)

<!-- The single document the user writes directly. All other documents derive from it. -->
| Document | Status | Notes |
|----------|--------|-------|
| PROJECT_BASELINE.md | active | User-owned root of all truth. Pure business language. ≤100 lines. |

## 2.5. Tier 0.5 — Baseline Interpretation (User-Confirmed, SA-Owned)

<!-- User-confirmed business-semantic clarifications. Subordinate to BASELINE, superior to all technical translations. -->
| Document | Status | Derived From | Notes |
|----------|--------|-------------|-------|
| BASELINE_INTERPRETATION_LOG.md | active | PROJECT_BASELINE | Records user-confirmed interpretations of ambiguous business meaning. System Architect owns; user confirms entries. Cannot introduce meaning outside BASELINE envelope. |

## 3. Tier 1 — Final Goals (Derived from Baseline)

<!-- PRD, product vision, business requirements — derived from PROJECT_BASELINE -->
| Document | Status | Derived From | Notes |
|----------|--------|-------------|-------|
| SYSTEM_GOAL_PACK.md | active | PROJECT_BASELINE | Technical translation of business baseline |

## 4. Tier 2 — Top-Level Architecture

<!-- System architecture, core design decisions -->
| Document | Status | Notes |
|----------|--------|-------|
| <!-- e.g., SYSTEM_ARCHITECTURE.md --> | active | |

## 5. Tier 3 — System Constraints (Derived from Baseline §4)

<!-- Hard rules derived from BASELINE business rules -->
| Document | Status | Derived From | Notes |
|----------|--------|-------------|-------|
| SYSTEM_INVARIANTS.md | active | PROJECT_BASELINE §4 | Technical invariants from business rules |

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
4. Active baseline documents from tiers 1-4
5. Supporting documents from tier 5 — only when task requires
6. Historical documents — only for context, never as design truth
7. Code — as evidence, never as override

**Downstream agents** (Module Architect, Debug, Implementation, Verification, Frontend Specialist) do NOT load PROJECT_BASELINE directly. They consume the baseline constraints extracted by the System Architect and passed downstream through SYSTEM_GOAL_PACK, SYSTEM_INVARIANTS, and cited BASELINE_INTERPRETATION_LOG entries.
