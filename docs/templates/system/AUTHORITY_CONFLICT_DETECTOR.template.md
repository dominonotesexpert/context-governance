---
artifact_type: authority-conflict-detector
status: proposed
owner_role: system-architect
scope: system
downstream_consumers: [all-roles]
last_reviewed: YYYY-MM-DD
---

# AUTHORITY_CONFLICT_DETECTOR

**Status:** proposed
**Owner:** System Architect Agent
**Last Updated:** YYYY-MM-DD

> Defines how to detect and resolve conflicts between standards from different authority levels.
> When standards contradict each other, the higher authority level wins.
> Conflicts are resolved by updating upstream documents, never by ad-hoc overrides.

---

## 1. When to Run Detection

- Before each optimization round (autoresearch Step 0)
- When a new standard is derived from any source
- When feedback analysis produces an Upstream Update Suggestion
- When the user reports unexpected agent behavior that may stem from contradictory rules

## 2. Conflict Types

### Type A: Cross-Level Conflict

Standards from different authority levels contradict each other.

```
Example:
  - baseline (highest): "User data must never be lost"
  - engineering_practice (medium): "Use eventual consistency for performance"
  → Conflict: eventual consistency may lose data during failure windows
  → Resolution: baseline wins — engineering practice must be constrained to strong consistency for user data
```

### Type B: Same-Level Conflict

Two standards at the same authority level contradict each other.

```
Example:
  - contract (MODULE_CONTRACT api-service): "Return 200 for all successful operations"
  - contract (MODULE_CONTRACT webhook-service): "Expect 201 for resource creation from api-service"
  → Conflict: same level, different expectations for creation response code
  → Resolution: escalate to System Architect for arbitration
```

### Type C: Derivation Drift

A derived document's content no longer matches what would be derived from the current upstream.

```
Example:
  - BASELINE §4 was updated to add a new business rule
  - SYSTEM_INVARIANTS still reflects the old §4 (derived_from_baseline_version is outdated)
  → Not a conflict per se, but a staleness that may cause downstream contradictions
  → Resolution: trigger re-derivation via System Architect
```

## 3. Detection Procedure

### Step 1: Collect All Active Standards

From CRITERIA_EVOLUTION and the current evaluation checklist, list every active standard with:
- ID
- Statement
- Source (baseline / prd / invariant / contract / engineering_practice / user_input / feedback_history)
- Authority level (from §6.2.4 standard source classification)

### Step 2: Pairwise Comparison

For each pair of standards, check:
1. Do they address the same topic or behavior?
2. If yes, can they both be satisfied simultaneously?
3. If no, which authority level is higher?

### Step 3: Version Check

For each derived document, compare:
- `derived_from_baseline_version` in the document
- Current version of PROJECT_BASELINE

Mismatch → flag as Type C (derivation drift).

## 4. Resolution Rules

| Conflict Type | Resolution |
|--------------|------------|
| **Cross-Level** | Higher authority wins. Lower-level standard is deprecated or re-derived to be compatible. |
| **Same-Level** | Escalate to System Architect. System Architect produces a judgment (verdict + why + impact + action) and records in SYSTEM_CONFLICT_REGISTER. |
| **Derivation Drift** | Trigger re-derivation of the stale document from current upstream. Structural derivations auto-update. Interpretive derivations require user confirmation. |

## 5. Resolution Output

Every resolved conflict is recorded in `SYSTEM_CONFLICT_REGISTER.md`:

```markdown
### CR-NNN: [Conflict Title]

- **Conflict Type:** cross-level | same-level | derivation-drift
- **Standards Involved:** [IDs and statements]
- **Authority Levels:** [levels of each standard]
- **Decision:** [which standard wins / how to reconcile]
- **Authority Basis:** [which tier in SYSTEM_AUTHORITY_MAP decided this]
- **Impact:** [what downstream documents or check items change]
- **Action Taken:** [deprecated X / re-derived Y / updated Z]
- **Date:** YYYY-MM-DD
```

## 6. Prevention

To minimize future conflicts:
1. Every new standard must cite its authority source before being accepted
2. Standards from feedback_history or autoresearch (low authority) are flagged for review if they touch topics already covered by higher-authority standards
3. BASELINE version tracking in all derived documents catches drift early
4. The autoresearch optimization loop runs conflict detection in Step 0 before any modification
