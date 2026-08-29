# Governance Kernel v2 Implementation Plan

**Date:** 2026-04-23
**Status:** Active
**Design doc:** `2026-04-23-governance-kernel-v2-design.md`
**Upstream authority:** `~/.config/claude-work/plans/sorted-squishing-pinwheel.md` §M1
**Scope:** Concrete, ordered steps to land schema v2, the state machine, PDR and Provenance schemas, and a v1→v2 migration framework without breaking any already-bootstrapped downstream project.

## 1. Dependency order (must be followed)

```
Step A  POLICY_DECISION_RECORD.schema.yaml       (no deps)
Step A  ATTESTATION_PROVENANCE.schema.yaml       (no deps)
Step A  TASK_STATE_MACHINE.md                    (no deps)
Step B  TASK_RECEIPT.schema.yaml → v2            (requires Step A state machine)
Step C  migrations/engine + registry + v1_to_v2  (requires Step B)
Step D  scripts/migrate-receipts.py              (requires Step C)
Step E  server.py schema wiring                  (requires Step B + C)
Step F  fixtures/v1 and fixtures/v2              (requires Step B)
Step G  test_migrations.py                       (requires Step C + D + F)
Step H  validators accept v1 and v2              (requires Step B)
Step I  e2e test run + downstream dry-run        (requires all above)
```

Steps A, F are parallelizable within themselves; the rest are strictly sequential.

## 2. Step-by-step

### Step A — companion schemas and state machine

| File | Action | Notes |
|---|---|---|
| `docs/templates/governance/TASK_STATE_MACHINE.md` | Create | Enumerate states, transitions, illegal transitions, and the mapping from v1 `status` to v2 `state`. |
| `docs/templates/governance/POLICY_DECISION_RECORD.schema.yaml` | Create | Follow the shape defined in design §2.3. Mark `chain_prev_hash` as reserved (populated in M4). |
| `docs/templates/governance/ATTESTATION_PROVENANCE.schema.yaml` | Create | Follow design §2.4. Mark `signature` as `nullable: true`, populated in M4. |

### Step B — TASK_RECEIPT.schema.yaml → v2

- Bump header comment to `# Version: 2`.
- Add `schema_version` example `2`; keep v1 example in a trailing comment block titled "Historical example (v1)".
- Add new top-level fields: `state`, `policy_version`, `context_class`, `actor`, `signature`, `provenance_ref`.
- `status` retained but marked *deprecated alias of `state`*; readers must accept both.
- Update the "Required Claims by Task Type" table to include `context_class` default per task_type.

### Step C — migrations package

Files under `governance-mcp-server/migrations/`:

- `__init__.py` — exports `upgrade_in_memory`, `write_latest`, `CURRENT_VERSION`.
- `registry.py` — maps `(from, to) → upgrader`.
- `v1_to_v2.py` — the actual upgrader. Key mappings:

| v1 | v2 |
|---|---|
| `status: in_progress` | `state: running`, `status: in_progress` |
| `status: completed` | `state: completed`, `status: completed` |
| `status: abandoned` | `state: abandoned`, `status: abandoned` |
| `lifecycle.issuer: governance-mcp` | `actor: {kind: mcp, id: governance-mcp}` + preserve `lifecycle.issuer` |
| `lifecycle.issuer: manual` (or other) | `actor: {kind: user, id: <issuer>}` |
| (missing) `context_class` | `context_class: internal` |
| (missing) `policy_version` | `policy_version: "unversioned-v1"` |
| `signature` | always `null` in M1 |

- `engine.py` — small orchestrator; picks the chain of upgraders from `registry`. Fails loudly on unknown `schema_version`.

### Step D — `scripts/migrate-receipts.py`

CLI behavior:

```
migrate-receipts.py [--target DIR] [--dry-run] [--write] [--backup-dir PATH]

--dry-run (default)     scan and print a side-by-side diff per receipt
--write                 apply upgrades; refuse unless --backup-dir is set
--backup-dir PATH       copy each v1 file here before overwriting
--target DIR            root of the project to scan (default: auto-detect)
```

Exit codes: 0 = nothing to do or all upgrades successful; 1 = upgrader raised on at least one file; 2 = config error (e.g., `--write` without `--backup-dir`).

### Step E — server.py wiring

Concrete edits:

- Import `from migrations import write_latest, upgrade_in_memory, CURRENT_VERSION`.
- `server.py:92` — replace literal `1` with `CURRENT_VERSION` in `_write_receipt`.
- `server.py:362, 474` — remove hard-coded `"schema_version": 1`; rely on `write_latest` to stamp the version.
- `_read_receipt` (L216–316) — after parsing, call `upgrade_in_memory(data)` so every reader sees v2 shape.
- Extend the parser's recognized keys to include the new nested `actor` object. The parser already handles nested dicts; verify on the new fixtures.
- Reject writes whose `state` is not in the legal transitions of the state machine. Implementation: small in-process state-machine table mirroring the markdown doc, sourced from the single declaration in a tiny helper `_state_machine.py`.

### Step F — fixtures

Fixtures are minimal receipts (no sensitive content). Cover:

- `v1/bug_in_progress.yaml`
- `v1/bug_completed.yaml`
- `v1/feature_in_progress.yaml`
- `v1/design_completed.yaml`
- `v1/autoresearch_in_progress.yaml`
- `v1/trivial_completed.yaml`
- `v1/broken_missing_task_id.yaml`
- `v1/broken_unknown_task_type.yaml`

For each well-formed v1 fixture, a parallel `v2/<name>.yaml` captures the expected upgrade output. The broken fixtures do not have v2 counterparts; the migrator must reject them.

### Step G — tests

File: `governance-mcp-server/tests/test_migrations.py`

Minimum coverage:

1. Well-formed v1 → v2 upgrade matches the fixture for every well-formed pair (6 tests).
2. Broken fixtures raise with a message naming the bad field (2 tests).
3. Idempotency: `upgrade_in_memory(upgrade_in_memory(x)) == upgrade_in_memory(x)` (1 test).
4. `upgrade_in_memory` on a v2 input is a no-op (1 test).
5. State-machine legality: routine `running → completed` passes only with coherent task claims; formal Verification completion without `state=verified` and verification evidence is rejected.

### Step H — validators

- `scripts/validate-receipt.py` — accept `schema_version in {1, 2}`; if v1, auto-upgrade in memory before validation; if v2, validate against v2 required-claims matrix.
- `scripts/validate-index.py` — accept index entries with either schema version; add tolerance for new keys.

### Step I — end-to-end

Run, in order:

```bash
pytest governance-mcp-server/tests/
bash tests/bootstrap-project.test.sh
bash tests/governance-e2e.test.sh
bash tests/adapter-parity.test.sh
python3 scripts/migrate-receipts.py --target docs/examples/minimal-governed-repo/ --dry-run
```

All must pass. The migrate dry-run must report a structured diff or `no-op`; it must not raise.

## 3. Rollback plan

If Step E destabilizes the server (e.g., a receipt write starts failing), revert only the server.py import and writer changes; v2 schema, migrations package, fixtures, and validators are inert without server wiring and can remain on main. The rollback boundary is thus a 20-line diff.

## 4. Branch and review discipline

- Work is done on `main` per the repo's observed discipline (no feature branches in git log).
- Each step above corresponds to one commit, with `CG-Task` trailer referencing this plan.
- The PR description cites this plan by path; no commit-as-design.

## 5. Out of scope

As stated in the design doc §3. In particular, no signing, no PDR emission from adapters, no project_id field, no CI phase 4, no ADR directory — all deferred to M3/M4/M5.
