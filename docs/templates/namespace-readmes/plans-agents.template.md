---
artifact_type: namespace-readme
status: proposed
owner_role: system-architect
scope: system
downstream_consumers: [all-roles]
last_reviewed: 2026-03-20
---

# Agent Plans Namespace

**Status:** active
**Owner:** System Architect Agent
**Purpose:** Separate agent system design documents and implementation plans from regular system plan documents

---

## What Goes Here

`docs/plans/agents/` stores only **agent system** plan documents, such as:

1. Routing design
2. Bootstrap / governance design
3. Debug flow-map design
4. Agent system implementation plans

## What Does NOT Go Here

1. Runtime / renderer / protocol system designs
2. Business feature task execution packs
3. Affected-files maps
4. Risk checklists
5. Single-task execution drafts

These should remain in `docs/plans/` or enter `docs/agents/execution/` / `docs/agents/task-checklists/` as appropriate.

## Suggested Subdirectories

1. `docs/plans/agents/governance/`
2. `docs/plans/agents/debug/`
3. `docs/plans/agents/routing/`

## Boundary Principle

1. Discussing what agents are, how they route, how they verify — goes here
2. Task-level documents produced when agents execute a business task — does NOT go here
3. `docs/agents/` remains the active truth / contract / oracle namespace
