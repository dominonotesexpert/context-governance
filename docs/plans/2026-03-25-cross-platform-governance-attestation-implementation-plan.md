# Cross-Platform Governance Attestation — Implementation Plan

**Date:** 2026-03-25
**Status:** Proposed
**Design source:** `2026-03-24-deerflow-inspired-governance-engine-plan.md`
**Current baseline:** Phase 0 ~ 1.5 已完成，Phase 2 ~ 7 待实施

---

## 0. Implementation Status Snapshot

| Phase | Status | Key Artifacts |
|-------|--------|---------------|
| Phase 0 | ✅ Done | `check-derived-edits.sh`, `check-hardgate.sh`, `check-staleness.sh` |
| Phase 1 | ✅ Done | Design doc revised, authority model established |
| Phase 1.5 | ✅ Done | `check-commit-governance.sh`, `check-module-contract.sh`, `check-escalation-block.sh`, `check-bug-evidence.sh`, `.githooks/pre-commit`, bootstrap integration |
| Phase 2 | ❌ Pending | Receipt schema, index format, manual attestation rules, task binding spec |
| Phase 3 | ❌ Pending | Receipt validation scripts, CI gate, branch protection |
| Phase 4 | ❌ Pending | Codex adapter, Claude Code adapter |
| Phase 5 | ❌ Pending | MCP attestation service |
| Phase 6 | ❌ Pending | Autoresearch integration |
| Phase 7 | ❌ Pending | Cross-platform verification |

---

## 1. Phase 2: Attestation Schema（估计 7 个任务）

**Goal:** Define machine-checkable receipt format, index format, manual attestation rules, and task-binding convention.

### Task 2.1 — Canonical Receipt Schema

**Deliverable:** `docs/templates/governance/TASK_RECEIPT.schema.yaml`

Define the YAML schema per design §3.4:

```yaml
schema_version: 1
task_id: string        # T-YYYYMMDD-NNN
task_type: enum        # bug | feature | refactor | design | architecture | protocol | contract_authoring | trivial
status: enum           # in_progress | completed | abandoned
attestation_mode: enum # mcp | manual_attestation
manual_fallback_reason: string | null

scope:
  affected_modules: [string]
  affected_paths: [string]

governance_claims:
  debug_case_present: boolean | null
  module_contract_refs: [string]
  verification_refs: [string]
  engineering_constraint_refs: [string]

evidence_refs:
  - path: string
    kind: enum  # debug_case | module_contract | acceptance_rules | verification_oracle | engineering_constraint
    upstream_hash: string | null

lifecycle:
  created_at: ISO8601
  updated_at: ISO8601
  issuer: string
  session_ids: [string]
```

**Acceptance:** Schema YAML parseable; includes per-task-type required claims table (§3.4A).

### Task 2.2 — Receipt Index Format

**Deliverable:** `docs/templates/governance/ATTESTATION_INDEX.schema.md`

Define `.governance/attestations/index.jsonl` line format:

```json
{"task_id":"T-20260325-001","task_type":"bug","status":"completed","receipt_path":".governance/attestations/T-20260325-001.receipt.yaml","created_at":"...","updated_at":"..."}
```

**Acceptance:** Format documented; includes field descriptions and lifecycle rules.

### Task 2.3 — Manual Attestation Policy

**Deliverable:** `docs/templates/governance/MANUAL_ATTESTATION_POLICY.md`

Per design §3.6:
- `attestation_mode: manual_attestation` requires `manual_fallback_reason`
- All formal `evidence_refs` are still required
- CI must flag manual attestation
- Protected branch merge requires explicit human approval

**Acceptance:** Policy documented with examples.

### Task 2.4 — Task Binding Convention (CG-Task Trailer)

**Deliverable:** Section in receipt schema doc + example commit

Per design §4.1:
- Primary binding: `CG-Task: T-YYYYMMDD-NNN` git commit trailer
- Secondary: branch naming convention `cg/<task_id>/<description>`
- One task ID may span multiple commits/sessions
- One commit should normally bind to one primary task ID

**Acceptance:** Convention documented; example trailer shown.

### Task 2.5 — Governance Mode Interaction Rules

**Deliverable:** Section in receipt schema doc

Per design §3.7:
- `incident` mode: receipt requirements may be partially deferred
- `exploration` mode: receipts may reference draft artifacts
- `exception` mode: receipts record intentionally absent claims
- `migration` mode: receipts record scoped deviations

**Acceptance:** Each mode's receipt behavior documented with examples.

### Task 2.6 — `.governance/` Directory Scaffold

**Deliverable:** `.governance/` directory in this repo (for self-governance)

Create:
```
.governance/
├── attestations/
│   └── .gitkeep
├── audit/          (gitignored)
├── sessions/       (gitignored)
└── steps/          (gitignored)
```

Update `.gitignore` per design §3.3.

**Acceptance:** Directory exists; gitignore rules match design.

### Task 2.7 — Bootstrap Script Phase 2 Update

**Deliverable:** Update `scripts/bootstrap-project.sh`

- Add attestation index initialization (empty `index.jsonl`)
- Add receipt schema validation in `--validate` mode
- Ensure `.governance/attestations/` is committed, others gitignored

**Acceptance:** `bootstrap-project.sh --validate` checks attestation directory structure.

---

## 2. Phase 3: Local and CI Gates（估计 8 个任务）

**Goal:** Implement receipt validation scripts and CI enforcement.

**Dependency:** Phase 2 complete (schema must exist before validation scripts).

### Task 3.1 — `check-task-binding.sh`

**Deliverable:** `scripts/check-task-binding.sh`

Per design §8.2:
- Validate commit message contains `CG-Task: T-YYYYMMDD-NNN` trailer
- Validate referenced task ID format
- Exit 0 = valid, Exit 1 = violation

**Acceptance:** Blocks commits without valid CG-Task trailer (when receipt system is active).

### Task 3.2 — `check-task-receipt.sh`

**Deliverable:** `scripts/check-task-receipt.sh`

Per design §3.4A:
- Validate receipt YAML against schema
- Validate per-task-type required claims:
  - `bug` → `debug_case_present: true` + `module_contract_refs`
  - `feature`/`refactor` → `module_contract_refs`
  - `design`/`architecture`/`protocol`/`contract_authoring` → base schema only
  - `trivial` → no claims required
- Validate `evidence_refs` exist and are parseable
- Validate `upstream_hash` freshness if present (delegate to `check-staleness.sh`)

**Acceptance:** Unit tests per task type; blocks incomplete receipts.

### Task 3.3 — `check-receipt-scope.sh`

**Deliverable:** `scripts/check-receipt-scope.sh`

Per design §4.3:
- Compare staged/changed files against receipt `affected_paths`
- Warn or block if changed files fall outside receipt scope
- Module ownership comes from governance docs, not receipt

**Acceptance:** Blocks commits with out-of-scope changes.

### Task 3.4 — `check-manual-attestation-policy.sh`

**Deliverable:** `scripts/check-manual-attestation-policy.sh`

Per design §3.6:
- If `attestation_mode: manual_attestation`, verify `manual_fallback_reason` is non-empty
- Verify all `evidence_refs` still present
- Output warning for CI visibility

**Acceptance:** Blocks manual attestation without reason.

### Task 3.5 — Activate Phase 3 in `check-commit-governance.sh`

**Deliverable:** Update `scripts/check-commit-governance.sh`

- Uncomment Phase 3 checks (currently lines 49-52)
- Add activation flag: only run receipt checks when `.governance/attestations/` exists
- Maintain backward compatibility for repos not yet using receipts

**Acceptance:** Pre-commit runs all Phase 1.5 + Phase 3 checks when attestation is active.

### Task 3.6 — CI Governance Gate (GitHub Actions)

**Deliverable:** `.github/workflows/governance.yml`

Per design §7.2:
- Run `check-commit-governance.sh` on every PR
- Validate receipt/evidence consistency for all commits in PR
- Flag `manual_attestation` paths
- Check derivation freshness
- Required status check for protected branches

**Acceptance:** CI blocks non-compliant PRs; passes compliant ones.

### Task 3.7 — Branch Protection Documentation

**Deliverable:** `docs/templates/governance/BRANCH_PROTECTION.md`

Per design §7.3:
- Protected branches require passing governance CI
- Manual attestation requires explicit approval
- Normal code review still required

**Acceptance:** Setup guide documented.

### Task 3.8 — Bootstrap Script Phase 3 Update

**Deliverable:** Update `scripts/bootstrap-project.sh`

- Copy Phase 3 scripts to target projects
- Initialize `index.jsonl`
- Add `--validate` checks for receipt completeness
- Generate CI workflow file for target project

**Acceptance:** Full bootstrap creates complete governance scaffold.

---

## 3. Phase 4: Platform Adapters（估计 6 个任务）

**Goal:** Wire Codex and Claude Code platform-specific enforcement.

**Dependency:** Phase 3 complete (gates must exist before adapters wire into them).

### Task 4.1 — Adapter Directory Structure

**Deliverable:** Create `adapters/` directory:
```
adapters/
├── codex/
│   ├── config.toml.template
│   └── skills/
│       └── governance-check/
└── claude-code/
    ├── hooks.json.template
    └── skills/
```

### Task 4.2 — Claude Code Hook Registration

**Deliverable:** `adapters/claude-code/hooks.json.template`

Per design §6.2:
- Tier 0/0.5/0.8 edit blocking hooks
- Audit capture hook
- Governance bypass warning hook

**Acceptance:** Hooks block protected file edits in Claude Code.

### Task 4.3 — Codex Sandbox Configuration

**Deliverable:** `adapters/codex/config.toml.template`

Per design §6.1:
- MCP server registration
- Sandbox/filesystem restrictions for Tier 0/0.5/0.8
- Skill configuration

**Acceptance:** Codex config protects governed files.

### Task 4.4 — Codex Governance Skill

**Deliverable:** `adapters/codex/skills/governance-check/`

- Skill-guided routing for Codex
- Maps to same receipt issuance model

### Task 4.5 — Bootstrap `--adapter` Flag

**Deliverable:** Update `scripts/bootstrap-project.sh`

Per design §9.1 Phase 4:
- Add `--adapter codex|claude-code` flag (default: `claude-code`)
- `--adapter codex`: generate `.codex/config.toml`
- `--adapter claude-code`: update `.claude/settings.local.json`

**Acceptance:** Bootstrap creates platform-specific configuration.

### Task 4.6 — Adapter Parity Tests

**Deliverable:** `tests/adapter-parity.test.sh`

Per design §6.3:
- Same receipt schema on both platforms
- Same evidence requirements
- Same pre-commit rules
- Same CI rules

**Acceptance:** Tests verify equivalent acceptance rules across platforms.

---

## 4. Phase 5: MCP Attestation Service（估计 5 个任务）

**Goal:** Implement MCP server for receipt issuance and governance workflow.

**Dependency:** Phase 2 (schema) + Phase 3 (gates) + Phase 4 (adapter wiring).

### Task 5.1 — MCP Server Scaffold

**Deliverable:** `governance-mcp-server/`

```
governance-mcp-server/
├── server.py          # FastMCP or stdio-based server
├── requirements.txt
├── tools/
│   ├── start_task.py
│   ├── update_receipt.py
│   ├── record_debug_case.py
│   ├── record_escalation.py
│   ├── record_verification.py
│   └── complete_task.py
└── tests/
```

### Task 5.2 — Core MCP Tools

**Deliverable:** 6 MCP tools per design §5.2:

| Tool | Purpose |
|------|---------|
| `governance_start_task` | Create receipt + `current-task.json` |
| `governance_update_receipt` | Update receipt claims/scope |
| `governance_record_debug_case` | Attach debug case evidence |
| `governance_record_escalation` | Record escalation in `.governance/escalations.jsonl` |
| `governance_record_verification` | Attach verification evidence |
| `governance_complete_task` | Finalize receipt, update index |

**Acceptance:** Each tool creates/updates valid receipt YAML.

### Task 5.3 — MCP Integration with Existing Checks

Per design §5.2:
- Hardgate: delegate to `check-hardgate.sh`
- Staleness: delegate to `check-staleness.sh`
- Derived edits: delegate to `check-derived-edits.sh`

**Acceptance:** MCP tools compose existing scripts rather than duplicating logic.

### Task 5.4 — Manual Fallback Path

Per design §5.4:
- When MCP unavailable, manual receipt creation documented
- `current-task.json` can be created manually
- CI/approval rules stricter for manual path

**Acceptance:** Full workflow works without MCP running.

### Task 5.5 — MCP Server Tests

**Deliverable:** `governance-mcp-server/tests/`

- Tool input/output validation
- Receipt schema compliance
- Integration with check scripts

---

## 5. Phase 6: Autoresearch Integration（估计 2 个任务）

**Goal:** Define how governance-optimization tasks fit into the attestation model.

**Dependency:** Phase 5 (MCP tools must exist).

### Task 6.1 — Autoresearch Receipt Requirements

**Deliverable:** Add `autoresearch` task type to receipt schema

- Define required claims for governance-optimization work
- Ensure optimization outputs escalate upstream (never rewrite downstream truth)

### Task 6.2 — Autoresearch MCP Tool Integration

**Deliverable:** Add autoresearch-specific MCP tool or extend `governance_start_task`

- `task_type: autoresearch` starts with appropriate defaults
- Evidence refs point to optimization artifacts

---

## 6. Phase 7: End-to-End Verification（估计 4 个任务）

**Goal:** Prove the system works across platforms and failure modes.

**Dependency:** All prior phases.

### Task 7.1 — Cross-Platform Acceptance Parity Tests

Per design §7 item 1:
- Same governed change accepted/rejected on both platforms
- Receipt schema identical

### Task 7.2 — Receipt vs Evidence Consistency Tests

Per design §7 item 2:
- Stale evidence → receipt rejected
- Missing evidence → receipt rejected
- Valid evidence → receipt accepted

### Task 7.3 — Manual Attestation Approval Path Tests

Per design §7 item 3:
- Manual attestation without approval → blocked
- Manual attestation with approval → accepted

### Task 7.4 — End-to-End Bootstrap → Task → Pre-commit → CI

Per design §7 item 4:
- Bootstrap new project
- Create governed task
- Make changes with receipt
- Pre-commit validates
- CI validates
- Merge succeeds

---

## 7. Implementation Order and Dependencies

```
Phase 2 (Schema)
    │
    ▼
Phase 3 (Gates)
    │
    ├──────────┐
    ▼          ▼
Phase 4    Phase 5
(Adapters) (MCP)
    │          │
    └────┬─────┘
         ▼
    Phase 6
    (Autoresearch)
         │
         ▼
    Phase 7
    (Verification)
```

**Phases 4 and 5 can proceed in parallel** once Phase 3 is complete.

---

## 8. Priority Recommendation

**Immediate next step: Phase 2 (Attestation Schema)**

Rationale:
- All subsequent phases depend on the schema definition
- Schema is a pure documentation/design task with no code risk
- Unblocks Phase 3 scripts and Phase 5 MCP tools simultaneously

**Highest-value next: Phase 3 (CI Gate)**

Rationale:
- CI is the "final judge" per design — without it, governance is advisory only
- The `.github/workflows/governance.yml` is the single most impactful deliverable for enforcement credibility

---

## 9. Estimated Total Tasks

| Phase | Tasks | Status |
|-------|-------|--------|
| Phase 2 | 7 | Pending |
| Phase 3 | 8 | Pending |
| Phase 4 | 6 | Pending |
| Phase 5 | 5 | Pending |
| Phase 6 | 2 | Pending |
| Phase 7 | 4 | Pending |
| **Total** | **32** | |

---

## 10. Success Criteria (from design §11)

Implementation is complete when:

1. `docs/agents/` remains sole authority source — no projection overrides
2. Every governed task type has a canonical receipt path
3. `pre-commit` blocks missing/mismatched task binding and evidence
4. CI rejects invalid receipts and unreconciled evidence
5. Codex and Claude Code share identical receipt/acceptance model
6. Framework can honestly claim: "Governed changes require attestation plus formal evidence and are blocked by repository gates when non-compliant"
