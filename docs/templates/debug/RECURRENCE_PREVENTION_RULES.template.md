---
artifact_type: recurrence-prevention-rules
status: proposed
owner_role: debug
scope: debug
downstream_consumers: [implementation, verification]
last_reviewed: 2026-03-20
---

# RECURRENCE_PREVENTION_RULES

**Status:** proposed
**Owner:** Debug Agent
**Last Updated:** YYYY-MM-DD

---

## 1. Purpose

Actionable rules to prevent known bug classes from recurring. Each rule is linked to a bug class and specifies where in the system the prevention should be enforced.

## 2. Rule Scope Layers

Prevention rules can operate at any of these layers:

| Layer | Example |
|-------|---------|
| Test / Assertion | Add a specific test case covering the failure path |
| Validator / Gate | Add a gate check that catches the condition before it propagates |
| Runtime Guard | Add a runtime assertion or diagnostic |
| Module Contract | Update the module contract to explicitly forbid the pattern |
| System Invariant | Promote to system-level invariant if cross-module |

## 3. Rules

### RP-001: [Rule Name]

- **Status:** active
- **Bug Class:** <!-- Link to BUG_CLASS_REGISTER entry -->
- **Layer:** <!-- test | validator | runtime | contract | invariant -->
- **Rule:** <!-- Clear, actionable statement of what must be done -->
- **Enforcement:** <!-- How is this rule checked? Automated test? Manual review? Gate? -->
- **Date Added:** YYYY-MM-DD

<!-- Add more rules as bug classes are registered -->
