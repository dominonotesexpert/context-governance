---
artifact_type: engineering-constraints
status: proposed
owner_role: system-architect
scope: system
downstream_consumers: [module-architect, implementation, debug]
last_reviewed: YYYY-MM-DD
authority_tier: 1.5
---

# ENGINEERING_CONSTRAINTS

**Status:** proposed
**Owner:** System Architect (with engineering team input)
**Last Updated:** YYYY-MM-DD
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
| <!-- EC-001 | dependency-limit | Example constraint | Engineering team | Shapes MODULE_CONTRACT boundary X | 2026-06-01 or permanent --> |

## 4. Rules

1. Constraints MUST NOT contradict PROJECT_BASELINE or BASELINE_INTERPRETATION_LOG
2. Constraints CAN shape how business goals are technically achieved
3. Each constraint MUST cite its source (team, audit, vendor advisory, etc.)
4. Time-bounded constraints MUST have an expiry date
5. Permanent constraints MUST be reviewed at least quarterly
6. Module Architect and Implementation Agent consume this document; Debug Agent references it for root-cause context
7. Engineering constraints may challenge `PROJECT_ARCHITECTURE_BASELINE` (Tier 0.8) by providing evidence of infeasibility, excessive risk, or external contradiction — but they may NOT rewrite Tier 0.8 directly. The conflict resolution path is `ARCHITECTURE_CHANGE_PROPOSAL`
