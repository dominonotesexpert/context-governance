# Changelog

## Unreleased

### Positioning

- Clarified project lifecycle: introduce after framework stabilizes, not on day one
- Documented relationship with Superpowers: execution layer vs governance layer
- Added "When to Introduce" section with typical project lifecycle phases
- Removed all superpowers/gstack coupling from framework files (CLAUDE.md, settings, design docs)

### Templates

- Added Frontend Specialist AGENT_SPEC template (`docs/templates/frontend/AGENT_SPEC.template.md`)
- Added namespace README templates for all `docs/agents/` subdirectories (`docs/templates/namespace-readmes/`)
  - agents-root, system, modules, debug, implementation, verification, frontend, execution, task-checklists, plans-agents

### Bootstrap

- Bootstrap now creates namespace READMEs for every `docs/agents/` subdirectory
- Bootstrap now creates `SYSTEM_CONFLICT_REGISTER.md` alongside other system artifacts
- Bootstrap now creates `docs/agents/implementation/`, `docs/agents/frontend/`, `docs/agents/execution/`, `docs/agents/task-checklists/`, `docs/plans/agents/` directories
- Added `--copy-skills` flag to bootstrap script for installing `.claude/skills/`
- Added `make bootstrap-full` target (commands + skills)

### Design Documents

- Added debug agent flow map implementation plan
- Added repository agent routing hardening design
- Added repository semantic router design for multilingual intent classification

### Documentation

- Hardened README for external reuse
- Fixed design document links
- Clarified role count and bootstrap flow
- Added docs and template index READMEs
- Added CONTRIBUTING and CHANGELOG maintenance files
- Updated templates README with namespace-readmes and frontend specialist sections

### Tooling

- Added `scripts/bootstrap-project.sh` for minimum project bootstrap
- Added `Makefile` targets for bootstrap and bootstrap verification
- Added shell test coverage for non-destructive bootstrap behavior
- Expanded test coverage for namespace READMEs, new directories, and --copy-skills
