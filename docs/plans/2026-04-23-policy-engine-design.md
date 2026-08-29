# Declarative Policy Engine Design

**Date:** 2026-04-23
**Status:** Proposed
**Depends on:** `2026-04-23-governance-kernel-v2-design.md`
**Authority:** `~/.config/claude-work/plans/sorted-squishing-pinwheel.md` §M2 (user-approved)
**Scope:** Replace the ad-hoc shell/regex logic in four hardgate scripts with a declarative rule file format and a shared Python executor that emits Policy Decision Records (PDRs) matching the v2 schema.

## 1. Problem

The repository ships 13 shell scripts under `scripts/check-*.sh`. Four of them encode the most consequential governance decisions:

- `check-derived-edits.sh` — flags direct edits to derived documents by comparing `derivation_timestamp` and `upstream_hash` in staged vs committed versions. Logic is a mix of `grep -m1 | sed`, which is fragile: any comment or example block that happens to contain the field name produces false positives, and any YAML quoting variation produces false negatives.
- `check-module-contract.sh` — walks the directory tree to find a module name and checks that `MODULE_CONTRACT.md` exists. It cannot tell whether the contract actually covers the modified files — it only asserts the contract file is present.
- `check-bug-evidence.sh` — historically asserted a `DEBUG_CASE_*` for every `task_type=bug`. The converged rule defaults bugs to formal Debug, but allows an explicit routine route only when `debug_required=false`, a route reason, and cited root-cause evidence are recorded before code is staged.
- `check-escalation-block.sh` — scans `escalations.jsonl` with `grep -c '"status":"pending"'`, which will mis-match any JSON line that happens to have that substring anywhere in the value, not just in the status field.

Four concrete gaps:

1. **No golden input/output fixtures** — every change to a hardgate must be validated by hand, and historical false-positive scenarios are not preserved anywhere.
2. **No structured output** — scripts print human-readable PASS/FAIL lines that CI can parse only by exit code. M3 runtime enforcement and M4 attestation need structured PDRs.
3. **No versioning** — there is no way to say "this check was evaluated under policy v1.2.0" in a receipt, because policies are not versioned.
4. **Logic is duplicated across scripts and adapter code** — `adapters/hermes/plugin/hardgate.py:24–88` hard-codes role→docs mappings that duplicate `check-hardgate.sh`'s logic, and they can drift.

## 2. Decision Summary

### 2.1 Hybrid rule model: declarative metadata + named predicates

Each rule lives as a YAML file under `docs/templates/governance/rules/<rule-id>.rule.yaml`. The rule file declares:

- `id`, `name`, `description`, `version` (semver)
- `inputs` — named evaluation contexts required (staged_files, task, repo_root, etc.)
- `iterate` — name of the collection to iterate over (optional)
- `clauses` — ordered list of `{id, when, decision, reason}`

`when` is a named predicate registered in `policy_engine.predicates`, invoked with positional and keyword arguments. Predicates are Python functions with a stable signature:

```python
def predicate(ctx: EvalContext, **kwargs) -> bool: ...
```

Rationale for the hybrid: a pure DSL would take weeks to build and test for an engine that must evaluate four specific rules. A pure-Python rules would bring back the shell's "logic duplicated in scripts and adapters" problem. The hybrid lets rule files stay human-readable and diffable while the heavy lifting (reading git index, parsing frontmatter, walking directories) stays in audited Python code.

### 2.2 PDR emission contract

Every rule evaluation emits zero or more PDRs (one per iteration). A PDR shape matches `POLICY_DECISION_RECORD.schema.yaml` v1 — required fields: `pdr_id`, `rule_id`, `policy_version`, `actor`, `subject`, `action`, `decision`, `reason`, `context_hash`, `timestamp`. `task_id` is nullable.

`context_hash` is `sha256(canonical_json(context_subset))` where `context_subset` is the minimal set of inputs the rule actually consumed (declared in the rule file). This gives M4 a replay-reproduction key without bloating the PDR with irrelevant environment noise.

### 2.3 Shell wrappers preserve CI integration

Each of the four shell scripts (`check-derived-edits.sh`, `check-module-contract.sh`, `check-bug-evidence.sh`, `check-escalation-block.sh`) keeps its current CLI and exit-code contract, but the body is reduced to:

```bash
exec python3 "$SCRIPT_DIR/../governance-mcp-server/policy_engine/cli.py" \
    check "$RULE_ID" --target "$TARGET" "$@"
```

Exit codes: `0` = all ALLOW, `1` = at least one DENY, `2` = misuse / unrecoverable error (same as today). The CLI also has a `--format json` flag that emits the full PDR array for programmatic consumers (including the MCP server and future PR-comment bots).

### 2.4 Golden fixtures

Per rule, a directory `governance-mcp-server/tests/policy_golden/<rule-id>/` holds JSON fixtures:

```
policy_golden/derived-edits/
    01-new-file-allowed.json
    02-context-updated-allowed.json
    03-content-changed-without-context-denied.json
    04-non-derived-file-allowed.json
    05-edge-quoted-yaml-value.json
    ...
```

Each fixture contains:

```json
{
  "name": "content changed without context update",
  "context": { ...serializable evaluation context... },
  "expected_decisions": [
    {"subject.id": "docs/agents/system/SYSTEM_INVARIANTS.md", "decision": "DENY"}
  ]
}
```

Golden test harness `test_policy_golden.py` enumerates every fixture, invokes the engine, and asserts the emitted PDR set matches `expected_decisions` on the key fields (not the full PDR, since timestamp and pdr_id are nondeterministic).

### 2.5 Version stamping

Each rule file declares `version: "1.0.0"`. The engine stamps this into every PDR as `policy_version`. When a rule's semantics change (not just refactor), the minor version bumps. Receipts carry the union of rule versions they encountered via the existing `policy_version` top-level field (M1 v2 schema) — the receipt records the **engine bundle version**, not individual rules; the full per-rule breakdown lives in the PDRs the receipt references.

For M2 the engine bundle version is `1.0.0`. When M3 adds runtime enforcement, the bundle stays at `1.x`. When M4 adds signing semantics that change decision reproducibility, the bundle bumps to `2.0.0`.

### 2.6 Failure modes

Engine fail-closed behavior:

- **Missing rule file** → CLI exits 2 (misuse); MCP reports `status: error`; no PDR emitted.
- **Malformed rule file** → CLI exits 2; loader raises with field path.
- **Missing predicate** → Same as malformed: the rule never evaluates. Engine boot-time registry check guarantees this is caught at engine startup, not rule evaluation.
- **Predicate raises an exception** → Convert to DENY with `reason: "predicate <name> raised <Exception>"`. Rationale: in a governance system, unknown-state is unsafe; a predicate that cannot evaluate should not produce a spurious ALLOW.

## 3. Non-goals

Explicitly deferred to later milestones to keep M2 shippable:

- Runtime enforcement at tool-call time (M3). M2 only covers commit/CI-time evaluation.
- Signed PDRs (M4). The `context_hash` field goes in now because it's cheap, but signing fields remain null in v1 of the engine.
- `check-hardgate.sh` and other secondary scripts. M2 migrates the four most impactful rules; the rest stay as shell and migrate opportunistically in M2.1+.
- PR-comment bot that consumes PDR JSON (M5).
- DSL expression language for `when` clauses. M2 uses named predicates only.

## 4. Rule file schema (rule.yaml v1)

```yaml
# Required
id: derived-edits
name: Derived Document Edit Protection
description: >
  Prevents direct edits to derived documents (those carrying a
  derivation_type frontmatter) without a corresponding update to
  derivation_timestamp or upstream_hash.
version: "1.0.0"

# Evaluation inputs the engine must prepare.
inputs:
  - staged_files        # list[str] of staged paths
  - staged_content      # dict[str, str]
  - committed_content   # dict[str, str]

# Iterate over one of the inputs. Each iteration value is bound to `item`.
# Omit `iterate` to evaluate the rule once as a whole.
iterate:
  over: staged_files
  as: file
  filter: has_suffix         # named predicate
  filter_args: [".md"]

# Ordered clauses. First match wins.
clauses:
  - id: not-derived
    when: not_predicate
    when_args: [is_derived_document]
    decision: ALLOW
    reason: "not a derived document"
  - id: new-file
    when: is_new_file
    decision: ALLOW
    reason: "new file — no prior derivation context to compare"
  - id: context-updated
    when: derivation_context_changed
    decision: ALLOW
    reason: "derivation_context updated — treated as re-derivation"
  - id: unchanged-content
    when: not_predicate
    when_args: [content_differs]
    decision: ALLOW
    reason: "staged content matches committed; no edit"
  - id: direct-edit
    when: always
    decision: DENY
    reason: "content changed but derivation_context unchanged — possible direct edit"

# Subject shape for the emitted PDR.
subject:
  kind: file
  id_from: file            # take subject.id from the iteration variable `file`
```

The schema is extended in M3 with `when: when_any` / `when: when_all` compound combinators; M2 uses only single predicates.

## 5. Engine architecture

```
governance-mcp-server/policy_engine/
├── __init__.py          # exports: Engine, load_rule, Decision
├── cli.py               # CLI: check <rule-id> [--format json] [--target DIR]
├── loaders.py           # rule file parser; validates against schema v1
├── predicates.py        # registry of named predicates
├── evalcontext.py       # EvalContext dataclass; materializes inputs lazily
├── engine.py            # Engine.evaluate(rule, context) -> list[Decision]
└── decisions.py         # Decision dataclass -> PDR dict
```

Key types:

```python
@dataclass
class Rule:
    id: str
    name: str
    description: str
    version: str
    inputs: list[str]
    iterate: IterateSpec | None
    clauses: list[Clause]
    subject: SubjectSpec

@dataclass
class Decision:
    rule_id: str
    policy_version: str
    subject_kind: str
    subject_id: str
    decision: str           # ALLOW | DENY | ESCALATE
    reason: str
    context_hash: str

@dataclass
class EvalContext:
    repo_root: Path
    staged_files: list[str]
    task: dict | None
    # lazily materialized:
    def staged_content_of(path) -> str
    def committed_content_of(path) -> str
```

## 6. Historical false-positive / false-negative samples

M2 acceptance requires proving two historically known bugs are correctly classified by the new engine:

- **FP-1** — `check-derived-edits.sh` warns on re-derivations where the committed version had a quoted timestamp (`"2026-03-20T10:00:00Z"`) but the staged version has an unquoted one. The shell `tr -d '"'` normalizes both but only after the comparison has happened in some invocations. Rule-file version uses a structured frontmatter parser and compares the normalized values.
- **FN-1** — `check-escalation-block.sh` misses `"status":"pending"` substrings inside a `"description":"..."` field that happened to contain the text. Rule-file version parses JSONL and checks `entry["status"] == "pending"` field-path exactly.

Both scenarios are encoded as golden fixtures with `expected_decisions` that the current shell would have gotten wrong.

## 7. Acceptance criteria (M2 exit)

1. Four rule files exist under `docs/templates/governance/rules/` (derived-edits, module-contract, bug-evidence, escalation-block), each with ≥5 golden fixtures.
2. `python3 -m policy_engine.cli check <rule-id> --target <project>` runs each rule; exit codes match the existing shell script's codes on the same inputs.
3. The four shell scripts are now thin wrappers that `exec` the Python CLI and preserve their argument surface.
4. `governance_run_checks` in the MCP server returns a structured PDR array via the engine (no `subprocess` call).
5. The two historical FP/FN samples are correctly classified (shell would have been wrong).
6. FP < 2% and FN < 5% across a 100-sample synthetic set (sample generator ships alongside golden fixtures).
7. All prior tests stay green: `pytest governance-mcp-server/tests/`, `bootstrap-project.test.sh`, `governance-e2e.test.sh`, `adapter-parity.test.sh`.

## 8. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Named-predicate sprawl (one-off predicates per rule) | Cap at ~20 predicates in the registry for M2; a code review gate rejects PR adding a 21st without justification |
| Rule file evolution breaks old rules | Rule file schema itself is versioned (`schema_version: 1`); loader rejects unknown versions |
| Migration leaves shell scripts and Python engine transiently out of sync | Shell wrappers ship in the same PR as the Python rule — no interim state where both logics are live |
| Predicate exceptions get silently swallowed | Engine converts to DENY with reason; unit test asserts a raising predicate produces DENY not ALLOW |
| Golden fixtures grow stale vs. rule changes | `governance_run_checks` re-runs the golden set in CI; any rule change that breaks a golden fixture requires updating the fixture in the same PR |

## 9. Open questions

None at design time. The three project-level open questions (semver, signing, multi-project) were resolved at plan approval and do not affect M2.
