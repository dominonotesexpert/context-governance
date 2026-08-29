# Context Governance — Claude Code Auto-Routing

> This file is read automatically by Claude Code at session start.
> It routes every task through the correct agent sequence without manual prompts.

## Automatic Agent Routing Protocol

For **every** repository task, always:

1. Read `docs/agents/BOOTSTRAP_READINESS.md` (or the template version at `docs/agents/BOOTSTRAP_READINESS.template.md`)
2. Read `docs/agents/system/ROUTING_POLICY.md` — this is the **single source of truth** for task routing
3. Treat `docs/agents/` as the **active truth namespace**
4. Classify the task before touching any code, following the routing policy

**Note:** `docs/agents/PROJECT_BASELINE.md` is the Tier 0 root of all truth, but **only System Architect loads it directly**. All other roles consume the baseline constraints extracted by System Architect through derived documents (SYSTEM_GOAL_PACK, SYSTEM_INVARIANTS). See ROUTING_POLICY §4 for each role's artifact loading list.

### Quick Reference (authoritative version in ROUTING_POLICY.md)

- Always load System context.
- Load Module context for a concrete module.
- Add Debug for production, cross-stage, repeated, ambiguous, or formal-RCA incidents.
- Add formal Verification for release, merge, deploy, security, cross-module, oracle, or explicitly requested acceptance.
- Routine implementation and locally proven low-risk bugs execute after the context gates with proportionate evidence.

When the task type changes mid-session, reroute from `System → Module` using the latest user instruction.

### What Each Role Does (in order)

**System Architect** — Read `PROJECT_BASELINE.md`, `BASELINE_INTERPRETATION_LOG.md`, `PROJECT_ARCHITECTURE_BASELINE.md`, `SYSTEM_GOAL_PACK.md`, `ENGINEERING_CONSTRAINTS.md`, `SYSTEM_AUTHORITY_MAP.md`, `SYSTEM_INVARIANTS.md`, `GOVERNANCE_MODE.md`, `SYSTEM_ARCHITECTURE.md`, `ROUTING_POLICY.md`. Establish what is true. Derive downstream documents from BASELINE when needed. When business ambiguity is found, create interpretation entries for user confirmation.

**Module Architect** — Read the target module's `MODULE_CONTRACT.md`. Establish what this module must do and must not do.

**Debug Agent** (formal Debug route only) — Read `RCA_HARD_CONSTRAINTS.md`, `DEBUG_CASE_TEMPLATE.md`, and `SYSTEM_SCENARIO_MAP_INDEX.md`. Build a DEBUG_CASE. Lock the active baseline, keep `Confirmed Evidence`, `Inference`, and `Disproven` separate, and require both an authority anchor and an observation anchor before confirming root cause.

**Implementation Agent** — Consume upstream artifacts. Write code within contract boundaries. Escalate if contract is insufficient.

**Verification Agent** (formal Verification route only) — Read `ACCEPTANCE_RULES.md`. Verify contract satisfaction with evidence. Routine tasks still require proportionate evidence without activating this role.

## Hard Rules

1. **No fix without root cause.** A DEBUG_CASE is mandatory when formal Debug is triggered. A routine bug requires a cited root-cause observation but not a formal case artifact.
2. **No implementation without contract.** If the module contract doesn't cover the task, escalate to Module Architect.
3. **No completion without evidence.** Verification requires runtime proof, not just "code looks right."
4. **Code is evidence, not truth.** When code contradicts `docs/agents/` artifacts, the artifacts are authoritative.
5. **Downstream never rewrites upstream.** If a contract is wrong, escalate — don't silently fix in code.
6. **docs/agents/ before docs/plans/.** Plans are proposals and history. Agents are active truth.
7. **Design tasks default to a complete draft.** Do not ask the user to approve each section one-by-one; only ask consolidated blocking questions when business ambiguity or authority conflict would otherwise reduce correctness.
8. **MODULE_CONTRACT is approved truth, not a code snapshot.** Code changes may satisfy the contract, drift from it, or reveal that upstream truth must change — but code does not automatically rewrite the contract.
9. **Inference is not root cause.** In bug work, keep `Confirmed Evidence`, `Inference`, and `Disproven` separate. Do not present a plausible theory as confirmed until evidence closes the gap.
10. **Observation is not authority.** Code, logs, DOM, and runtime state may prove drift; they cannot silently redefine canonical identity, ownership, state, or architecture.

## When the Formal Debug Route Is Triggered

```
MANDATORY SEQUENCE:
1. Create DEBUG_CASE (before reading code)
2. If it is a regression, establish Last Known Good / First Known Bad / Behavior Delta
3. Select System Scenario Map (match trigger to scenario)
4. Drill down to Module Canonical Maps (trace the failure path)
5. For UI/runtime handoff bugs, prove which layer is hidden, mounted, visible, and owning the user-visible surface
6. Upstream boundary check at each module hop
7. Confirm root cause with evidence + Prediction-observation validation
8. Complete Root Cause Validation Gate (5 items, including Double Anchor) + Classify root cause level
8A. Escalation gate: if level = baseline, or architecture requiring Tier 0.8 change or business-semantic impact → user confirmation required. Otherwise proceed autonomously.
9. Route by level: code→Impl, module→Impl+MA review, cross-module→MA, engineering-constraint→SA(EC update), architecture→SA, baseline→User
10. Implement fix (only after routing gate clears)
11. Verify with evidence
```

**Do NOT skip steps 1-8A on the formal Debug route.** Routine low-risk bugs use the System/Module scope lock, record concise root-cause evidence, implement the smallest systemic fix, and run proportionate checks.
Note: In `incident` governance mode, steps 6-8A are deferred to post-incident review per ROUTING_POLICY §8.

## Context Compression Priority

When context approaches capacity, preserve in this order:

1. **PROJECT_BASELINE references** — never summarize, always keep verbatim
2. **Architecture decisions and escalation records** — the "why" behind choices
3. **MODULE_CONTRACT changes** — what changed and why
4. **Verification verdicts** — pass/fail/insufficient per contract item
5. **Unresolved escalations and contract gaps** — open issues must survive compression
6. **Tool outputs and intermediate traces** — may be deleted, keep only conclusions

**Identifier protection:** commit hashes, file paths, PR numbers, line numbers, UUIDs, URLs must be preserved exactly as-is during compression. Never rewrite, simplify, or "correct" them.

## Constraint Principle

**Constraints by mechanism, not expectation.** Rules that can be encoded into HARD-GATEs, hooks, or tool validations MUST be. A rule that exists only as a suggestion in a document is not a constraint — it is a wish.
