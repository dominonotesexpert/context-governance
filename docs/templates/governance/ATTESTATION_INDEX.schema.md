# Attestation Index Schema

**Location:** `.governance/attestations/index.jsonl`
**Authority:** `docs/plans/2026-03-24-deerflow-inspired-governance-engine-plan.md` §3.3, §4.4

---

## Purpose

The attestation index is a machine-readable registry of all governed task receipts. It enables fast lookup of task history without parsing individual receipt files.

**This file is committed to version control** alongside receipt files.

---

## Format

One JSON object per line (JSONL). Each line represents one task receipt.

```jsonl
{"task_id":"T-20260325-001","task_type":"bug","status":"completed","receipt_path":".governance/attestations/T-20260325-001.receipt.yaml","created_at":"2026-03-25T10:00:00Z","updated_at":"2026-03-25T14:30:00Z","attestation_mode":"mcp"}
{"task_id":"T-20260325-002","task_type":"feature","status":"in_progress","receipt_path":".governance/attestations/T-20260325-002.receipt.yaml","created_at":"2026-03-25T11:00:00Z","updated_at":"2026-03-25T11:00:00Z","attestation_mode":"manual_attestation"}
```

---

## Field Definitions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `task_id` | string | yes | Task identifier. Format: `T-YYYYMMDD-NNN` |
| `task_type` | string | yes | One of: `bug`, `feature`, `refactor`, `design`, `architecture`, `protocol`, `contract_authoring`, `autoresearch`, `trivial` |
| `status` | string | yes | One of: `in_progress`, `completed`, `abandoned` |
| `receipt_path` | string | yes | Relative path to the receipt YAML file |
| `created_at` | string | yes | ISO 8601 timestamp of receipt creation |
| `updated_at` | string | yes | ISO 8601 timestamp of last receipt update |
| `attestation_mode` | string | yes | One of: `mcp`, `manual_attestation` |

---

## Lifecycle Rules

1. **Creation:** A new line is appended when `governance_start_task` (MCP) or manual receipt creation occurs.
2. **Update:** When a receipt is updated, the existing line is replaced (matched by `task_id`). Tools must preserve line order for other entries.
3. **Completion:** When a task is completed or abandoned, the line's `status` and `updated_at` are updated.
4. **No deletion:** Lines are never removed. Abandoned tasks remain in the index for audit trail.

---

## Task ID Assignment

- **Default issuer:** MCP service (`governance_start_task` tool)
- **Fallback issuer:** Manual creation with `attestation_mode: manual_attestation`
- Task IDs are monotonically increasing within a date: `T-YYYYMMDD-001`, `T-YYYYMMDD-002`, ...
- To assign the next ID: read the index, find the highest NNN for today's date, increment by 1
- If no entries exist for today, start at 001

---

## Validation Rules

- Each line must be valid JSON
- `task_id` must be unique across the entire index
- `receipt_path` must point to an existing file
- `status` must match the `status` field in the referenced receipt
- `task_type` must match the `task_type` field in the referenced receipt

---

## Receipt File Naming Convention

```
.governance/attestations/{task_id}.receipt.yaml
```

Example: `.governance/attestations/T-20260325-001.receipt.yaml`
