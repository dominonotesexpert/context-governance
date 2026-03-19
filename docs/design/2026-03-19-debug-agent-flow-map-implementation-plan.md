# Debug Agent and Flow Map Implementation Plan

**Date:** 2026-03-19
**Status:** Approved
**Scope:** Implementation plan for Debug Agent role and Flow Map artifact system

---

## Goal

Instantiate the Debug Agent and Flow Map system into the `docs/agents/` governance namespace, upgrading the bug pipeline to `System -> Module -> Debug -> Implementation -> Verification`.

## Architecture

Implementation proceeds in three layers:

1. **Layer 1** — Create `docs/agents/debug/` minimum bootstrap so every bug produces a DEBUG_CASE
2. **Layer 2** — Add System Scenario Map and pilot module canonical workflow/dataflow maps so debug no longer depends on exhaustive code reading
3. **Layer 3** — Wire entry points (platform entrypoints, BOOTSTRAP_READINESS, existing agent specs) to the new pipeline

## Tasks

### Task 1: Create Debug Agent Scaffold

Create the following files:

- `docs/agents/debug/AGENT_SPEC.md`
- `docs/agents/debug/DEBUG_BOOTSTRAP_PACK.md`
- `docs/agents/debug/DEBUG_CASE_TEMPLATE.md`
- `docs/agents/debug/BUG_CLASS_REGISTER.md`
- `docs/agents/debug/RECURRENCE_PREVENTION_RULES.md`
- `docs/agents/debug/README.md`
- `docs/agents/debug/cases/README.md`

### Task 2: Register Debug Agent in Bootstrap Entry Points

Update:

- `docs/agents/README.md`
- `docs/agents/BOOTSTRAP_READINESS.md`
- Platform entrypoint files
- Agent routing tables

### Task 3: Add System Scenario Map Namespace

Create:

- `docs/agents/system/SYSTEM_SCENARIO_MAP_INDEX.md`
- `docs/agents/system/scenarios/README.md`
- At least one pilot scenario map

### Task 4: Create Pilot Module Canonical Map Set

For one pilot module, create:

- `MODULE_CONTRACT.md`
- `MODULE_BOUNDARY.md`
- `MODULE_WORKFLOW.md`
- `MODULE_DATAFLOW.md`
- `MODULE_CANONICAL_WORKFLOW.md`
- `MODULE_CANONICAL_DATAFLOW.md`
- `MODULE_BOOTSTRAP_PACK.md`

### Task 5: Add Debug Closure Rules to Verification

Update verification artifacts to include debug prerequisite rules:

- DEBUG_CASE + root cause + promotion decision + verification targets required before `pass` verdict

### Task 6: Create First Real Debug Case

Instantiate one real DEBUG_CASE to validate the template and flow.

### Task 7: Final Governance Review

Run consistency scans across all agent governance files and entry points.

## Execution Options

1. **Sequential** — Execute tasks 1-7 in order, reviewing between tasks
2. **Parallel** — Tasks 1, 3, and 4 can run concurrently; tasks 2, 5, 6, 7 are sequential

## Verification

After completion, verify:

1. Every bug task route includes Debug in the chain
2. DEBUG_CASE_TEMPLATE is discoverable from bootstrap
3. System Scenario Map is linked from system bootstrap
4. At least one module has canonical maps
5. Verification acceptance rules include debug closure prerequisite
