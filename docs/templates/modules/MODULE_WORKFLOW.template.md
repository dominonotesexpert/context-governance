---
artifact_type: module-workflow
status: proposed
owner_role: module-architect
scope: module
module: "[module-name]"
downstream_consumers: [implementation, debug]
last_reviewed: 2026-03-20
---

# MODULE_WORKFLOW: [module-name]

**Status:** proposed
**Owner:** Module Architect Agent
**Last Updated:** YYYY-MM-DD

---

## 1. Overview

<!-- List the fixed execution phases of this module -->
<!-- Phase 1 → Phase 2 → Phase 3 → ... -->

## 2. Phase: [Name]

**Entry Conditions:**
<!-- What must be true before this phase starts? -->

**Core Actions:**
<!-- What happens in this phase? -->

**Fail-Closed Rules:**
<!-- Under what conditions does this phase STOP and degrade? -->

## 3. Phase: [Name]

<!-- Repeat for each phase -->

<!-- TIP: Every phase MUST have explicit fail-closed rules. -->
<!-- "Try to handle errors gracefully" is NOT a fail-closed rule. -->
<!-- "If X is missing, abort and restore previous state" IS. -->
