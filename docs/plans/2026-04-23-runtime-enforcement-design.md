# Runtime Enforcement Surface Design (M3)

**Date:** 2026-04-23
**Status:** Proposed
**Depends on:** `2026-04-23-policy-engine-design.md`, `2026-04-23-governance-kernel-v2-design.md`
**Authority:** `~/.config/claude-work/plans/sorted-squishing-pinwheel.md` §M3 (user-approved)
**Scope:** Turn authority decisions from "audit-log only" into actual pre-tool-call blocks, emit PDRs at every runtime decision, and define a cross-adapter enforcement contract so Claude Code, Hermes, and Codex produce the same ALLOW/DENY outcome for the same input.

## 1. Problem

Three concrete gaps remain after M1 (kernel) and M2 (declarative rules):

### 1.1 Hermes decisions never reach the tool boundary

`adapters/hermes/plugin/__init__.py:146–149` documents `_pre_tool_call` as "return value ignored by Hermes." Authority DENY decisions made by `authority.check_authority()` are written to `.governance/audit/session.jsonl` by `_post_tool_call` **after the tool has already executed**. In practice this means a mis-routed `implementation` agent writing to `PROJECT_BASELINE.md` is detected but not prevented.

### 1.2 Claude Code's path-guard hooks are inflexible

`adapters/claude-code/hooks.json.template` hardcodes tier protections as bash case statements over literal filenames (`PROJECT_BASELINE.md`, `SYSTEM_GOAL_PACK.md`, …). Adding a new Tier-0.5 artifact means editing both the template and every already-bootstrapped downstream project's `.claude/settings.local.json`. Role-awareness is absent: the bash hook does not know *who* is acting, only *what* path.

### 1.3 Codex cannot block runtime

`adapters/codex/config.toml.template:11` admits Codex sandbox is `workspace-write` and does not support per-file read-only. There is no pre-tool-call hook API. Runtime enforcement is therefore structurally impossible on Codex today; only pre-commit enforcement (M2) applies.

### 1.4 No canonical place to record a runtime decision

Authority DENY outcomes today live in `audit/session.jsonl` with free-form event keys. There is no versioned, queryable PDR record keyed by `rule_id`, `policy_version`, and `context_hash` — which M4 verification and M5 audit querying require.

## 2. Decision Summary

### 2.1 Three-tier adapter posture

| Adapter | Runtime block capability | M3 posture |
|---|---|---|
| Claude Code | Yes — `PreToolUse` hook returning non-zero aborts the call | **Reference enforcer**: full runtime block via a new `cc-authority-hook.py` that calls the policy engine |
| Hermes | Conditional — existing plugin host ignores return value of `_pre_tool_call` | **Best-effort enforcer + MCP compensation**: plugin is upgraded to return `abort: True`; MCP server simultaneously refuses to write receipts for DENY-classified actors, forcing the task to abort indirectly. Upstream coordination with Hermes is noted and tracked as a risk. |
| Codex | No | **Advisory only**: continue shipping M2's pre-commit gates; `config.toml.template` documents the limitation. No runtime hook is added because none exists to hook into. |

This is consistent with the plan's risk register (`sorted-squishing-pinwheel.md` §五, row 1) and avoids the anti-pattern of claiming uniform enforcement where the platform does not support it.

### 2.2 Authority and context-class become declarative rules

Authority — currently hardcoded in `adapters/hermes/plugin/constants.py:AUTHORITY_MATRIX` — is promoted to two policy-engine rules under `docs/templates/governance/rules/`:

- **`authority.rule.yaml`** — for a `(role, operation, file)` triple, evaluates tier → allowed_roles lookup and yields ALLOW/DENY. The tier→role matrix itself is a `kind: static-reference` rule (`authority-matrix.rule.yaml`) so it lives in one place and both the Python plugin and the CLI read it.
- **`context-class-tools.rule.yaml`** — when the active task's `context_class` is `restricted`, tools with network egress (`WebFetch`, `WebSearch`, `curl`-family shell calls) are DENYed regardless of role.

This pays back M2's investment: all three adapters converge on the same rule bundle, with consistent version stamping in emitted PDRs.

### 2.3 Canonical PDR emission

Every runtime decision — ALLOW or DENY — is persisted to `.governance/decisions.jsonl` via a new MCP tool `governance_record_decision(actor, subject, action, decision, reason, rule_id, policy_version, context_hash)`. Adapters that cannot call MCP directly (e.g., a pure bash `PreToolUse` hook) use a thin Python helper that is the CLI equivalent.

The PDR shape matches `POLICY_DECISION_RECORD.schema.yaml` v1 (M1). In M3 the `chain_prev_hash` field remains reserved; the hash chain activates in M4.

### 2.4 Contract for cross-adapter consistency

`docs/templates/adapter/ADAPTER_ENFORCEMENT_CONTRACT.md` formalizes:

- **Input contract** — every adapter must pass `{actor_role, tool_name, tool_args, task_id, context_class}` to the enforcement layer.
- **Output contract** — enforcement returns `{decision: ALLOW|DENY, reason, rule_id, policy_version, pdr_id}`.
- **Fail-closed default** — if the policy engine is unavailable (import error, file missing, subprocess exit ≠ 0), adapters MUST treat the outcome as DENY for sensitive operations (Tier ≤ 3 writes) and as ALLOW for read-only operations, with a structured log entry recording the fallback. This matches M2's convention for predicate exceptions.
- **Version negotiation** — adapters declare which contract version they implement via `enforcement_contract_version` in their plugin/config; mismatched majors cause a boot-time warning.

### 2.5 MCP-side compensation for non-blocking hosts

When the MCP server's `governance_start_task` / `governance_update_receipt` receives a call whose `actor` would fail authority on the receipt's scope, the call is rejected and an escalation record is written. This gives Hermes indirect enforcement today: a violating agent may execute its tool, but it cannot finalize or update a governance receipt, so the task cannot progress or be considered compliant.

This is explicitly a compensation, not a replacement for a true pre-tool block. It is documented as such so the gap remains visible to future work.

## 3. Non-goals

- Signing PDRs (M4).
- Hash-chained `chain_prev_hash` wiring (M4).
- Host-side changes to Hermes itself (upstream project; tracked as risk).
- Codex native pre-tool-call enforcement (no platform capability).
- Multi-project authority aggregation (M5).

## 4. Touched files

### Modified

- `adapters/hermes/plugin/authority.py` — output gains `abort: bool`, `rule_id`, `policy_version`.
- `adapters/hermes/plugin/__init__.py` — `_pre_tool_call` returns an abort envelope; writes PDR via MCP if available.
- `adapters/claude-code/hooks.json.template` — reduced to a single matcher that `exec`s the Python hook.
- `governance-mcp-server/server.py` — new `governance_record_decision` tool; `governance_start_task` / `governance_update_receipt` add authority pre-check.
- `governance-mcp-server/policy_engine/predicates.py` — new predicates: `actor_has_authority`, `tool_is_networked`, `context_class_is`.

### New

- `docs/templates/adapter/ADAPTER_ENFORCEMENT_CONTRACT.md`
- `docs/templates/governance/rules/authority.rule.yaml`
- `docs/templates/governance/rules/authority-matrix.rule.yaml` (static-reference)
- `docs/templates/governance/rules/context-class-tools.rule.yaml`
- `adapters/claude-code/cc-authority-hook.py`
- `governance-mcp-server/tests/policy_golden/authority/*.json`
- `governance-mcp-server/tests/policy_golden/context-class-tools/*.json`
- `governance-mcp-server/tests/test_runtime_block.py`
- `tests/runtime-enforcement.test.sh`

## 5. Acceptance (M3 exit)

1. Negative test: a role=`implementation` agent attempting `Edit` on `docs/agents/PROJECT_BASELINE.md` via Claude Code is blocked by `cc-authority-hook.py` with non-zero exit and a PDR is appended to `.governance/decisions.jsonl`.
2. Same input via Hermes plugin returns `{abort: True}`; MCP-side `governance_start_task` with this `actor`+`subject` is rejected.
3. `context_class: restricted` on the active receipt rejects `WebFetch` invocation (via the same rule file on both Claude Code and Hermes).
4. Policy engine unavailable (rename `policy_engine/` to break imports): adapters DENY sensitive writes, ALLOW reads, and log the fallback — no silent pass-through.
5. All prior tests green: MCP unit, bootstrap, e2e, adapter-parity, policy-golden. `test_runtime_block.py` adds at least 8 cases covering allow/deny/engine-down permutations.

## 6. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Hermes host never honors `abort: True` | MCP receipt rejection provides indirect blocking today; explicit upstream coordination issue filed; milestone does not claim hard enforcement on Hermes |
| Claude Code hook adds a per-tool Python spawn cost | Hook is ~30 ms when policy_engine already imported; acceptable for interactive coding agent sessions. If this becomes a bottleneck in M5 metrics, cache the engine in a long-lived companion process. |
| hooks.json template change breaks existing downstream projects' `.claude/settings.local.json` | Template is a bootstrap source, not an auto-apply. Downstream updates happen on next bootstrap or via `MIGRATION.md` (M5). Old inline-bash matchers continue to work until replaced. |
| Declarative authority rule subtly diverges from `constants.AUTHORITY_MATRIX` | One source of truth: `authority-matrix.rule.yaml` is a static-reference rule, and `constants.py` imports from it at module load. Unit test asserts equality to prevent drift. |
| Fail-closed DENY on engine-down creates new false positives for read operations | The fail-closed rule distinguishes sensitive (writes to Tier ≤ 3) from safe (reads, tool calls not touching files) and allows reads. Explicitly documented in ADAPTER_ENFORCEMENT_CONTRACT.md §3. |

## 7. Open questions

None at design time. Reference adapter strategy, signing deferral, project_id deferral all resolved at plan approval.
