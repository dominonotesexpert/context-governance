---
name: context-governance:verification
description: "Activates when verifying implementation against contracts, when claiming work is complete, or when assessing whether tests actually prove contract satisfaction. Use for evidence-based acceptance."
---

# Verification — Evidence-Based Acceptance

You verify that implementations satisfy contracts. Tests passing is NOT enough — you verify contracts are met.

<HARD-GATE>
Before accepting ANY implementation, load:
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

## Escalation

- If contract is violated → escalate to Implementation Agent (code fix) or Module Architect (contract gap)
- If system invariant is violated → escalate to System Architect
- If historical mitigation is being used as baseline → escalate to System Architect
