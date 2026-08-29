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
4. `RCA_HARD_CONSTRAINTS.md` — Baseline lock, double-anchor, authority-diff, scope and blocker rules
5. `BUG_CLASS_REGISTER.md` — Long-term bug classification register
6. `RECURRENCE_PREVENTION_RULES.md` — Prevention rules by layer
7. `cases/` — Individual debug case files

## Consumption Chain

The Debug namespace consumes:
- System Scenario Maps (from `docs/agents/system/scenarios/`)
- Module Canonical Workflows and Dataflows (from `docs/agents/modules/<module>/`)

The Debug namespace produces:
- DEBUG_CASE per incident
- Bug class entries (when promoted)
- Recurrence prevention rules (when promoted)

## Core Rule

**No fix without root cause.** A DEBUG_CASE is mandatory on the formal Debug route. Routine low-risk bugs remain outside this namespace but must record a route reason and cited root-cause evidence before code is staged.
