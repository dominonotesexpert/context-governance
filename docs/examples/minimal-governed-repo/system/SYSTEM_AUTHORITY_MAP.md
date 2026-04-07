---
artifact_type: system-authority-map
status: active
owner_role: system-architect
scope: system
downstream_consumers: [module-architect, implementation, verification, debug]
last_reviewed: 2026-03-20
---

# SYSTEM_AUTHORITY_MAP

**Status:** active

## 1. Usage Rules
1. Higher tier wins when documents conflict
2. `active` = current truth; `historical` = evidence only
3. Code is tier 6 evidence — never overrides design
4. PROJECT_BASELINE is Tier 0 — the absolute root of all truth
5. Derived documents must never be hand-edited to contradict their upstream source

## 2. Tier 0 — Project Baseline (User-Owned Root)
| Document | Status | Notes |
|----------|--------|-------|
| PROJECT_BASELINE.md | active | User-owned root. Pure business language. |

## 2.5. Tier 0.5 — Baseline Interpretation (User-Confirmed, SA-Owned)
| Document | Status | Derived From | Notes |
|----------|--------|-------------|-------|
| BASELINE_INTERPRETATION_LOG.md | active | PROJECT_BASELINE | 2 confirmed interpretations (INT-001, INT-002) |

## 3. Tier 1 — Final Goals (Derived from Baseline + Interpretations)
| Document | Status | Derived From | Notes |
|----------|--------|-------------|-------|
| SYSTEM_GOAL_PACK.md | active | PROJECT_BASELINE + BASELINE_INTERPRETATION_LOG | Technical translation of business baseline and confirmed interpretations |

## 3.5. Tier 1.5 — Engineering Constraints (SA-Owned, Engineering Input)
| Document | Status | Source | Notes |
|----------|--------|--------|-------|
| ENGINEERING_CONSTRAINTS.md | active | Engineering team + System Architect | Shapes downstream contracts within BASELINE envelope. |

## 4. Tier 2 — Architecture
| Document | Status | Notes |
|----------|--------|-------|
| (not yet created) | — | Will contain system architecture decisions |

## 5. Tier 3 — System Constraints (Derived from Baseline §4 + Interpretations)
| Document | Status | Derived From | Notes |
|----------|--------|-------------|-------|
| SYSTEM_INVARIANTS.md | active | PROJECT_BASELINE §4 + BASELINE_INTERPRETATION_LOG | Technical invariants from business rules and confirmed interpretations |

## 6. Tier 4 — Module Contracts
| Document | Status | Notes |
|----------|--------|-------|
| modules/api-service/MODULE_CONTRACT.md | active | API service boundaries |

## 7. Tier 5 — Historical
| Document | Status | Reason |
|----------|--------|--------|
| (none yet) | — | — |
