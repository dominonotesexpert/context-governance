# Policy Engine Implementation Plan (M2)

**Date:** 2026-04-23
**Status:** Active
**Design doc:** `2026-04-23-policy-engine-design.md`
**Upstream authority:** `~/.config/claude-work/plans/sorted-squishing-pinwheel.md` §M2

## 1. Dependency order

```
Step A  policy_engine scaffold (dataclasses, loaders, engine, CLI, no rules yet)
Step A  predicates.py with a minimum viable kernel (~8 primitives)
Step B  rule file schema doc + rules/hardgate-loading.rule.yaml (simplest first)
Step C  derived-edits rule + golden fixtures (hardest; validates schema)
Step D  escalation-block rule + golden fixtures (simplest runtime; covers JSONL)
Step E  module-contract rule + golden fixtures
Step F  bug-evidence rule + golden fixtures
Step G  shell wrapper conversion (4 scripts become thin `exec python3 -m ...`)
Step H  governance_run_checks MCP integration
Step I  FP/FN regression + 100-sample synthetic set
Step J  Full regression across all test suites
```

Steps A, B are serial (A first). Steps C–F each ship one rule and ≥5 golden fixtures in a single commit so a failure is isolated. Step G is a single commit that flips all four shells at once after all rules are proven. Steps H–J are serial.

## 2. Step-by-step

### Step A — engine scaffold

| File | Notes |
|---|---|
| `governance-mcp-server/policy_engine/__init__.py` | Exports `Engine`, `load_rule`, `Decision`, `PREDICATES`. |
| `policy_engine/evalcontext.py` | `EvalContext` dataclass with lazy materializers for staged/committed content and frontmatter parse. |
| `policy_engine/predicates.py` | Registry + ~8 primitives: `always`, `never`, `not_predicate`, `has_suffix`, `is_new_file`, `content_differs`, `is_derived_document`, `derivation_context_changed`. |
| `policy_engine/loaders.py` | Parse rule YAML → Rule dataclass. Uses the same hand-rolled parser pattern from server.py (no PyYAML). Validates schema_version, predicate names, decision enum. |
| `policy_engine/engine.py` | `Engine.evaluate(rule, context) -> list[Decision]`. Handles iteration, clause order, exception→DENY conversion. |
| `policy_engine/decisions.py` | `Decision` dataclass with `to_pdr(actor, task_id, timestamp) -> dict`. |
| `policy_engine/cli.py` | `python3 -m policy_engine.cli check <rule-id> [--target DIR] [--format text|json]`. |

CLI conventions:
- `--target` defaults to auto-detected repo root (looks for `.governance/`).
- `--format json` prints `{"rule_id": ..., "decisions": [...]}` to stdout.
- `--format text` prints one line per decision plus a terminal summary (mirrors the current shell script output style).

### Step B — rule schema + first rule

File: `docs/templates/governance/rules/RULE_SCHEMA.md` — describes the v1 rule file schema (conceptually; the schema itself is also encoded in `loaders.py`).

File: `docs/templates/governance/rules/hardgate-loading.rule.yaml` — a static table of role → required docs. This rule has no iteration and no predicate lookups; it exists to prove the loader handles a trivial case and to consolidate the role→docs mapping that is currently duplicated in `check-hardgate.sh` and `adapters/hermes/plugin/hardgate.py`.

```yaml
id: hardgate-loading
name: HARD-GATE Document Loading Map
version: "1.0.0"
kind: static-reference
data:
  system-architect: [PROJECT_BASELINE.md, system/SYSTEM_INVARIANTS.md, ...]
  debug: [debug/DEBUG_CASE_TEMPLATE.md, debug/RCA_HARD_CONSTRAINTS.md, system/SYSTEM_SCENARIO_MAP_INDEX.md]
  ...
```

This rule is consumed by downstream callers via `load_rule('hardgate-loading').data[role]` rather than via the normal evaluate() path; the engine treats `kind: static-reference` as a pure data bundle.

### Step C — derived-edits rule

Predicates used: `has_suffix`, `is_derived_document`, `is_new_file`, `derivation_context_changed`, `content_differs`, `not_predicate`, `always`.

Golden fixtures (≥ 5):

1. `01-new-file-allowed.json` — file staged but not in HEAD
2. `02-context-updated-allowed.json` — derivation_timestamp differs → ALLOW
3. `03-content-changed-without-context-denied.json` — content differs, context matches → DENY (FP-1 regression)
4. `04-non-derived-file-allowed.json` — regular markdown without derivation_type
5. `05-quoted-yaml-timestamp-allowed.json` — FP-1: committed has `"2026-03-20T10:00:00Z"`, staged has `2026-03-20T10:00:00Z` → ALLOW (today's shell would WARN)
6. `06-staged-content-identical-allowed.json` — file in index but no actual change

### Step D — escalation-block rule

Inputs: `escalations_jsonl_content` (new evalcontext materializer), `staged_files`.

Predicates used: `has_pending_escalation`, `has_governed_code_staged`.

Golden fixtures (≥ 5):

1. `01-no-escalations-file-allowed.json`
2. `02-no-pending-escalations-allowed.json`
3. `03-pending-escalation-no-code-staged-allowed.json`
4. `04-pending-escalation-with-code-denied.json`
5. `05-substring-in-description-field-allowed.json` — FN-1: an escalation whose `description` literally contains `"status":"pending"` but whose actual status is `resolved` → ALLOW (today's shell's grep would BLOCK)

### Step E — module-contract rule

Inputs: `staged_files`, `repo_root`.

Predicates used: `is_governed_code_file`, `module_for_path`, `module_contract_exists`.

Golden fixtures (≥ 5):

1. `01-no-staged-files-allowed.json`
2. `02-staged-docs-only-allowed.json`
3. `03-staged-code-in-module-with-contract-allowed.json`
4. `04-staged-code-in-module-without-contract-denied.json`
5. `05-staged-code-outside-any-module-allowed.json` — path doesn't walk up to any governed module

### Step F — bug-evidence rule

Inputs: `task` (from current-task.json), `staged_files`, `repo_root`.

Predicates used: `task_type_is`, `routine_bug_route_is_valid`, `routine_bug_route_is_invalid`, `has_debug_case_for_any_affected_module`.

Golden fixtures (≥ 5):

1. `01-no-active-task-allowed.json`
2. `02-non-bug-task-allowed.json`
3. `03-bug-task-with-existing-debug-case-allowed.json`
4. `04-bug-task-with-staged-debug-case-allowed.json`
5. `05-bug-task-without-debug-case-denied.json`
6. `06-bug-task-with-docs-only-staged-allowed.json`
7. `07-routine-bug-with-root-cause-allowed.json`
8. `08-routine-bug-without-evidence-denied.json`

### Step G — shell wrapper conversion

Convert each of `check-derived-edits.sh`, `check-module-contract.sh`, `check-bug-evidence.sh`, `check-escalation-block.sh` into a minimal shell that invokes the CLI. Preserve existing CLI surface (`--target`, `--strict`, etc.) by passing them through. Exit-code contract matches today's behavior.

### Step H — MCP integration

`governance-mcp-server/server.py : governance_run_checks` — replace the current `_run_check` loop (which shells out to `check-*.sh`) with a direct call to the engine. Keep the existing return structure (`overall`, `checks`) but each entry gains a `decisions` key with the PDR array. Also write PDRs into `.governance/decisions.jsonl` (append-only).

### Step I — FP/FN regression

`governance-mcp-server/tests/test_policy_engine_fpfn.py` generates 100 synthetic samples per rule by perturbing golden fixtures (random edits, random module paths, random timestamps). The test asserts the rule's output matches a conservative oracle (the golden cases plus rule-obvious predictions). Fails if FP > 2% or FN > 5%.

### Step J — Full regression

```bash
python3 -m unittest discover governance-mcp-server/tests
bash tests/bootstrap-project.test.sh
bash tests/governance-e2e.test.sh
bash tests/adapter-parity.test.sh
python3 -m policy_engine.cli check derived-edits --target .
python3 -m policy_engine.cli check escalation-block --target .
python3 -m policy_engine.cli check module-contract --target .
python3 -m policy_engine.cli check bug-evidence --target .
```

All must pass. CLI runs against the framework's own repo produce no DENY decisions (smoke test).

## 3. Rollback plan

If Step H destabilizes the MCP server, revert `governance_run_checks` to the prior shell-out implementation while keeping the engine and rules on main. The shell wrappers can continue to work independently, so downstream projects are unaffected.

## 4. Out of scope

- PDR signing (M4).
- Tool-call-time enforcement (M3).
- PR-comment bot (M5).
- Sigstore/Rekor integration (M4.2+).
- Expression DSL. Hybrid named-predicate model only.
