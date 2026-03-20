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

## 3. Tier 1 — Final Goals (Derived from Baseline)
| Document | Status | Derived From | Notes |
|----------|--------|-------------|-------|
| SYSTEM_GOAL_PACK.md | active | PROJECT_BASELINE | Technical translation of business baseline |

## 4. Tier 2 — Architecture
| Document | Status | Notes |
|----------|--------|-------|
| (not yet created) | — | Will contain system architecture decisions |

## 5. Tier 3 — System Constraints (Derived from Baseline §4)
| Document | Status | Derived From | Notes |
|----------|--------|-------------|-------|
| SYSTEM_INVARIANTS.md | active | PROJECT_BASELINE §4 | Technical invariants from business rules |

## 6. Tier 4 — Module Contracts
| Document | Status | Notes |
|----------|--------|-------|
| modules/api-service/MODULE_CONTRACT.md | active | API service boundaries |

## 7. Tier 5 — Historical
| Document | Status | Reason |
|----------|--------|--------|
| (none yet) | — | — |
