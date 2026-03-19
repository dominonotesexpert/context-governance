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
4. Code is evidence at tier 6 — it can inform decisions but never override design truth

## 2. Tier 1 — Final Goals

<!-- PRD, product vision, business requirements -->
| Document | Status | Notes |
|----------|--------|-------|
| <!-- e.g., PRD_V2.md --> | active | <!-- Primary product requirements --> |

## 3. Tier 2 — Top-Level Architecture

<!-- System architecture, core design decisions -->
| Document | Status | Notes |
|----------|--------|-------|
| <!-- e.g., SYSTEM_ARCHITECTURE.md --> | active | |

## 4. Tier 3 — Active Baselines

<!-- Module-level active designs, implementation plans -->
| Document | Status | Notes |
|----------|--------|-------|
| <!-- Add active baseline docs --> | active | |

## 5. Tier 4 — Supporting Documents

<!-- Accepted extensions, narrow fixes, specs -->
| Document | Status | Notes |
|----------|--------|-------|

## 6. Tier 5 — Historical / Superseded

<!-- Documents that WERE active but are no longer authoritative -->
| Document | Status | Reason for Downgrade |
|----------|--------|---------------------|
| <!-- e.g., old-architecture-v1.md --> | historical | <!-- Superseded by X --> |

## 7. Artifact Consumption Order

Agents MUST read artifacts in this order:
1. `docs/agents/` (persistent truth) — FIRST
2. Active baseline documents from tiers 1-3
3. Supporting documents from tier 4 — only when task requires
4. Historical documents — only for context, never as design truth
5. Code — as evidence, never as override
