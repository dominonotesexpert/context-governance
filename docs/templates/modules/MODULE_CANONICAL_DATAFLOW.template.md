---
artifact_type: module-canonical-dataflow
status: proposed
owner_role: module-architect
scope: module
module: "[module-name]"
downstream_consumers: [implementation, debug]
last_reviewed: 2026-03-20
---

# MODULE_CANONICAL_DATAFLOW: [module-name]

**Status:** proposed
**Owner:** Module Architect Agent
**Last Updated:** YYYY-MM-DD

---

## 1. Canonical Data Nodes

<!-- List the key data objects that flow through this module -->

| # | Node Name | Type | Description |
|---|-----------|------|-------------|
| 1 | <!-- e.g., UserRequest --> | <!-- object/string/array --> | <!-- what this data represents --> |

## 2. Canonical Edges

### CD-1: [Source] → [Target]

- **Source:** `path/to/file.ts#L100-L120`
- **Target Data Node:** <!-- which data node is produced -->
- **Transform:** <!-- what transformation occurs -->
- **Notes:** <!-- any important observations -->

### CD-2: [Source] → [Target]

- **Source:** `path/to/file.ts#L130-L180`
- **Target Data Node:** <!-- ... -->
- **Transform:** <!-- ... -->

<!-- Add more edges as needed. Every edge MUST have a source code link. -->

## 3. Dataflow Guarantees

<!-- What invariants hold across this dataflow? -->
<!-- - Data X is never modified after step Y -->
<!-- - Output Z always contains field W -->

## 4. Debug / Verification Hooks

<!-- Where can you observe data in transit for debugging? -->
<!-- - `path/to/test.test.ts` — tests this dataflow -->
<!-- - Runtime log: `[module] event-name` — logs data at this point -->

---

> **Note:** Every canonical edge MUST include a `filePath#L-L` source code link.
> Edges without code links are documentation, not debug truth.
