---
name: governance-check
description: Validates Context Governance compliance — task routing, protected artifact checks, receipt management, and pre-commit gates. For use with Hermes Agent.
---

# Governance Check Skill (Hermes Adapter)

## When to Activate

- Before starting any governed task (bug, feature, refactor, design, architecture)
- Before committing changes
- When the agent needs to verify governance compliance

## Instructions

### 1. Task Classification

Classify the current task using `docs/agents/system/ROUTING_POLICY.md`:

| Task Type | Route |
|-----------|-------|
| Bug/regression/test failure | System → Module → Debug → Implementation → Verification |
| Feature/code change/refactor | System → Module → Implementation → Verification |
| Design/architecture/protocol | System → Module → Verification |

### 2. Pre-Work Validation

Before modifying code:

- Verify the target module has a `MODULE_CONTRACT.md` in `docs/agents/modules/<name>/`
- For bug tasks: verify a `DEBUG_CASE` exists or will be created first
- Check governance mode in `docs/agents/execution/GOVERNANCE_MODE.md`

### 3. Protected Artifacts

Do NOT modify these files directly:

- **Tier 0:** `docs/agents/PROJECT_BASELINE.md`
- **Tier 0.5:** `SYSTEM_GOAL_PACK.md`, `SYSTEM_INVARIANTS.md`, `SYSTEM_AUTHORITY_MAP.md`, `ROUTING_POLICY.md`
- **Tier 0.8:** `ENGINEERING_CONSTRAINTS.md`, `SYSTEM_ARCHITECTURE.md`, `PROJECT_ARCHITECTURE_BASELINE.md`

If these need changes, escalate to System Architect.

### 4. Receipt Management

Use the governance MCP tools (auto-discovered by Hermes from `context-governance` MCP server):

- Call `governance_start_task` to create a receipt
- Call `governance_update_receipt` as evidence is produced
- Call `governance_complete_task` when done

If MCP is unavailable:

- Create receipt manually per `docs/templates/governance/MANUAL_ATTESTATION_POLICY.md`
- Set `attestation_mode: manual_attestation` with reason

### 5. Pre-Commit Validation

Before committing:

- Ensure `CG-Task: T-YYYYMMDD-NNN` trailer is in the commit message
- Run `governance_run_checks` via MCP (or `scripts/check-commit-governance.sh` directly)
- If any check fails, resolve before committing

### 6. Hermes-Specific Notes

- **Memory is context, documents are truth.** Hermes persistent memory may contain governance state from prior sessions. Always verify against the actual files in `docs/agents/` per HARD-GATE requirements.
- **Cron job outputs are advisory.** Scheduled governance checks report findings but do not modify governance artifacts.
- **Notifications are push-only.** Escalation notifications sent via Slack/Telegram are informational; the canonical state is in `.governance/escalations.jsonl`.
