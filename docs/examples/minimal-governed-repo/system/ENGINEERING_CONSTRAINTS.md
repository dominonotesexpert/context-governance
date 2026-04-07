---
artifact_type: engineering-constraints
status: active
owner_role: system-architect
scope: system
downstream_consumers: [module-architect, implementation, debug]
last_reviewed: 2026-03-20
authority_tier: 1.5
---

# ENGINEERING_CONSTRAINTS

**Status:** active
**Owner:** System Architect (with engineering team input)
**Last Updated:** 2026-03-20
**Authority Tier:** 1.5 (below SYSTEM_GOAL_PACK, above Architecture)

> This document records real-world engineering constraints that shape downstream contracts and implementation choices.
> It cannot override or contradict PROJECT_BASELINE — business truth always wins.
> It CAN influence how business goals are technically achieved.

---

## 1. Purpose

Engineering constraints represent facts about the technical environment that are not derivable from business goals alone. They include dependency limits, migration windows, performance ceilings, compliance implementation details, legacy system constraints, and known third-party defects.

These constraints have first-class representation in the governance chain at Tier 1.5, ensuring that downstream module contracts and implementation plans account for engineering reality.

## 2. Constraint Categories

| Category | Description |
|----------|-------------|
| `dependency-limit` | Version pins, API deprecations, library restrictions |
| `migration-window` | Time-bounded technical transitions |
| `performance-ceiling` | Known capacity or latency boundaries |
| `compliance-detail` | Technical implementation of compliance requirements |
| `legacy-constraint` | Existing system limitations that shape design |
| `third-party-defect` | Known bugs in external dependencies |

## 3. Constraint Registry

| ID | Category | Constraint | Source | Impact on Contracts | Expiry |
|----|----------|-----------|--------|-------------------|--------|
| EC-001 | dependency-limit | PostgreSQL 14.x only — upgrade to 15 blocked until ORM driver supports MERGE syntax | DBA team advisory 2026-02 | api-service MODULE_CONTRACT must not use PG15-only features | 2026-09-01 |
| EC-002 | legacy-constraint | Auth service returns 200 with error body instead of 4xx on permission denial | Legacy API team | api-service must inspect response body, not just HTTP status, for auth checks | permanent |

## 4. Rules

1. Constraints MUST NOT contradict PROJECT_BASELINE or BASELINE_INTERPRETATION_LOG
2. Constraints CAN shape how business goals are technically achieved
3. Each constraint MUST cite its source (team, audit, vendor advisory, etc.)
4. Time-bounded constraints MUST have an expiry date
5. Permanent constraints MUST be reviewed at least quarterly
6. Module Architect and Implementation Agent consume this document; Debug Agent references it for root-cause context
