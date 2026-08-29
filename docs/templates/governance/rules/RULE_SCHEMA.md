# Rule File Schema (rule.yaml v1)

**Authority:** `docs/plans/2026-04-23-policy-engine-design.md` §4
**Status:** Active
**Schema version:** 1

A rule file declares a single governance rule evaluated by
`governance-mcp-server/policy_engine/`. Each rule lives at
`docs/templates/governance/rules/<id>.rule.yaml`.

## 1. Two kinds

- `kind: dynamic` (default) — the rule is evaluated over an EvalContext and produces Decision records.
- `kind: static-reference` — the rule is a pure data bundle consumed by callers via `load_rule(...).data[key]`. No evaluation, no predicates, no clauses.

## 2. Required fields (both kinds)

| Field | Type | Notes |
|---|---|---|
| `schema_version` | int | Must be 1. |
| `id` | string | Rule identifier; must match the filename (without `.rule.yaml`). |
| `name` | string | Human-readable title. |
| `description` | string | One-to-three-sentence summary of the rule's intent. |
| `version` | string | Semver. Bump minor for behavior changes, patch for bug fixes. |

## 3. Dynamic-rule fields

| Field | Type | Notes |
|---|---|---|
| `inputs` | list[string] | Names of EvalContext inputs the rule consumes (`staged_files`, `task`, `escalations_jsonl`, etc.). Used to compute `context_hash` in the emitted PDR. |
| `iterate` | object? | Iteration spec (see §4). Omit for rule-scope evaluation. |
| `subject` | object | Shape for the emitted PDR subject (see §5). |
| `clauses` | list[object] | Ordered list of `{id, when, decision, reason, when_args, when_kwargs}` (see §6). First match wins. |
| `action` | string? | Free-form verb stamped into the PDR. Defaults to `"evaluate"`. |

## 4. Iterate spec

```yaml
iterate:
  over: staged_files      # input name (must be a list)
  as: file                # binding name for each item
  filter: has_suffix      # optional named predicate
  filter_args: [".md"]    # positional args passed to the filter
```

## 5. Subject spec

```yaml
subject:
  kind: file              # file | tool | receipt | contract | commit | escalation
  id_from: file           # iteration variable to take id from
  # OR
  id_literal: "derived-edits-scope"   # fixed id for rule-scope rules
```

## 6. Clause spec

```yaml
clauses:
  - id: stable-short-id
    when: some_predicate
    when_args: [positional, args]
    when_kwargs:
      keyword: value
    decision: ALLOW        # ALLOW | DENY | ESCALATE
    reason: "human-readable explanation"
```

- `when` must be the name of a predicate registered in `policy_engine.predicates`.
- Unknown predicate names cause a DENY decision at evaluation time (fail-closed).
- A predicate raising an exception produces a DENY decision with a reason naming the exception type.

## 7. Static-reference format

```yaml
schema_version: 1
kind: static-reference
id: hardgate-loading
name: HARD-GATE Document Loading Map
version: "1.0.0"
description: Role-to-required-docs mapping consumed by HARD-GATE loaders.
data:
  system-architect:
    - PROJECT_BASELINE.md
    - system/SYSTEM_INVARIANTS.md
  implementation:
    - system/SYSTEM_INVARIANTS.md
```

Consumers call `load_rule('hardgate-loading').data['system-architect']`.

## 8. Naming and placement

- File name: `<id>.rule.yaml`. `id` matches the filename (minus extension).
- Location: `docs/templates/governance/rules/`.
- One rule per file. No multi-document YAMLs.

## 9. Evolution rules

- Adding a new optional field to the schema is a minor change; existing rule files remain valid.
- Adding a new required field bumps `schema_version` and requires all rule files to be updated.
- Removing a field is a major break handled via the same deprecation window as receipt schemas (see `MIGRATION.md` in M5).

## 10. Example: minimal dynamic rule

```yaml
schema_version: 1
kind: dynamic
id: example-rule
name: Example
version: "1.0.0"
description: A minimal reference rule.
inputs: [staged_files]
iterate:
  over: staged_files
  as: file
  filter: has_suffix
  filter_args: [".md"]
subject:
  kind: file
  id_from: file
clauses:
  - id: allow-always
    when: always
    decision: ALLOW
    reason: "example accepts everything"
```
