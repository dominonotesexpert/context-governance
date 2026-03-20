---
artifact_type: governance-progress
status: proposed
owner_role: system-architect
scope: execution
downstream_consumers: [all-roles]
last_reviewed: YYYY-MM-DD
---

# GOVERNANCE_PROGRESS

> Cross-session state file for a single governance task.
> One file per task: `GOVERNANCE_PROGRESS-{task_id}.json`
> Designed for a single developer resuming work across days/weeks.

## Usage

- Each agent role updates this file after completing its step
- Next session reads this file to restore context without replaying conversation history
- When all steps are done, move to `docs/agents/execution/completed/`
- If file is lost, reconstruct from git log and existing artifacts

## Template

```json
{
  "task_id": "{YYYY-MM-DD}-{short-description}",
  "task_description": "",
  "route": "System → Module → Implementation → Verification",
  "current_step": "pending",
  "completed_steps": [],
  "pending_steps": ["system-architect", "module-architect", "implementation", "verification"],
  "context_snapshot": {
    "baseline_reference": "",
    "baseline_version": "",
    "unresolved_escalations": [],
    "key_decisions": []
  },
  "last_updated": ""
}
```

## Field Definitions

| Field | Description |
|-------|-------------|
| `task_id` | Unique identifier, format: `YYYY-MM-DD-short-description` |
| `task_description` | One sentence describing what needs to be done |
| `route` | The governance route for this task type |
| `current_step` | Which agent role is currently active |
| `completed_steps` | Array of completed steps with `role`, `status`, `artifacts_produced`, `key_decisions` |
| `pending_steps` | Remaining steps in order |
| `context_snapshot.baseline_reference` | Which BASELINE sections are relevant |
| `context_snapshot.baseline_version` | BASELINE version at task start |
| `context_snapshot.unresolved_escalations` | Open escalations that need resolution |
| `context_snapshot.key_decisions` | Architecture decisions made during this task (survives compression) |
| `last_updated` | ISO 8601 timestamp |
