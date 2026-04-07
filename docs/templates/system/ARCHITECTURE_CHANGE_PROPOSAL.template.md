---
artifact_type: architecture-change-proposal
status: proposed
owner_role: system-architect
scope: system
downstream_consumers: [system-architect, module-architect, implementation, verification, debug]
last_reviewed: YYYY-MM-DD
---

# ARCHITECTURE_CHANGE_PROPOSAL

**Status:** proposed
**Owner:** System Architect
**Last Updated:** YYYY-MM-DD

> This artifact records proposed changes to PROJECT_ARCHITECTURE_BASELINE.
> Proposals do NOT modify architecture truth directly.
> Only user approval converts a proposal into a baseline change.

---

## Proposal Registry

### ACP-001: [Proposal Title]

- **Date:** YYYY-MM-DD
- **Raised By:** [agent role or user]
- **Affected Section:** PROJECT_ARCHITECTURE_BASELINE §X
- **Trigger:** [structural contradiction | technical infeasibility | engineering-constraint conflict | goal satisfaction gap]
- **Evidence:** <!-- What proves the current architecture baseline is problematic? -->
- **Options:**
  1. <!-- Option A -->
  2. <!-- Option B -->
- **Recommendation:** <!-- Which option and why -->
- **User Decision:** pending | approved | rejected
- **Resolution:** <!-- What was decided and what changed -->

## Rules

1. Agents MUST NOT directly edit PROJECT_ARCHITECTURE_BASELINE — all changes go through this proposal mechanism
2. Each proposal must cite evidence (not just opinion)
3. User approval is required before any Tier 0.8 modification
4. After approval, System Architect re-derives Tier 2 and affected downstream artifacts
5. DERIVATION_REGISTRY updates after verification of re-derived artifacts
