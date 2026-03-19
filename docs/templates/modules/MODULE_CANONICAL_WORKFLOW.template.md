---
artifact_type: module-canonical-workflow
status: proposed
owner_role: module-architect
scope: module
module: "[module-name]"
downstream_consumers: [implementation, debug]
last_reviewed: 2026-03-20
---

# MODULE_CANONICAL_WORKFLOW: [module-name]

**Status:** proposed
**Owner:** Module Architect Agent
**Last Updated:** YYYY-MM-DD

---

## 1. Canonical Scenario

<!-- Describe the main happy path this workflow covers -->
<!-- Step 1 → Step 2 → Step 3 → ... → Output -->

## 2. Canonical Steps

### CW-1: [Step Name]

- **Entry:** `path/to/file.ts#L100-L120` — function/method name
- **Action:** <!-- What happens at this step -->
- **Output:** <!-- What is produced -->
- **Failure Rule:** <!-- What causes this step to fail? What happens on failure? -->

### CW-2: [Step Name]

- **Entry:** `path/to/file.ts#L130-L180`
- **Action:** <!-- ... -->
- **Output:** <!-- ... -->
- **Failure Rule:** <!-- ... -->

<!-- Add more steps as needed. Every step MUST have a code link. -->

## 3. Canonical Failure Semantics

<!-- How does this module handle failures at each step? -->
<!-- - Step fails → what happens? Retry? Fallback? Abort? -->
<!-- - Is fail-closed enforced? -->

## 4. Drilldown Links

<!-- Pointers to deeper code paths for debugging -->
<!-- - `path/to/internal-helper.ts#L50-L80` — helper function description -->
<!-- - `path/to/test-file.test.ts` — relevant test coverage -->

---

> **Note:** Every canonical step MUST include a `filePath#L-L` code link.
> Steps without code links are documentation, not debug truth.
