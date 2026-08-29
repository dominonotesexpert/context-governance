# Adapter Enforcement Contract v1

**Authority:** `docs/plans/2026-04-23-runtime-enforcement-design.md` §2.4
**Status:** Active
**Contract version:** 1

All Context Governance adapters — Claude Code, Hermes, Codex, and any future integration — implement the same pre-tool-call enforcement contract so that governance decisions are consistent and auditable across platforms.

## 1. Input shape

Every enforcement invocation receives:

```json
{
  "actor_role": "implementation",                 // string; current governance role
  "tool_name": "Edit",                             // string; tool being invoked
  "tool_args": {"file_path": "docs/agents/PROJECT_BASELINE.md", ...},
  "task_id": "T-YYYYMMDD-NNN",                   // nullable
  "context_class": "internal"                      // public | internal | restricted
}
```

Adapters are responsible for collecting these inputs from their host platform and passing them to the policy engine.

## 2. Output shape

The enforcement layer returns:

```json
{
  "decision": "ALLOW" | "DENY",
  "reason": "...",
  "rule_id": "authority",
  "policy_version": "1.0.0",
  "pdr_id": "PDR-20260423-017"
}
```

Every invocation, ALLOW or DENY, produces a PDR persisted in `.governance/decisions.jsonl` (append-only). Adapters that cannot call the MCP `governance_record_decision` tool (e.g., pure-bash hooks) write the PDR line directly.

## 3. Fail-closed rules

When the policy engine is unavailable (import error, missing rule file, subprocess exit ≠ 0):

- **Sensitive operations** (Edit/Write/MultiEdit on Tier ≤ 3 files, any tool with network egress) → adapter MUST treat as DENY and log a fallback record with `reason: "engine-unavailable: fail-closed"`.
- **Safe operations** (Read-only tools, tool invocations that never touch governance artifacts) → adapter MAY ALLOW with the same fallback log.

This split exists so that a transient engine failure does not brick an entire session, but also does not become a backdoor for governance bypass.

## 4. Version negotiation

Each adapter declares the contract version it implements:

- Hermes plugin: `plugin.yaml` gains `enforcement_contract_version: 1`.
- Claude Code: `hooks.json.template` front-matter comment includes `"_contract_version": "1"`.
- Codex: `config.toml.template` gains `# enforcement_contract_version = "1"`.

On major-version mismatch, the MCP server logs a warning at first invocation and falls back to permissive mode for reads, fail-closed for writes. Minor mismatches are silent (additive changes).

## 5. PDR persistence obligation

Every ALLOW or DENY emitted under this contract corresponds to one JSONL line in `.governance/decisions.jsonl` with the shape defined in `docs/templates/governance/POLICY_DECISION_RECORD.schema.yaml` v1. Manual edits to this file are rejected by the M4 verifier once the hash chain is active; in M3, a warning is emitted.

## 6. Compliance checklist for new adapters

An integration claims M3 compliance only if it:

1. Intercepts tool invocations before side effects (true pre-tool-call, not post-tool audit).
2. Passes all five input fields; defaults are explicit when the host does not supply one.
3. Blocks execution on DENY (non-zero exit / abort envelope / equivalent platform mechanism).
4. Writes the PDR line via MCP or direct append.
5. Emits fail-closed fallback logs on engine error.
6. Declares its contract version in its config / plugin metadata.
7. Passes `tests/runtime-enforcement.test.sh` with its own invocation path.

Adapters that cannot intercept tool invocations (e.g., Codex native `workspace-write` sandbox) do NOT claim M3 compliance; they fall back to pre-commit enforcement (M2) and document the gap in their bootstrap notes.

## 7. Evolution

Adding an optional input field or output field is a minor change (no version bump). Changing the decision enum, required fields, or fail-closed rules is a major change (bump to v2; adapters declare v2 and MCP warns on v1 invocation).
