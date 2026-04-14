# Documentation Index

This repository has three documentation layers:

1. **Design docs** in [`docs/design/`](./design/)
   - Architecture decisions
   - Governance model design
   - Bootstrap and implementation plans
   - Routing and semantic router designs
2. **Examples** in [`docs/examples/`](./examples/)
   - Real-world sample artifacts
   - Debug and implementation examples
3. **Templates** in [`docs/templates/`](./templates/)
   - Starter documents for bootstrapping `docs/agents/` in another project

Platform-specific entrypoints live at the repository root:

- [AGENTS.md](/AGENTS.md)
- [CLAUDE.md](/CLAUDE.md)
- [GEMINI.md](/GEMINI.md)
- [HERMES.md](/HERMES.md)
- [.codex/INSTALL.md](/.codex/INSTALL.md)

## How To Read This Repo

If you are evaluating the framework:

1. Read [README.md](/README.md)
2. Read the design docs in [`docs/design/`](./design/)
3. Read the example artifacts in [`docs/examples/`](./examples/)

If you are trying to install and use the framework in another project:

1. Read [README.md](/README.md)
2. Read [docs/templates/README.md](./templates/README.md)
3. Instantiate templates into your target project's `docs/agents/`
4. Install the skills for your platform

## Important Distinction

- `docs/templates/` contains source templates
- your target project's `docs/agents/` contains active truth artifacts

Templates do not become authoritative until they are instantiated with active filenames such as:

- `SYSTEM_GOAL_PACK.md`
- `SYSTEM_AUTHORITY_MAP.md`
- `MODULE_CONTRACT.md`
- `VERIFICATION_ORACLE.md`

Do not point agents at `.template.md` files as if they were active truth.
