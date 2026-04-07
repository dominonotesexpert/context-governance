# Manual Attestation Policy

**Authority:** `docs/plans/2026-03-24-deerflow-inspired-governance-engine-plan.md` §3.6, §5.4

---

## Purpose

When the MCP attestation service is unavailable or intentionally bypassed, governed work may still proceed using manual attestation. This policy defines the rules and constraints for that path.

---

## When Manual Attestation Applies

- MCP server is not running or not configured
- Offline development environment
- Platform does not support MCP (e.g., some CI environments)
- Emergency hotfix where MCP setup would delay critical work

---

## Rules

### 1. Explicit Mode Declaration

The receipt must declare:

```yaml
attestation_mode: manual_attestation
manual_fallback_reason: "MCP server unavailable during offline development"
```

Both fields are required. A receipt with `attestation_mode: manual_attestation` and an empty or missing `manual_fallback_reason` is invalid.

### 2. Evidence Requirements Are Not Relaxed

All formal evidence references required by the task type (per `TASK_RECEIPT.schema.yaml` §3.4A) remain mandatory:

- `bug` tasks still require `debug_case_present: true` and `module_contract_refs`
- `feature`/`refactor` tasks still require `module_contract_refs`
- All referenced `evidence_refs` artifacts must exist and be parseable

Manual attestation reduces the issuance mechanism's trustworthiness, not the evidence bar.

### 3. CI Flags Manual Attestation

CI must:

- Detect `attestation_mode: manual_attestation` in any receipt bound to the PR
- Add a visible annotation or check output indicating manual attestation is present
- Not auto-pass: manual attestation requires additional human review

### 4. Protected Branch Merge Requires Human Approval

Commits bound to manually-attested receipts cannot merge to protected branches without:

- Passing all governance CI checks
- Explicit human approval from a reviewer with governance authority
- The reviewer acknowledging the manual attestation flag

### 5. Audit Trail

Manual attestation receipts are committed alongside MCP-issued receipts. The `attestation_mode` field provides permanent audit distinction.

---

## Manual Receipt Creation Process

When MCP is unavailable:

1. **Create the receipt file manually:**
   ```bash
   # Choose the next available task ID
   cat .governance/attestations/index.jsonl | tail -1
   # Create receipt
   cp docs/templates/governance/TASK_RECEIPT.example.yaml \
      .governance/attestations/T-YYYYMMDD-NNN.receipt.yaml
   # Edit with actual values
   ```

2. **Set attestation fields:**
   ```yaml
   attestation_mode: manual_attestation
   manual_fallback_reason: "<explain why MCP was not used>"
   ```

3. **Fill all required claims** for the declared `task_type`.

4. **Update the index:**
   Append a line to `.governance/attestations/index.jsonl`.

5. **Bind to commit:**
   Include `CG-Task: T-YYYYMMDD-NNN` trailer in commit message.

---

## What Manual Attestation Does NOT Allow

- Skipping evidence requirements
- Bypassing pre-commit governance checks
- Merging to protected branches without human approval
- Treating the manual path as equivalent trust to MCP-issued receipts
- Creating receipts without `manual_fallback_reason`

---

## Governance Mode Interaction

- In `incident` mode: manual attestation is expected (speed is prioritized); deferred items must be completed in post-incident review
- In `exploration` mode: manual attestation is allowed; receipts may reference draft artifacts
- In `exception` mode: manual attestation must record which claims are intentionally absent
- In `migration` mode: manual attestation is allowed within the declared migration envelope
