---
name: governance-check
description: Validates Context Governance compliance — task routing, protected artifact checks, receipt management, and pre-commit gates.
---

# Governance Check Skill (Codex Adapter)

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

If the MCP governance server is available:

- Call `governance_start_task` to create a receipt
- Call `governance_update_receipt` as evidence is produced
- Call `governance_complete_task` when done

If MCP is unavailable:

- Create receipt manually per `docs/templates/governance/MANUAL_ATTESTATION_POLICY.md`
- Set `attestation_mode: manual_attestation` with reason

### 5. Pre-Commit Validation

Before committing:

- Ensure `CG-Task: T-YYYYMMDD-NNN` trailer is in the commit message
- Run `scripts/check-commit-governance.sh` to validate all gates
- If any check fails, resolve before committing
