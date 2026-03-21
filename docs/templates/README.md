# Template Bootstrap Guide

This directory contains starter templates for bootstrapping Context Governance in another project.

## Core Rule

Each `*.template.md` file must be copied into your target project's `docs/agents/` tree and renamed to its active filename.

Example:

```bash
cp docs/templates/system/SYSTEM_GOAL_PACK.template.md \
  your-project/docs/agents/system/SYSTEM_GOAL_PACK.md
```

## Minimum Bootstrap Set

For the smallest usable installation, instantiate:

- [`BOOTSTRAP_READINESS.template.md`](./BOOTSTRAP_READINESS.template.md) -> `docs/agents/BOOTSTRAP_READINESS.md`
- [`system/BASELINE_INTERPRETATION_LOG.template.md`](./system/BASELINE_INTERPRETATION_LOG.template.md) -> `docs/agents/system/BASELINE_INTERPRETATION_LOG.md` (Tier 0.5)
- [`system/SYSTEM_GOAL_PACK.template.md`](./system/SYSTEM_GOAL_PACK.template.md) -> `docs/agents/system/SYSTEM_GOAL_PACK.md`
- [`system/SYSTEM_AUTHORITY_MAP.template.md`](./system/SYSTEM_AUTHORITY_MAP.template.md) -> `docs/agents/system/SYSTEM_AUTHORITY_MAP.md`
- [`system/SYSTEM_INVARIANTS.template.md`](./system/SYSTEM_INVARIANTS.template.md) -> `docs/agents/system/SYSTEM_INVARIANTS.md`
- [`system/SYSTEM_BOOTSTRAP_PACK.template.md`](./system/SYSTEM_BOOTSTRAP_PACK.template.md) -> `docs/agents/system/SYSTEM_BOOTSTRAP_PACK.md`
- [`modules/MODULE_CONTRACT.template.md`](./modules/MODULE_CONTRACT.template.md) -> `docs/agents/modules/<module>/MODULE_CONTRACT.md`
- [`verification/ACCEPTANCE_RULES.template.md`](./verification/ACCEPTANCE_RULES.template.md) -> `docs/agents/verification/ACCEPTANCE_RULES.md`

## Role Specs

Use [`AGENT_SPEC.template.md`](./AGENT_SPEC.template.md) when you want a role-owned bootstrap file such as:

- `docs/agents/system/AGENT_SPEC.md`
- `docs/agents/modules/AGENT_SPEC.md`
- `docs/agents/debug/AGENT_SPEC.md`
- `docs/agents/implementation/AGENT_SPEC.md`
- `docs/agents/verification/AGENT_SPEC.md`
- `docs/agents/frontend/AGENT_SPEC.md`

## Directory Guide

- [system/README.md](./system/README.md)
- [modules/README.md](./modules/README.md)
- [debug/README.md](./debug/README.md)
- [implementation/README.md](./implementation/README.md)
- [verification/README.md](./verification/README.md)
- [frontend/README.md](./frontend/README.md)
- [namespace-readmes/](./namespace-readmes/) — README templates for each `docs/agents/` subdirectory

## Namespace READMEs

The `namespace-readmes/` directory contains README templates for every `docs/agents/` subdirectory. The bootstrap script automatically installs these:

- `agents-root.template.md` -> `docs/agents/README.md`
- `system.template.md` -> `docs/agents/system/README.md`
- `modules.template.md` -> `docs/agents/modules/README.md`
- `debug.template.md` -> `docs/agents/debug/README.md`
- `implementation.template.md` -> `docs/agents/implementation/README.md`
- `verification.template.md` -> `docs/agents/verification/README.md`
- `frontend.template.md` -> `docs/agents/frontend/README.md`
- `execution.template.md` -> `docs/agents/execution/README.md`
- `task-checklists.template.md` -> `docs/agents/task-checklists/README.md`
- `plans-agents.template.md` -> `docs/plans/agents/README.md`

## Frontend Specialist

Use [`frontend/AGENT_SPEC.template.md`](./frontend/AGENT_SPEC.template.md) to create a frontend specialist role specification at `docs/agents/frontend/AGENT_SPEC.md`.

## Recommended Order

1. Instantiate system templates
2. Optionally instantiate one critical module contract if you already know a stable module boundary
3. Instantiate verification acceptance rules
4. Install skills and routing entrypoint (`CLAUDE.md`, platform-specific setup)
5. Start using the framework on one real task before expanding coverage

## Automation

You can automate the minimum bootstrap with:

```bash
bash scripts/bootstrap-project.sh --target your-project --platform claude
```

Or:

```bash
make bootstrap TARGET=your-project PLATFORM=claude
```

If you already know your first stable module boundary, add:

```bash
--seed-module billing
```

The script skips existing files unless `--force` is passed.
