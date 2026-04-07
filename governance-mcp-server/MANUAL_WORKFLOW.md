# Manual Governance Workflow (Without MCP)

When the MCP attestation server is unavailable, all governance work can be completed manually. CI and approval rules become stricter for manually-attested work.

---

## Step 1: Determine Task ID

```bash
# Check existing tasks for today
cat .governance/attestations/index.jsonl | grep "$(date +%Y%m%d)" | tail -1

# Pick the next sequence number (e.g., if last was T-20260325-002, use T-20260325-003)
# If no tasks today, start with T-YYYYMMDD-001
```

## Step 2: Create Receipt

```bash
TASK_ID="T-20260325-001"
cat > .governance/attestations/${TASK_ID}.receipt.yaml << 'EOF'
schema_version: 1
task_id: T-20260325-001
task_type: bug
status: in_progress
attestation_mode: manual_attestation
manual_fallback_reason: "MCP server not available in offline environment"

scope:
  affected_modules: [auth]
  affected_paths:
    - src/auth/handler.ts

governance_claims:
  debug_case_present: false
  module_contract_refs: []

evidence_refs: []

lifecycle:
  created_at: 2026-03-25T10:00:00Z
  updated_at: 2026-03-25T10:00:00Z
  issuer: manual
  session_ids: []
EOF
```

## Step 3: Update Index

```bash
echo '{"task_id":"T-20260325-001","task_type":"bug","status":"in_progress","receipt_path":".governance/attestations/T-20260325-001.receipt.yaml","created_at":"2026-03-25T10:00:00Z","updated_at":"2026-03-25T10:00:00Z","attestation_mode":"manual_attestation"}' >> .governance/attestations/index.jsonl
```

## Step 4: Create Current Task Marker (for Phase 1.5 scripts)

```bash
cat > .governance/current-task.json << 'EOF'
{
  "task_type": "bug",
  "task_id": "T-20260325-001",
  "affected_modules": ["auth"],
  "created_by": "manual",
  "created_at": "2026-03-25T10:00:00Z"
}
EOF
```

## Step 5: Do Your Work

Follow the governance routing protocol:
1. For bugs: create a DEBUG_CASE before fixing code
2. For features: verify MODULE_CONTRACT covers your changes
3. For all: follow ROUTING_POLICY routing order

## Step 6: Update Receipt with Evidence

As you produce evidence, update the receipt:

```yaml
governance_claims:
  debug_case_present: true
  module_contract_refs:
    - docs/agents/modules/auth/MODULE_CONTRACT.md

evidence_refs:
  - path: docs/agents/debug/cases/DEBUG_CASE_auth_session.md
    kind: debug_case
    upstream_hash: null
  - path: docs/agents/modules/auth/MODULE_CONTRACT.md
    kind: module_contract
    upstream_hash: a1b2c3d
```

## Step 7: Commit with Trailer

```bash
git add .
git commit -m "fix(auth): resolve session expiry race condition

CG-Task: T-20260325-001"
```

## Step 8: Complete Task

Update receipt status and index:

```bash
# In receipt YAML: change status: in_progress → status: completed
sed -i 's/status: in_progress/status: completed/' .governance/attestations/T-20260325-001.receipt.yaml

# Update index line (replace status)
# Then remove current-task.json
rm .governance/current-task.json
```

## Step 9: PR and Merge

- CI will flag `manual_attestation` in PR checks
- Reviewer must explicitly approve manual attestation
- All evidence requirements still enforced by CI

---

## Quick Reference: Required Claims by Task Type

| Type | Must have in receipt |
|------|---------------------|
| bug | `debug_case_present: true`, `module_contract_refs`, evidence kinds: `debug_case` + `module_contract` |
| feature/refactor | `module_contract_refs`, evidence kind: `module_contract` |
| design/architecture/protocol | Base schema only |
| trivial | Nothing beyond base |
