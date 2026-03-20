---
artifact_type: prompt-tuning-protocol
status: proposed
owner_role: autoresearch
scope: optimization
downstream_consumers: [system-architect]
last_reviewed: YYYY-MM-DD
---

# PROMPT_TUNING_PROTOCOL

**Status:** proposed
**Owner:** Autoresearch process
**Last Updated:** YYYY-MM-DD

> Defines how SKILL.md files are modified during the optimization loop.
> Every modification must follow this protocol — no exceptions.

---

## 1. Single Change Constraint

Each optimization round modifies **exactly one thing** in **exactly one SKILL.md**.

Never:
- Modify two SKILL.md files in one round
- Make multiple unrelated changes in one round
- Change HARD-GATE loading order and prompt wording simultaneously

Why: If a round causes regression, you must know exactly what caused it. Multiple changes make attribution impossible.

## 2. Allowed Modification Directions

Listed in priority order. Try the first applicable direction before moving to the next.

### a) Precision — Make a vague instruction specific

```
Before: "Pay attention to edge cases"
After:  "You MUST verify handling of: null input, empty array, string exceeding 1000 chars"
```

### b) Worked Example — Add a concrete example of the desired behavior

```
Before: "Produce a verification report with evidence"
After:  "Produce a verification report with evidence. Example:
         - Contract item: 'API returns structured errors'
         - Evidence: tests/api/error_format.test.ts:42 — asserts {code, message, detail} shape
         - Verdict: PASS"
```

### c) Explicit Prohibition — Add a NEVER rule for observed failures

```
Before: (no rule about this case)
After:  "NEVER claim verification is complete based on 'code looks correct'.
         You must cite specific test files, log entries, or runtime output."
```

### d) Execution Order — Reorder steps if sequence causes information loss

```
Before: Step 1: Write code. Step 2: Read contract.
After:  Step 1: Read contract. Step 2: Write code within contract.
```

## 3. Backup Protocol

Before ANY modification:

1. Copy the target file to `docs/agents/optimization/backups/`
2. Naming: `{skill-name}-SKILL.{round-number}.backup.md`
   - Example: `verification-SKILL.003.backup.md`
3. Verify the backup exists and is readable before proceeding
4. **No backup = no modification allowed**

Retention: keep the 10 most recent backups per skill. Delete older ones.

## 4. Recording Protocol

Every modification MUST be recorded in OPTIMIZATION_LOG.md:

```
- Target: which SKILL.md
- Round: number
- Direction: precision | worked_example | prohibition | execution_order
- Before: the exact text being replaced (copy verbatim)
- After: the exact replacement text (copy verbatim)
- Rationale: which check item failed, what pattern was observed
- Backup: path to backup file
```

## 5. What Must NOT Be Modified

The optimization loop may NOT change:
- HARD-GATE loading lists (which documents are loaded)
- Role activation conditions (when the skill activates)
- Core responsibility boundaries (what the role owns vs doesn't own)
- Upstream/downstream relationships (who escalates to whom)

These are architectural decisions owned by System Architect, not optimization targets.
