# Task State Machine

**Schema:** `TASK_RECEIPT.schema.yaml` v2
**Authority:** `docs/plans/2026-04-23-governance-kernel-v2-design.md` §2.2
**Status:** Active

This document defines the legal state transitions for a governed task receipt. The MCP completion path and CI gate reject receipts whose state, route requirements, claims, and evidence are incoherent.

## 1. States

| State | Meaning | Entered when |
|---|---|---|
| `pending` | Receipt created, no work started | `governance_start_task` (strictly speaking this is the default starting state, but the MCP server currently jumps straight to `running` on task start; `pending` is reserved for external callers that pre-create receipts) |
| `running` | Work in progress | `governance_start_task`; or re-entered after failed verification / resolved escalation |
| `evidence_collected` | Formal-route evidence refs attached, ready for Verification | Last required `governance_record_*` call completes |
| `verified` | Formal Verification evidence passed acceptance rules | `governance_record_verification` + oracle pass |
| `escalated` | Work blocked; escalation record created | `governance_record_escalation` |
| `completed` | Terminal success | Routine path after proportionate checks, or formal path after `verified` |
| `aborted` | Terminal failure without escalation | Explicit abort (future `governance_abort_task` tool; not exposed in M1) |
| `abandoned` | Terminal failure after escalation resolved as "won't fix" | Resolve an escalation with decision `abandon` |

States `completed`, `aborted`, `abandoned` are terminal: no further transitions are permitted.

## 2. Transitions

```
            ┌─────────┐
            │ pending │
            └────┬────┘
                 │ start
                 ▼
     ┌──────────────────────┐
     │       running        │◄────────────┐
     └──────┬───────┬───────┘             │
            │       │                     │
  escalate  │       │  collect_evidence   │
            │       │                     │ verify_fail
            ▼       ▼                     │
    ┌──────────┐  ┌────────────────────┐  │
    │escalated │  │ evidence_collected │──┘
    └────┬─────┘  └────────┬───────────┘
         │                 │ verify_ok
 resolve │                 ▼
         │           ┌──────────┐
         ▼           │ verified │
     running         └────┬─────┘
                          │ complete (formal route)
                          ▼
                    ┌───────────┐
                    │ completed │
                    └───────────┘

    routine complete: running → completed
      only when formal_verification_required=false and all task-type
      claims plus proportionate evidence validate

    abandon: escalated → abandoned  (terminal)
    abort:   running   → aborted    (terminal; M1 not exposed, reserved)
```

Legal transitions as a table:

| From | To | Trigger | Required claim or evidence |
|---|---|---|---|
| `pending` | `running` | `start` | none |
| `running` | `evidence_collected` | `collect_evidence` | task_type's required `evidence_refs` present |
| `running` | `escalated` | `escalate` | escalation record in `.governance/escalations.jsonl` |
| `escalated` | `running` | `resolve` | escalation.status = `resolved` |
| `escalated` | `abandoned` | `abandon` | escalation.resolution = `abandon` |
| `evidence_collected` | `verified` | `verify_ok` | `verification_refs` non-empty + oracle pass |
| `evidence_collected` | `running` | `verify_fail` | verification produced a failure record |
| `verified` | `completed` | `complete` | none (already verified) |
| `running` | `completed` | `complete_routine` | formal_verification_required=false; task-type claims and proportionate evidence valid |
| `running` | `aborted` | `abort` | reserved for future; not callable in M1 |

## 3. Illegal transitions (explicitly rejected)

- `pending` → `completed`
- `running` → `completed` when `formal_verification_required=true`
- `running` → `verified` (must pass through `evidence_collected`)
- Any state → `pending` (no rewinding)
- Any terminal state → any state (`completed`, `aborted`, `abandoned` are absorbing)

Attempting an incoherent completion causes receipt validation to fail with the missing route claim or evidence. Formal routes must pass through `verified`; routine routes may complete directly after proportionate evidence is recorded.

## 4. Mapping from v1 `status` to v2 `state`

v1 used a flat status field. The migrator `migrations/v1_to_v2.py` reconstructs a plausible state as follows:

| v1 `status` | v2 `state` | Notes |
|---|---|---|
| `in_progress` | `running` | Most common case |
| `completed` | `completed` | Assumed to have been verified at the time it was completed; the migrator does not re-verify |
| `abandoned` | `abandoned` | Preserved |

The v2 `status` field is kept as a read-only alias of `state` for the first six months after v2 GA. After that deprecation window (tracked in `MIGRATION.md`), writers stop emitting `status`.

## 5. Interaction with CI

Phase 1.5 and Phase 3 of `.github/workflows/governance.yml` currently validate by inspecting `governance_claims` and `evidence_refs`. After M1:

- `check-task-receipt.sh` additionally asserts that `state` is one of the legal enum values.
- `validate-receipt.py` asserts that the `(state, governance_claims)` combination is coherent (e.g., `state: verified` requires `verification_refs` to be non-empty).
- Incoherent combinations emit a structured error listing the offending state and the missing or excess claims.

## 6. Versioning

This state machine is declared at schema v2. Adding a state or transition in a future minor version (v2.1+) requires updating this document in the same PR and emitting a migration entry in `MIGRATION.md`. Removing a state is a major break.
