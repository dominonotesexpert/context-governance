# Module Templates

These templates define module-level truth owned by the Module Architect.

## What counts as a module

A module is a stable unit of responsibility with:

- a clear purpose
- explicit boundaries
- identifiable inputs and outputs
- behavior that can be verified on its own

Examples:

- service-level modules: `auth`, `billing`, `notifications`
- runtime subsystems: `preview-runtime`, `style-generation`
- business flows: `checkout`, `case-intake`
- domain slices: `reporting`, `customer-admin`

Non-examples:

- `misc`
- `bugfix-123`
- `new-work`
- the whole repository when it contains multiple unrelated responsibilities

If you cannot name a stable module yet, start with system-level truth only and add modules later.

Instantiate per module:

- `MODULE_CONTRACT.template.md` -> `docs/agents/modules/<module>/MODULE_CONTRACT.md`
- `MODULE_BOUNDARY.template.md` -> `docs/agents/modules/<module>/MODULE_BOUNDARY.md`
- `MODULE_DATAFLOW.template.md` -> `docs/agents/modules/<module>/MODULE_DATAFLOW.md`
- `MODULE_WORKFLOW.template.md` -> `docs/agents/modules/<module>/MODULE_WORKFLOW.md`
- `MODULE_CANONICAL_WORKFLOW.template.md` -> `docs/agents/modules/<module>/MODULE_CANONICAL_WORKFLOW.md`
- `MODULE_CANONICAL_DATAFLOW.template.md` -> `docs/agents/modules/<module>/MODULE_CANONICAL_DATAFLOW.md`
- `MODULE_BOOTSTRAP_PACK.template.md` -> `docs/agents/modules/<module>/MODULE_BOOTSTRAP_PACK.md`

Start with one critical module first. Do not try to map the whole system on day one.
