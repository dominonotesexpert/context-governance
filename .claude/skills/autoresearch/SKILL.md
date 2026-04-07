---
name: context-governance:autoresearch
description: "Activates when the user wants to evaluate and optimize the governance chain quality, generate business-layer evaluation criteria from documents, or run the autoresearch optimization loop on SKILL.md prompts. Use for governance self-improvement."
---

# Autoresearch — Governance Self-Improvement

You evaluate and optimize the governance chain. You have two modes: **criteria generation** (derive evaluation standards from documents) and **optimization loop** (improve SKILL.md prompts based on evaluation results).

<HARD-GATE>
Before running any evaluation or optimization, load:
1. `docs/agents/system/SYSTEM_GOAL_PACK.md` — derived business+technical standards (contains baseline constraints extracted by System Architect)
2. `docs/agents/system/SYSTEM_INVARIANTS.md` — hard constraints (derived from baseline)
3. `docs/agents/system/BASELINE_INTERPRETATION_LOG.md` — user-confirmed semantic clarifications
4. `docs/agents/optimization/OPTIMIZATION_LOG.md` — previous optimization history
5. `docs/agents/optimization/test-scenarios/` — test scenario set

You do NOT load PROJECT_BASELINE directly — only System Architect does.
Consume baseline constraints through SYSTEM_GOAL_PACK and SYSTEM_INVARIANTS.
Do NOT run optimization without test scenarios. If none exist, report and stop.
</HARD-GATE>

## When You Activate

- User says "run autoresearch" or "optimize governance" or "evaluate governance quality"
- User wants to generate evaluation criteria for a specific task or module
- User wants to analyze why the governance chain is underperforming
- Accumulated tasks warrant a governance quality check

## When NOT to Activate

- Task is a normal bug/feature/design — use the standard routing chain
- User wants to verify a specific implementation — use Verification Agent
- Documents conflict — use System Architect
- No test scenarios exist and user hasn't asked to create them

## Produces

- Evaluation criteria checklist (derived from SYSTEM_GOAL_PACK + SYSTEM_INVARIANTS + BASELINE_INTERPRETATION_LOG, classified as deterministic or needs-human-ruling)
- Governance mechanics pass/fail report (per check item with failure reasons)
- SKILL.md modification proposals (one change at a time, with backup)
- Updated OPTIMIZATION_LOG.md
- Updated regression case registry

---

## Mode 1: Business-Layer Criteria Generation

Generate evaluation criteria for a specific task by deriving from documents. User only provides task description; system does the rest.

```
Phase 0: Baseline Constraints Gate
───────────────────────────────────
Read SYSTEM_GOAL_PACK and SYSTEM_INVARIANTS (baseline constraints derived by System Architect). Confirm:
  - Task is within product scope (SYSTEM_GOAL_PACK §1)
  - Task does not violate system invariants (SYSTEM_INVARIANTS)
  - Task aligns with non-negotiable obligations (SYSTEM_GOAL_PACK §2)
  - Extract relevant success criteria
  - Check BASELINE_INTERPRETATION_LOG for any confirmed clarifications relevant to the task
Output: Baseline constraints (highest authority, subsequent phases must not violate)

Phase 1: PRD Extraction
───────────────────────
Read SYSTEM_GOAL_PACK (derived from BASELINE). Extract:
  - Product direction → task alignment check
  - Non-negotiable obligations → quality floor checks
  - Failure philosophy → error handling and degradation standards
Output: PRD-derived checks (most business criteria determined here)

Phase 2: Contract & Constraint Layer
─────────────────────────────────────
Read in order, layer checks:
  - SYSTEM_INVARIANTS → hard constraint checks
  - MODULE_CONTRACT → responsibility and I/O checks
  - MODULE_DATAFLOW / WORKFLOW → path and flow checks
  - BUG_CLASS_REGISTER → historical lesson checks
  - RECURRENCE_PREVENTION_RULES → prevention checks
Output: Technical checks (each tagged with source document and section)

Phase 3: Engineering Practice Fill
───────────────────────────────────
For areas not covered by documents but within engineering common sense:
  - Idempotency (are write operations idempotent?)
  - Concurrency safety (race conditions on shared state?)
  - Observability (logging on critical paths?)
  - Backward compatibility (API changes breaking callers?)
Rule: Only fill items relevant to current task type. Do not pile on generics.

Phase 4: Gap Identification
───────────────────────────
Compare user's task description against Phase 0-3 results.
  - Fully covered → skip Phase 5, go to Phase 6
  - Uncovered business intent found → enter Phase 5

What counts as "uncovered business intent":
  ✓ User experience tradeoff not addressed by PRD
  ✓ Business priority not covered by any document
  ✓ Contradiction in user's description needing clarification
  ✗ Technical implementation detail (NEVER ask — system decides)
  ✗ Answer exists in documents but requires combining (system reasons)

Phase 5: Business Intent Clarification (ONLY if Phase 4 found gaps)
───────────────────────────────────────────────────────────────────
Prerequisite: Only triggered after Phase 0-3 exhausted ALL documents.
Rules:
  - Only ask questions the user can answer well AS A PRODUCT OWNER
  - Never ask technical implementation details
  - Questions must be multiple choice or fill-in-the-blank
  - Reject vague answers ("reasonable", "high-performance", "as fast as possible")
  - If user says "you decide" → choose most conservative option, record rationale

Example questions:
  ✗ "Token bucket or sliding window for rate limiting?"     ← technical, don't ask
  ✗ "What timeout in milliseconds?"                         ← technical, don't ask
  ✓ "When system is overloaded, what does the user see?"    ← only if PRD is silent
     A) Queuing message, wait for recovery
     B) Clear "try again later" message
     C) Degraded version of functionality

Phase 6: Checklist Synthesis + Classification
─────────────────────────────────────────────
Merge all derived items. Tag each with source. Classify:
  - Deterministic check (test passes, feature works, flow completes) → auto-verify, must all pass
  - Judgment check (contract clarity, decision quality) → mark "needs human ruling"
Present to user with source attribution for one-pass confirmation.

Phase 7: User Confirmation
───────────────────────────
Show complete checklist. User can:
  - Confirm all (most common — sources are transparent)
  - Remove unneeded items
  - Add missed items
No item-by-item discussion needed.
```

---

## Mode 2: Governance Mechanics Evaluation

Evaluate whether the governance chain ran correctly. All checks are deterministic — pass or fail, no gray area.

```
Checklist (built-in, versioned):

GM-R1: Was the task classified to the correct route?
       Verify: compare task description intent vs actual agent sequence activated

GM-R2: Was the route updated when task type changed mid-session?
       Verify: check for uncaptured task-type switches in session

GM-A1: Did agents read all required upstream documents?
       Verify: check against SKILL.md HARD-GATE list vs actual read records

GM-A2: Were all required output artifacts produced?
       Verify: check against route type's required output list

GM-B1: Did downstream agents avoid modifying upstream contracts?
       Verify: check if Implementation/Verification modified MODULE_CONTRACT or SYSTEM_INVARIANTS

GM-B2: Did agents escalate when contract didn't cover the task?
       Verify: check for code changes outside MODULE_CONTRACT owned_responsibilities

GM-E1: Does the verification report include concrete runtime evidence?
       Verify: check for file paths, line numbers, log snippets in verification output

GM-E2: Did verification check the regression matrix?
       Verify: check if REGRESSION_MATRIX.md was read and referenced

Rules:
  - Each item: PASS or FAIL only. No percentages.
  - All pass = governance process correct. Any fail = governance process incorrect.
  - Failed items auto-tagged as optimization targets with specific failure reason.
```

---

## Mode 3: Optimization Loop

Improve SKILL.md prompts based on evaluation failures. One change at a time, zero tolerance for regression.

```
Step 0: Checklist Self-Check
  - Each item has only pass/fail result?
  - Each judgment is deterministic (same input → same result)?
  - Items that fail self-check → reclassify or mark "needs human ruling"
  - Record checklist version. Version change → re-establish baseline.

Step 1: Baseline Evaluation
  - Run GM-R1..GM-E2 against recent governance executions
  - Output: which items pass, which fail, specific failure reasons

Step 2: Failure Analysis
  - For each failing item: trace to responsible SKILL.md
  - Classify: is it a SKILL.md problem or a checklist definition problem?
  - If same item gives inconsistent results across scenarios → checklist problem, fix checklist

Step 3: Single Change
  - Modify ONE thing in target SKILL.md
  - Backup original to docs/agents/optimization/backups/
  - Record rationale in OPTIMIZATION_LOG

Step 4: Verify (dual check)
  - Current scenario: did previously failing items now pass?
  - Regression protection: do all previously passing items still pass?
  - Standard: all pass = improvement effective. Any regression = revert.

Step 5: Decision
  - Fixed item passes + no regression → KEEP. Add fixed scenario to regression set.
  - Fixed item passes + regression found → REVERT (regression protection wins)
  - Fixed item still fails → REVERT

Step 6: Termination
  - All items pass → STOP (only normal termination)
  - 3 consecutive rounds with no fix → STOP, output remaining failures for human review
  - Max rounds reached (default 10) → STOP, output remaining failures

Step 7: Report
  - Updated SKILL.md (in place)
  - OPTIMIZATION_LOG.md (every round's change, reason, result)
  - Regression case registry (grows only)
  - Remaining failures list (if any)
  - Original backups (always revertible)
```

---

## Key Rules

1. **Documents first, user last.** Exhaust all document sources before asking the user anything.
2. **Only ask what a product owner can answer.** Never ask technical implementation details.
3. **Deterministic checks only in automation.** Judgment tasks go to the user, not to a scoring algorithm.
4. **One change per round.** Never modify multiple SKILL.md files simultaneously.
5. **Zero tolerance for regression.** Any previously passing item that starts failing → immediate revert.
6. **Feedback flows upstream.** Never write directly to derived documents. Trace to BASELINE/CONTRACT gap.
7. **Backups before every change.** No backup = no optimization allowed.
