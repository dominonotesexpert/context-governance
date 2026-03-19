---
artifact_type: namespace-readme
status: proposed
owner_role: debug
scope: debug
downstream_consumers: [implementation, verification]
last_reviewed: 2026-03-20
---

# Debug Artifact Namespace

**Status:** active
**Owner:** Debug Agent
**Purpose:** Store debug governance artifacts for root-cause analysis and recurrence prevention

---

## What Goes Here

1. `AGENT_SPEC.md` — Debug Agent role specification
2. `DEBUG_BOOTSTRAP_PACK.md` — Debug role warm bootstrap entry point
3. `DEBUG_CASE_TEMPLATE.md` — Structure for individual bug investigations
4. `BUG_CLASS_REGISTER.md` — Long-term bug classification register
5. `RECURRENCE_PREVENTION_RULES.md` — Prevention rules by layer
6. `cases/` — Individual debug case files

## Consumption Chain

The Debug namespace consumes:
- System Scenario Maps (from `docs/agents/system/scenarios/`)
- Module Canonical Workflows and Dataflows (from `docs/agents/modules/<module>/`)

The Debug namespace produces:
- DEBUG_CASE per incident
- Bug class entries (when promoted)
- Recurrence prevention rules (when promoted)

## Core Rule

**No fix without root cause.** A DEBUG_CASE must exist before any code change for bug tasks.
