# Module Artifact Namespace

**Status:** active
**Owner:** Module Architect Agent
**Purpose:** Store module-level contracts, boundaries, workflows, and dataflows

---

## What Goes Here

Each module gets its own subdirectory containing:

1. `MODULE_CONTRACT.md` — Purpose, inputs, outputs, owned/excluded responsibilities
2. `MODULE_BOUNDARY.md` — Responsibility splits with neighboring modules
3. `MODULE_WORKFLOW.md` — Execution phases with entry/exit conditions
4. `MODULE_CANONICAL_WORKFLOW.md` — Canonical workflow with fail-closed rules
5. `MODULE_DATAFLOW.md` — Data transformations through the module
6. `MODULE_CANONICAL_DATAFLOW.md` — Canonical dataflow with code linkage
7. `MODULE_BOOTSTRAP_PACK.md` — Module readiness tracking
8. `AGENT_SPEC.md` — Module Architect Agent role specification (shared)

## Directory Structure

```
docs/agents/modules/
├── README.md
├── AGENT_SPEC.md
├── <module-a>/
│   ├── MODULE_CONTRACT.md
│   ├── MODULE_BOUNDARY.md
│   ├── MODULE_WORKFLOW.md
│   ├── MODULE_CANONICAL_WORKFLOW.md
│   ├── MODULE_DATAFLOW.md
│   ├── MODULE_CANONICAL_DATAFLOW.md
│   └── MODULE_BOOTSTRAP_PACK.md
└── <module-b>/
    └── ...
```

## Consumption Rules

1. Module artifacts are consumed after system artifacts
2. Each module's contract defines what downstream agents may depend on
3. Module Architect must escalate to System Architect if a contract gap requires system-level change
