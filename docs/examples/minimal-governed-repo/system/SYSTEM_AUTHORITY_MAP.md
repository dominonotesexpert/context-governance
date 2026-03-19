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
3. Code is tier 5 evidence — never overrides design

## 2. Tier 1 — Final Goals
| Document | Status | Notes |
|----------|--------|-------|
| SYSTEM_GOAL_PACK.md | active | Product vision and obligations |

## 3. Tier 2 — Architecture
| Document | Status | Notes |
|----------|--------|-------|
| (not yet created) | — | Will contain system architecture decisions |

## 4. Tier 3 — Module Contracts
| Document | Status | Notes |
|----------|--------|-------|
| modules/api-service/MODULE_CONTRACT.md | active | API service boundaries |

## 5. Tier 4 — Historical
| Document | Status | Reason |
|----------|--------|--------|
| (none yet) | — | — |
