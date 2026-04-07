# Governance Check Skill (Codex Adapter)

## Description

Validates governance compliance before and after task execution within Codex sessions. This skill provides the same governance routing and validation as the Claude Code hooks and pre-commit gates, adapted for the Codex platform.

## When to Activate

- Before starting any governed task (bug, feature, refactor, design, architecture)
- Before committing changes
- When the agent needs to verify governance compliance

## Instructions

When activated, perform the following governance checks:

### 1. Task Classification

Classify the current task using ROUTING_POLICY.md:

| Task Type | Route |
|-----------|-------|
| Bug/regression/test failure | System → Module → Debug → Implementation → Verification |
| Feature/code change/refactor | System → Module → Implementation → Verification |
| Design/architecture/protocol | System → Module → Verification |

### 2. Pre-Work Validation

Before modifying code:

- Verify the target module has a `MODULE_CONTRACT.md` in `docs/agents/modules/<name>/`
- Check for pending escalations in `.governance/escalations.jsonl`
- For bug tasks: verify a `DEBUG_CASE` exists or will be created first
- Check governance mode in `docs/agents/execution/GOVERNANCE_MODE.md`

### 3. Receipt Management

If the MCP governance server is available:

- Call `governance_start_task` to create a receipt
- Call `governance_update_receipt` as evidence is produced
- Call `governance_complete_task` when done

If MCP is unavailable:

- Create receipt manually per `MANUAL_ATTESTATION_POLICY.md`
- Set `attestation_mode: manual_attestation` with reason

### 4. Pre-Commit Validation

Before committing:

- Ensure `CG-Task: T-YYYYMMDD-NNN` trailer is in the commit message
- Run `scripts/check-commit-governance.sh` to validate all gates
- If any check fails, resolve before committing

### 5. Protected Artifacts

Do NOT modify these files directly:

- **Tier 0:** `PROJECT_BASELINE.md`
- **Tier 0.5:** `SYSTEM_GOAL_PACK.md`, `SYSTEM_INVARIANTS.md`, `SYSTEM_AUTHORITY_MAP.md`, `ROUTING_POLICY.md`
- **Tier 0.8:** `ENGINEERING_CONSTRAINTS.md`, `SYSTEM_ARCHITECTURE.md`, `PROJECT_ARCHITECTURE_BASELINE.md`

If these need changes, escalate to System Architect.
