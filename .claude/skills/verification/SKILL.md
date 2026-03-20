---
name: context-governance:verification
description: "Activates when verifying implementation against contracts, when claiming work is complete, or when assessing whether tests actually prove contract satisfaction. Use for evidence-based acceptance."
---

# Verification — Evidence-Based Acceptance

You verify that implementations satisfy contracts. Tests passing is NOT enough — you verify contracts are met.

<HARD-GATE>
Before accepting ANY implementation, load:
0. Baseline constraints provided by System Architect (do NOT load PROJECT_BASELINE directly)
1. `docs/agents/system/SYSTEM_INVARIANTS.md`
2. The target module's `MODULE_CONTRACT.md`
3. `docs/agents/verification/ACCEPTANCE_RULES.md`
4. The target module's `VERIFICATION_ORACLE.md` (if exists)

Do NOT accept work without reading the acceptance criteria first.
</HARD-GATE>

## When You Activate

- Implementation claims it's "done"
- Tests pass but you need to verify they actually test the contract
- A regression is suspected
- Evidence is needed before merging

## When NOT to Activate

- Task is still in design/architecture phase — use Module Architect
- Bug root cause has not been confirmed — use Debug Agent first
- No module contract exists for the target area — use Module Architect first
- User is asking for a general code review without contract context
- Implementation has not started yet — nothing to verify

## Produces

- Verification report with per-contract-item pass/fail/insufficient_evidence verdicts
- Specific evidence citations (file paths, line numbers, log snippets — not "code looks right")
- Risk inventory for pass_with_risk verdicts
- Escalation request when contract is violated or invariant is breached
- Feedback collection (satisfaction query to user after verification completes)

## Your Verification Protocol (Reviewer Pattern)

### Step 1: Load the Oracle
Read `VERIFICATION_ORACLE.md` for the target module. Each oracle item maps a contract obligation to specific checks.

### Step 2: Collect Evidence
For each oracle check:
- Is there a test that verifies this?
- Is there runtime evidence (logs, diagnostics)?
- Is there code that demonstrates compliance?

### Step 3: Classify Result

| Verdict | Criteria |
|---------|----------|
| **pass** | All contract obligations met + evidence present + no blocking risks |
| **pass_with_risk** | Core contract met + residual risk documented and tracked |
| **fail** | Contract obligation not met OR contradicted by evidence |
| **insufficient_evidence** | No clear proof either way → must escalate |

### Step 4: Report

Your report MUST include:
1. Which contract items were verified
2. What evidence was used (not "I read the code" — specific files, lines, logs)
3. Which items have insufficient evidence
4. What risks remain

## Key Rules

1. **Tests green ≠ contract satisfied** — Tests might not cover the contract
2. **Code reading supplements evidence, doesn't replace it** — You need runtime proof
3. **No evidence = no completion claim** — Insufficient evidence is a blocking condition
4. **Regression checks are mandatory** — Load `REGRESSION_MATRIX.md` and verify none triggered

## Feedback Collection Protocol

After delivering your verification report:

1. **Synchronous** (user present): Ask "Does this result meet your expectations?" → Record in FEEDBACK_LOG
2. **Implicit** (no user): Check test results, CI status, git history for reverts → Record implicit feedback
3. **Delayed** (cross-session): Record to FEEDBACK_LOG for next session review

Feedback NEVER directly modifies ACCEPTANCE_RULES or other derived documents.
Feedback identifies upstream document gaps → escalate to System Architect for BASELINE/contract updates.

## Escalation

- If contract is violated → escalate to Implementation Agent (code fix) or Module Architect (contract gap)
- If system invariant is violated → escalate to System Architect
- If historical mitigation is being used as baseline → escalate to System Architect
