# Task Binding Convention

**Authority:** `docs/plans/2026-03-24-deerflow-inspired-governance-engine-plan.md` §4.1–§4.4

---

## Purpose

Task binding links code changes to governed task receipts. This enables pre-commit and CI to validate that every governed change has corresponding attestation evidence.

---

## 1. Primary Binding: CG-Task Commit Trailer

Every commit that is part of a governed task must include a `CG-Task` trailer in the commit message:

```
fix(auth): resolve session expiry race condition

Replaced shared timer with per-session timeout to prevent
premature session invalidation under concurrent load.

CG-Task: T-20260325-001
```

### Trailer Rules

- **Format:** `CG-Task: T-YYYYMMDD-NNN`
- **Position:** In the trailer block (after blank line following commit body)
- **One primary task per commit:** A commit should normally bind to one task ID
- **Multi-task exception:** If a commit legitimately spans multiple governed tasks, use multiple trailers:
  ```
  CG-Task: T-20260325-001
  CG-Task: T-20260325-002
  ```
  This must be rare and justified; prefer splitting commits.

### Validation

`check-task-binding.sh` verifies:
- Trailer is present in the commit message
- Task ID matches the `T-YYYYMMDD-NNN` pattern
- Referenced receipt file exists in `.governance/attestations/`

---

## 2. Secondary Binding: Branch Naming

Branch names should follow the pattern:

```
cg/<task_id>/<short-description>
```

Examples:
```
cg/T-20260325-001/fix-auth-session-expiry
cg/T-20260325-002/add-payments-module
```

### Branch Rules

- Branch naming is advisory, not enforced by pre-commit
- CI may use branch name to correlate with receipt for additional validation
- One branch may contain multiple commits for the same task
- Branch name task ID should match the primary `CG-Task` trailer in commits

---

## 3. Task ID Lifecycle

### ID Format

```
T-YYYYMMDD-NNN
```

- `YYYYMMDD` — date the task was created
- `NNN` — monotonically increasing sequence number within that date (starting at 001)

### Issuer

| Issuer | Mode | How |
|--------|------|-----|
| MCP service | `mcp` | `governance_start_task` tool assigns next ID automatically |
| Manual | `manual_attestation` | User reads `index.jsonl`, picks next available ID |

### Registry

All task IDs are registered in `.governance/attestations/index.jsonl`.

### Span

- One task ID may span **multiple commits** (a task is larger than a single commit)
- One task ID may span **multiple sessions** (work continues across agent sessions)
- One commit should bind to **one primary task ID** (prefer splitting)

---

## 4. External Issue Tracker Integration

Task IDs are independent of external issue trackers. When an external tracker is used:

- The receipt may include an optional `external_ref` field (future schema extension)
- Task IDs remain valid even when no external tracker exists
- The `CG-Task` trailer is always the canonical binding, not the issue tracker reference

---

## 5. Commits Without Task Binding

Not all commits require task binding. Task binding is required when:

- The commit modifies governed code modules
- The commit modifies governance artifacts in `docs/agents/`
- The commit is part of a bug fix, feature, or refactor task

Task binding is NOT required for:

- `trivial` task type (but may optionally include it)
- Commits that only modify non-governed files (e.g., README updates outside docs/agents/)
- Infrastructure-only commits (CI config, tooling) unless they affect governance enforcement

`check-task-binding.sh` only enforces binding when the attestation system is active (`.governance/attestations/` exists and contains receipts).
