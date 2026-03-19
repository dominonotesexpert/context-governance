---
artifact_type: system-scenario-map-index
status: proposed
owner_role: system-architect
scope: system
downstream_consumers: [debug, module-architect]
last_reviewed: 2026-03-20
---

# SYSTEM_SCENARIO_MAP_INDEX

**Status:** proposed
**Owner:** System Architect Agent
**Last Updated:** YYYY-MM-DD

---

## 1. Purpose

Index of all cross-module end-to-end scenario maps. Each scenario map traces a complete user-facing flow through the system, identifying module chains, handoff points, and known failure modes.

## 2. Ownership

System Architect Agent owns this index and all scenario maps. Module-level details are delegated to module canonical maps.

## 3. Required Fields Per Scenario Map

Every scenario map file MUST contain:

1. **Scenario Name** — descriptive identifier
2. **Status** — active | superseded | historical
3. **Entry Trigger** — what user action or system event starts this flow
4. **Module Chain** — ordered list of modules involved
5. **Cross-Module Hops** — where data/control passes between modules
6. **Failure Points** — known failure modes at each hop
7. **Drilldown Links** — pointers to module canonical maps and code anchors

## 4. Naming Convention

Scenario files live in `scenarios/` subdirectory:
```
scenarios/<descriptive-kebab-case-name>.md
```

## 5. Active Scenarios

| Scenario | Status | File |
|----------|--------|------|
| <!-- e.g., user-login-flow --> | active | `scenarios/<name>.md` |

## 6. Update Rules

1. New end-to-end flow discovered → add scenario map
2. Module chain changes → update affected scenario maps
3. New failure mode discovered → add to failure points
4. Scenario deprecated → mark as `historical`, do not delete
