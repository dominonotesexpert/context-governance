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
| Routine local bug | System → Module → Implementation; requires route reason + root-cause evidence |
| Production/cross-stage/repeated/ambiguous bug | System → Module → Debug → Implementation |
| Feature/code change/refactor | System → Module → Implementation |
| Design/architecture/protocol | System → Module; no implementation unless requested |
| Release/merge/deploy/security/cross-module/formal acceptance | Append formal Verification |

### 2. Pre-Work Validation

Before modifying code:

- Verify the target module has a `MODULE_CONTRACT.md` in `docs/agents/modules/<name>/`
- For a formal Debug route: verify a `DEBUG_CASE` exists or will be created first
- For a routine bug: verify `route_reason` and `root_cause_evidence` are recorded before code is staged
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

### 6. Runtime Enforcement Limitation (M3)

**Important:** Codex's `workspace-write` sandbox does not expose a pre-tool-call
hook API; runtime authority enforcement is therefore **structurally unavailable
on this platform**. This adapter does not claim compliance with
`docs/templates/adapter/ADAPTER_ENFORCEMENT_CONTRACT.md` v1.

Governance is enforced on Codex via two indirect paths:

1. **Agent self-restraint** — the prompts in AGENTS.md and this skill instruct
   the agent to refuse edits to protected artifacts. This is advisory.
2. **Pre-commit gates** — `scripts/check-commit-governance.sh` runs the
   declarative policy engine against staged files. Any violation blocks the
   commit. This is the authoritative enforcement on Codex.

If you need runtime enforcement (not just pre-commit), use the Claude Code
adapter which supports true PreToolUse blocking.

Policy Decision Records (PDRs) in `.governance/decisions.jsonl` are produced
on Codex only at pre-commit time (M2 rules). The M3 runtime-decision PDR
stream is empty for Codex sessions.
