# Governance Kernel v2 Design

**Date:** 2026-04-23
**Status:** Proposed
**Depends on:** `2026-03-23-enforcement-mechanism-strengthening-design.md`, `2026-03-25-cross-platform-governance-attestation-implementation-plan.md`
**Authority:** `~/.config/claude-work/plans/sorted-squishing-pinwheel.md` §M1 (user-approved)
**Scope:** Freeze the four canonical governance objects — task, receipt, decision, provenance — as versioned YAML schemas with an explicit state machine and a migration framework. This is the foundation for the declarative policy engine (M2), runtime enforcement (M3), and verifiable attestation chain (M4).

**Convergence update (2026-08-29):** v2 now records risk-triggered route claims. Context gates remain mandatory, while formal Debug and Verification are conditional. The state machine permits `running -> completed` only for a routine route whose task-type claims and proportionate evidence validate; formal Verification routes must pass through `verified`.

## 1. Problem

The framework has shipped an attestation recording path: `governance-mcp-server/server.py` exposes nine MCP tools that write `.governance/attestations/T-*.receipt.yaml` and append to `index.jsonl`. `TASK_RECEIPT.schema.yaml` declares a `schema_version: 1` field, and the `--validate` family of scripts can parse receipts at rest.

Four concrete gaps block the move from *recording* to *governing*:

### 1.1 Schema version field is cosmetic

`governance-mcp-server/server.py:92, 362, 474` hard-codes `schema_version: 1` on every write. No migration registry exists. The moment a field becomes newly required, every already-bootstrapped downstream project breaks silently because old receipts still parse but fail validation. There is no upgrade path and no backwards-compatibility layer.

### 1.2 No explicit task state machine

The schema has `status: [in_progress, completed, abandoned]`, but nothing defines the legal transitions. An agent can call `governance_complete_task` on a receipt that has no evidence, no verification, no signed-off upstream — `_run_check` at `server.py:611` only runs `check-task-receipt.sh` with whatever claims happen to be present. The downstream CI gate is the first place an illegal transition is caught, which is both too late and too coarse.

### 1.3 Authority decisions are not first-class artifacts

`adapters/hermes/plugin/authority.py:33` returns `{"decision": "ALLOW" | "DENY"}` with a reason string, but that decision is not persisted anywhere structured. The audit JSONL at `.governance/audit/` records the *event* of a tool call, not the *policy reasoning* that allowed or denied it. Without a canonical Policy Decision Record (PDR), M3 runtime enforcement has nothing to emit, M4 verification has nothing to check, and autoresearch has no machine-readable input to optimize against.

### 1.4 No provenance model

Receipts record what was produced, not *under what conditions*. There is no `builder.id`, no `invocation` record, no `materials` list tying evidence artifacts to their source commits. This is acceptable for local recording but incompatible with M4's signing and replay-detection goals, and incompatible with any future SLSA-aligned release.

## 2. Decision Summary

### 2.1 Elevate `TASK_RECEIPT` to schema_version 2

Required additions in v2:

- `schema_version: 2` — mandatory, replaces the cosmetic v1 value.
- `state` — new field, distinct from `status`. State expresses the lifecycle position; `status` is deprecated toward an alias of `state` for backwards compatibility.
- `policy_version` — the version of the rule engine that governed this receipt's checks.
- `context_class` — one of `public | internal | restricted`. Drives which tool classes are permitted on this task (consumed by M3 authority rules).
- `actor` — an object `{kind: user|agent|ci|mcp, id: string, session_id?: string}`. Replaces the ambiguous `lifecycle.issuer` string.
- `signature` — optional object `{alg, key_id, value, signed_over}`. Present when `GOVERNANCE_SIGNING=1` (populated in M4; defined here so the field is stable).
- `provenance_ref` — optional path to a sibling `T-*.provenance.yaml` record.
- `governance_claims.debug_required`, `formal_verification_required`, and `route_reason` — explicit role-extension decisions. Routine bugs also require `root_cause_evidence` before code is staged.

All v1 fields remain readable; migration writes v2 without data loss.

### 2.2 Introduce explicit TASK_STATE_MACHINE

The state machine replaces the flat `status` enum with a transition graph. Legal transitions are enumerated in `docs/templates/governance/TASK_STATE_MACHINE.md`:

```
pending ──(start)──> running ──(collect_evidence)──> evidence_collected
                       │                                    │
                       │                                    ├──(verify_ok)──> verified ──(complete)──> completed
                       │                                    │
                       │                                    └──(verify_fail)──> running
                       │
                       ├──(escalate)──> escalated ──(resolve)──> running
                       │                          └──(abandon)──> abandoned
                       │
                       └──(abort)──> aborted
```

Illegal transitions: `pending → completed`, `running → completed` when `formal_verification_required=true`, any state → `pending` (no rewinding), `completed → *` (terminal). A validated routine route may use `running → completed` directly.

The state machine is enforced at two points: the MCP server rejects illegal `_update_state` calls, and the CI gate rejects receipts whose state+claims combination is incoherent.

### 2.3 Introduce `POLICY_DECISION_RECORD` as a first-class artifact

Every policy evaluation — whether by the engine (M2), a pre-tool hook (M3), or a verifier (M4) — emits a PDR. Location: `.governance/decisions.jsonl` (append-only; hash-chained in M4).

Required PDR fields:

```yaml
pdr_id: PDR-YYYYMMDD-NNN
task_id: T-YYYYMMDD-NNN        # nullable when decision is project-scope
actor:                          # who initiated the action being decided on
  kind: user | agent | ci | mcp
  id: string
  session_id: string?
subject:                        # what the action targets
  kind: file | tool | receipt | contract | commit
  id: string                    # path / tool name / task id / hash
action: string                  # "write", "invoke", "complete", "merge", ...
decision: ALLOW | DENY | ESCALATE
reason: string
rule_id: string                 # id of the rule that produced the decision
policy_version: string          # semver of the rule bundle
context_hash: string            # hash of relevant inputs (role, task state, target)
timestamp: ISO8601
```

PDRs are write-only from the perspective of agents: only `policy_engine` and the MCP server may append. Manual edits are rejected by M4 verifier once the chain is enabled.

### 2.4 Introduce `ATTESTATION_PROVENANCE` aligned to SLSA v1 concepts

For each receipt that produces a change to `docs/agents/` or code, an optional sibling `T-*.provenance.yaml` records:

```yaml
schema_version: 1              # provenance schema starts at 1
subject:
  digest:                      # content hash of the primary artifact
    sha256: ...
  name: ...                    # path or module name
builder:
  id: governance-mcp@0.x       # or agent identifier (claude-code, hermes, codex)
buildType: cg.governance/v2    # identifies this framework's contract
invocation:
  configSource:
    uri: ...                   # commit URL or path
    digest: {sha256: ...}
  parameters:                  # task_type, policy_version, role, etc.
  environment:                 # adapter, host, relevant env vars (redacted)
materials:                     # upstream sources consulted
  - uri: docs/agents/system/SYSTEM_INVARIANTS.md
    digest: {sha256: ...}
  - uri: docs/templates/governance/rules/derived-edits.rule.yaml
    digest: {sha256: ...}
signature: null                # populated in M4
```

This is deliberately *SLSA-inspired* rather than full SLSA-compliant: it uses the same shape so M4 can add signing without re-designing the record, but does not claim an L-level today.

### 2.5 Migration framework (v1 → v2)

Location: `governance-mcp-server/migrations/`. No PyYAML dependency — the existing hand-written parser at `server.py:216–316` is reused through a lightweight adapter.

Components:

- `registry.py` — maps `from_version → to_version → upgrader`.
- `v1_to_v2.py` — the concrete migrator. Infers `state` from v1 `status`, fills `actor.kind = "mcp"` when `issuer = "governance-mcp"`, sets `context_class = "internal"` as safe default, leaves `signature` null.
- `engine.py` — public API: `upgrade_in_memory(data, target_version)` and `write_latest(data, path)`.

Invariants:

- **Idempotent.** Running the migrator twice is a no-op.
- **Non-destructive.** The original file is never overwritten unless the caller passes `--write`; dry-run is the default.
- **Explicit.** Every upgraded field is logged in a side-by-side diff summary.
- **Opt-in on read.** When the MCP server reads a v1 receipt, it upgrades in memory only; the on-disk file stays v1 until the user runs `scripts/migrate-receipts.py` explicitly.

### 2.6 Backwards-compatibility contract (binding for all future schema changes)

1. Adding an optional field is a minor change and does not bump `schema_version`.
2. Adding a required field, changing a field's type, or changing an enum's meaning bumps `schema_version` and requires an entry in the migration registry.
3. Removing a field is a major break and requires a deprecation notice in `MIGRATION.md` one minor version in advance (activated in M5).
4. Readers accept any schema version ≤ current and upgrade in memory; writers always emit the current version.
5. v1 receipts in downstream projects remain readable for at least six calendar months after v2 GA.

## 3. Non-goals

The following are explicitly out of scope for this design and belong to later milestones; they are mentioned to prevent scope drift during M1 implementation:

- **Signing** (M4). Fields are reserved but never populated in M1.
- **Runtime enforcement** (M3). PDRs are defined here but only the MCP server writes them in M1; hook-driven emission comes in M3.
- **Multi-project federation** (M5). A `project_id` field is *not* added in v2 — the per-user decision recorded above is "project_id only, no federation". That field arrives in schema v2.1 as part of M5.
- **KMS / Sigstore integration** (M4.2+).
- **Keep-a-Changelog migration** (M5).

## 4. Touched files

### Modified

- `docs/templates/governance/TASK_RECEIPT.schema.yaml` — v1 → v2 upgrade in place, with `schema_version: 1` examples preserved in comments for migration reference.
- `governance-mcp-server/server.py` — remove hard-coded `schema_version: 1` at L92, L362, L474; route writes through `migrations.write_latest`.
- `governance-mcp-server/server.py:216–316` — extend hand-written parser's field whitelist for the new top-level keys (`state`, `policy_version`, `context_class`, `actor`, `signature`, `provenance_ref`).

### New

- `docs/templates/governance/POLICY_DECISION_RECORD.schema.yaml`
- `docs/templates/governance/ATTESTATION_PROVENANCE.schema.yaml`
- `docs/templates/governance/TASK_STATE_MACHINE.md`
- `governance-mcp-server/migrations/__init__.py`
- `governance-mcp-server/migrations/registry.py`
- `governance-mcp-server/migrations/v1_to_v2.py`
- `governance-mcp-server/migrations/engine.py`
- `scripts/migrate-receipts.py`
- `governance-mcp-server/tests/fixtures/v1/*.yaml`
- `governance-mcp-server/tests/fixtures/v2/*.yaml`
- `governance-mcp-server/tests/test_migrations.py`

## 5. Acceptance criteria (M1 exit)

1. `pytest governance-mcp-server/tests/` is green, with ≥ 6 new migration tests (one per task_type terminal case).
2. `scripts/migrate-receipts.py --dry-run` on `docs/examples/minimal-governed-repo/` produces a structured diff only (no writes), and on a fresh `.governance/` produces a no-op.
3. A deliberately corrupted v1 receipt (missing `task_id`, unknown `task_type`) is rejected by the migrator with a field-level error path.
4. The framework's own `tests/bootstrap-project.test.sh` and `tests/governance-e2e.test.sh` remain green after the schema upgrade.
5. A companion implementation plan at `docs/plans/2026-04-23-governance-kernel-v2-implementation-plan.md` is merged before any file under `docs/templates/governance/` is changed.

## 6. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Downstream projects break on read because the MCP server writes v2 but old validators expect v1 | Validators (`validate-receipt.py`) are updated in the same PR as the schema upgrade; added a `--accept-versions 1,2` flag |
| Hand-written YAML parser chokes on new nested object `actor: {kind, id, session_id}` | Added a targeted unit test in `test_server.py` for `_read_receipt` against every new nesting pattern before touching writers |
| `context_class` default of `internal` surprises users who assumed all tasks are public | Migration emits a log line; README and MIGRATION.md (M5) call this out explicitly |
| State machine rejects legitimate historical transitions found in downstream receipts | Migrator reconstructs a plausible state from v1 `status` using the mapping table in `v1_to_v2.py`; receipts that cannot be reconstructed are tagged `state: unknown` (reserved; never written by the server) |
| PDR file grows unbounded over long-running projects | Out of scope for M1; M5 adds retention policy in `docs/templates/governance/RETENTION_POLICY.md` |

## 7. Open questions

None remaining for M1 — the three approval-time questions (semver start, signing trust root, multi-project form) are resolved for later milestones (v0.5.0, local Ed25519, project_id only) and do not affect M1.
