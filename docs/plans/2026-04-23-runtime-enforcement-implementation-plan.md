# Runtime Enforcement Implementation Plan (M3)

**Date:** 2026-04-23
**Status:** Active
**Design doc:** `2026-04-23-runtime-enforcement-design.md`
**Upstream authority:** `~/.config/claude-work/plans/sorted-squishing-pinwheel.md` §M3

## 1. Dependency order

```
Step A  ADAPTER_ENFORCEMENT_CONTRACT.md (doc; contract all steps below comply with)
Step B  authority-matrix.rule.yaml (static-reference) — single source of tier→role truth
Step C  adapters/hermes/plugin/constants.py imports from Step B (drift lock)
Step D  authority.rule.yaml + new predicates (actor_has_authority)
Step E  context-class-tools.rule.yaml + tool_is_networked predicate
Step F  golden fixtures for authority and context-class-tools (≥5 each)
Step G  governance_record_decision MCP tool; governance_start_task authority pre-check
Step H  cc-authority-hook.py (Claude Code reference adapter) + hooks.json template update
Step I  Hermes plugin: abort envelope in authority.py + _pre_tool_call return
Step J  test_runtime_block.py (Python, covers all 3 adapters' logic)
Step K  tests/runtime-enforcement.test.sh (end-to-end negative test via Claude Code hook)
Step L  Full regression
```

Steps A, B, D, E can be written in parallel. C depends on B. F depends on D and E. G–I each touch a different concrete enforcement surface and can proceed independently once F lands.

## 2. Concrete actions

### Step A — ADAPTER_ENFORCEMENT_CONTRACT.md

File: `docs/templates/adapter/ADAPTER_ENFORCEMENT_CONTRACT.md`

Sections: input shape, output shape, fail-closed rules, version negotiation, PDR persistence obligation, compliance checklist.

### Step B — authority-matrix.rule.yaml

`kind: static-reference`. Mirror the current `adapters/hermes/plugin/constants.AUTHORITY_MATRIX`. Keys are tiers (as strings `"0"`, `"0.5"`, …); values are dicts of `read` / `write` → list of role names.

### Step C — constants.py drift lock

`adapters/hermes/plugin/constants.py` — keep `AUTHORITY_MATRIX` as a Python dict, but add a module-level `assert` (or pytest fixture) that it equals the `data` loaded from `authority-matrix.rule.yaml` via `policy_engine.load_rule`. First divergence fails a unit test.

### Step D — authority.rule.yaml + predicates

Rule iterates over a single synthetic item (the inbound `(actor, subject)` pair) passed via the task context. New predicates:

- `actor_has_authority(ctx, item, operation)` — reads `authority-matrix.rule.yaml` via `load_rule`, classifies `item.subject.id` by tier via pattern, checks role ∈ allowed_roles for operation.

Single-decision rule with clauses:

```yaml
clauses:
  - id: allow-authorized
    when: actor_has_authority
    when_args: [write]     # operation
    decision: ALLOW
    reason: "role has write authority for this tier"
  - id: block-unauthorized
    when: always
    decision: DENY
    reason: "role lacks write authority for the target tier"
```

The evaluator provides `actor`, `subject_kind`, `subject_id`, `operation` via a fresh EvalContext input `runtime_call` (a dict).

### Step E — context-class-tools.rule.yaml

Rule with a single item (the inbound `(tool_name, context_class)` pair). New predicates:

- `tool_is_networked(ctx, item)` — hardcoded set `{WebFetch, WebSearch, Bash[curl], Bash[wget], ...}` (pattern match on tool_args for Bash).
- `context_class_is(ctx, item, value)` — reads from runtime_call.context_class.

### Step F — golden fixtures

Per rule, ≥ 5 fixtures. Include negative regression: impl-writes-baseline (M3 headline case).

### Step G — MCP server tool + authority pre-check

File: `governance-mcp-server/server.py`.

- New `@mcp.tool() def governance_record_decision(actor, subject_kind, subject_id, action, decision, reason, rule_id, policy_version, context_hash, task_id=None)`. Writes to `.governance/decisions.jsonl`.
- `governance_start_task` / `governance_update_receipt` — before write, synthesize a `runtime_call` context and evaluate `authority.rule.yaml`. If DENY, return `{"error": "authority violation", "pdr_id": ...}` and skip the write. Records an escalation.

### Step H — Claude Code reference adapter

Files:

- `adapters/claude-code/cc-authority-hook.py` — reads `CLAUDE_TOOL_NAME`, `CLAUDE_TOOL_PARAM_file_path` from env; runs the authority rule; non-zero exit on DENY; writes PDR via governance_record_decision (or direct JSONL append if MCP not running).
- `adapters/claude-code/hooks.json.template` — simplified to a single `PreToolUse` entry calling the Python hook with all matchers unified (Edit|Write|MultiEdit|NotebookEdit).

### Step I — Hermes plugin upgrade

Files:

- `adapters/hermes/plugin/authority.py` — `check_authority()` returns `{..., abort: bool, rule_id: ..., policy_version: ...}`.
- `adapters/hermes/plugin/__init__.py` — `_pre_tool_call` returns `{"abort": True, "reason": ..., "pdr": {...}}` on DENY. Writes PDR via MCP if available, falls back to direct JSONL write.

### Step J — test_runtime_block.py

Tests (minimum 8):

1. Claude Code hook blocks impl writing BASELINE (non-zero exit).
2. Claude Code hook allows SA writing BASELINE.
3. Hermes pre_tool_call returns abort on impl-writes-BASELINE.
4. Hermes pre_tool_call returns allow on read of BASELINE by any role with read authority.
5. MCP `governance_start_task` rejects impl writing BASELINE in its scope.
6. context_class=restricted + WebFetch → DENY.
7. context_class=public + WebFetch → ALLOW.
8. Engine unavailable (monkeypatch) → writes DENY for write, ALLOW for read, with fallback log.

### Step K — runtime-enforcement.test.sh

End-to-end: construct a tempdir with a `.governance/current-task.json` naming role=implementation; run `cc-authority-hook.py` with env simulating an Edit of PROJECT_BASELINE.md; assert exit 1 and PDR append. Then run with role=system-architect; assert exit 0.

### Step L — regression

```bash
python3 -m unittest discover governance-mcp-server/tests
bash tests/bootstrap-project.test.sh
bash tests/governance-e2e.test.sh
bash tests/adapter-parity.test.sh
bash tests/runtime-enforcement.test.sh
```

All must pass.

## 3. Rollback

If Step G breaks MCP for existing tasks, revert only the authority pre-check in `governance_start_task` / `governance_update_receipt`. The new `governance_record_decision` tool is additive and stays. Claude Code hook (Step H) and rules (B–F) are independent of MCP writes; they remain on main.

## 4. Out of scope

Per design §3: signing, hash chain, Hermes host-side changes, Codex native hook, multi-project authority aggregation.
