---
artifact_type: affected-files-map
status: proposed
owner_role: implementation
scope: task
downstream_consumers: [verification]
last_reviewed: 2026-03-20
---

# AFFECTED_FILES_MAP: [task-name]

**Date:** YYYY-MM-DD
**Task:** <!-- link to TASK_EXECUTION_PACK -->

---

## 1. Files to Modify

| File | Change Type | Description |
|------|-----------|-------------|
| `path/to/file.ts` | modify | <!-- what changes --> |
| `path/to/other.ts` | modify | <!-- what changes --> |

## 2. Files to Create

| File | Purpose |
|------|---------|
| <!-- path/to/new-file.ts --> | <!-- why this file is needed --> |

## 3. Files to Read (context only)

| File | Reason |
|------|--------|
| `path/to/dependency.ts` | <!-- understand interface / contract --> |

## 4. Test Files

| File | Change Type | Description |
|------|-----------|-------------|
| `path/to/test.test.ts` | modify | <!-- what test changes --> |

## 5. Documentation Files

| File | Change Type | Description |
|------|-----------|-------------|
| <!-- docs/agents/modules/.../MODULE_CANONICAL_WORKFLOW.md --> | modify | <!-- update code links --> |
