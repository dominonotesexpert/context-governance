---
artifact_type: module-taxonomy
status: proposed
owner_role: system-architect
scope: system
downstream_consumers: [module-architect]
last_reviewed: YYYY-MM-DD
---

# MODULE_TAXONOMY

**Status:** proposed
**Owner:** System Architect Agent

## 1. Purpose

Classify modules to prevent naming chaos and ensure consistent granularity. Every module in the system must fit one of the types below. If it doesn't fit, it either needs to be restructured or it is not a first-class module.

## 2. Module Types

| Type | Description | Examples |
|------|-------------|----------|
| `service-module` | A backend service with clear API boundaries | auth, billing, notifications |
| `domain-flow-module` | A business process that spans multiple services | checkout, onboarding |
| `runtime-subsystem` | An internal runtime component | preview-runtime, style-generation |
| `ui-domain-module` | A bounded UI domain with its own contract | admin-dashboard, settings-panel |
| `cross-cutting-concern` | NOT a first-class module. Managed at system level. | logging, auth-middleware, error-handling |

## 2b. Architecture Alignment

When SYSTEM_ARCHITECTURE.md exists, module decomposition should align with its component structure.

## 3. Rules

1. Only `service-module`, `domain-flow-module`, `runtime-subsystem`, and `ui-domain-module` can be first-class modules with their own `MODULE_CONTRACT.md`.
2. `cross-cutting-concern` MUST be managed at system level (e.g., in `SYSTEM_INVARIANTS.md` or system-level configuration), NOT as a standalone module with its own contract.
3. Module names MUST match the pattern: `[a-z0-9][a-z0-9_-]*`
4. The following name patterns are NOT valid module names:
   - `misc`, `utils`, `helpers` (too vague)
   - `tmp`, `temp`, `scratch` (not durable)
   - `fix-xxx`, `feature-xxx`, `hotfix-xxx` (task names, not module names)
   - `new-xxx`, `old-xxx`, `v2-xxx` (version markers, not identities)

## 4. Examples

### Good Module Choices

| Module Name | Type | Why It Works |
|-------------|------|--------------|
| `api-service` | service-module | Clear API boundary, owns request handling |
| `checkout` | domain-flow-module | Business process spanning cart, payment, inventory |
| `preview-runtime` | runtime-subsystem | Internal component with defined lifecycle |
| `admin-dashboard` | ui-domain-module | Bounded UI with its own state and contract |

### Bad Module Choices

| Proposed Name | Problem | Better Alternative |
|---------------|---------|-------------------|
| `utils` | Too vague, no clear boundary | Distribute into owning modules |
| `fix-auth-timeout` | Task name, not a module | The fix belongs in `auth` (service-module) |
| `logging` | Cross-cutting concern | Manage in SYSTEM_INVARIANTS or system config |
| `misc-api-stuff` | No clear responsibility | Split into the modules that own each piece |
| `new-billing` | Version marker | Just `billing` — use status fields for versioning |
