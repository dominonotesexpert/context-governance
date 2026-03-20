---
artifact_type: feedback-analysis-protocol
status: proposed
owner_role: verification
scope: verification
downstream_consumers: [system-architect, module-architect]
last_reviewed: YYYY-MM-DD
---

# FEEDBACK_ANALYSIS_PROTOCOL

**Status:** proposed
**Owner:** Verification Agent (with System Architect escalation)
**Last Updated:** YYYY-MM-DD

> Defines how accumulated feedback is analyzed, traced to upstream document gaps,
> and converted into document update suggestions.
> Feedback NEVER directly modifies derived documents — it always flows upstream.

---

## 1. When to Run Analysis

- After every 5 completed tasks (automatic trigger)
- When the user explicitly requests feedback review
- When 3+ feedback entries with the same issue category have accumulated
- At the start of a new session if unreviewed feedback exists in FEEDBACK_LOG

## 2. Pattern Identification

### Step 1: Scan FEEDBACK_LOG

Read all entries since the last analysis. Group by:
- **Issue category** (functional, boundary, performance, style, conflict, other)
- **Task type** (feature, bug, design, audit)
- **Target module** (if applicable)

### Step 2: Identify Repeating Patterns

A pattern is confirmed when:
- Same issue category appears in **2 or more** feedback entries
- OR same implicit negative signal (test failure, git revert) appears **2 or more** times on similar tasks

Record each pattern with:
- Issue description
- Feedback entry IDs (e.g., FB-003, FB-007)
- Frequency count

## 3. Upstream Gap Tracing

For each confirmed pattern, trace backwards through the derivation chain:

```
Feedback pattern identified
    ↓
Which check item should have caught this?
    ↓
Was the check item present in the evaluation checklist?
    ├─ YES → Evaluator execution problem → flag for prompt optimization
    └─ NO → Standard is missing → trace to upstream gap:
         ↓
    Which upstream document should define this standard?
         ├─ Business rule / capability scope → PROJECT_BASELINE gap
         ├─ Technical obligation / failure handling → SYSTEM_GOAL_PACK gap
         │   (but GOAL_PACK is derived → trace further to BASELINE §4 or §5)
         ├─ Module responsibility / boundary → MODULE_CONTRACT gap
         ├─ Known failure pattern → BUG_CLASS_REGISTER gap
         └─ Engineering common sense → Phase 3 engineering practice fill gap
```

### Output Format

For each pattern, produce an **Upstream Update Suggestion**:

```markdown
### UUS-001: [Pattern Description]

- **Pattern:** [what keeps going wrong]
- **Feedback Entries:** FB-XXX, FB-YYY, FB-ZZZ
- **Frequency:** N occurrences across M tasks
- **Root Upstream Gap:** [which document is missing what]
  - Document: PROJECT_BASELINE §X | MODULE_CONTRACT module-name §X | (new)
  - Gap: [what's not covered]
- **Suggested Addition:** [specific text to add to the upstream document]
- **Status:** pending_user_review | accepted | rejected
```

## 4. Standard Deprecation Detection

During each analysis, also check for standards that may be obsolete:

```
For each active check item in CRITERIA_EVOLUTION:
  - Has it been evaluated in the last 10 tasks?
    - NO → flag as "potentially unused, review needed"
  - Has it always passed in the last 10 evaluations?
    - YES → flag as "possibly redundant or too loose, review needed"
  - Has its source document been updated since the check was created?
    - YES → flag as "source changed, re-derivation needed"
```

Flagged items are presented to the user. The user decides:
- **Keep:** the check is still valuable
- **Re-derive:** source changed, run derivation again
- **Deprecate:** no longer needed, move to CRITERIA_EVOLUTION deprecated section

## 5. Escalation Rules

- If a pattern traces to a PROJECT_BASELINE gap → present suggestion to user (BASELINE is user-owned)
- If a pattern traces to a SYSTEM_GOAL_PACK or SYSTEM_INVARIANTS gap → escalate to System Architect for re-derivation from BASELINE
- If a pattern traces to a MODULE_CONTRACT gap → escalate to Module Architect
- If a pattern is an evaluator execution problem → add to autoresearch optimization targets
- If patterns conflict with each other → escalate to System Architect for authority judgment

## 6. What This Protocol Does NOT Do

- Does NOT directly modify ACCEPTANCE_RULES, VERIFICATION_ORACLE, or any derived document
- Does NOT create new check items without tracing to an upstream source
- Does NOT override user decisions on BASELINE content
- Does NOT run automatically without the user being informed of pending suggestions
