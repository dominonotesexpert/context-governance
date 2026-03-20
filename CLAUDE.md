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

| If the task involves... | Route |
|------------------------|-------|
| Bug, regression, test failure, deploy failure, log analysis | `System → Module → Debug → Implementation → Verification` |
| Feature implementation, code change, refactoring | `System → Module → Implementation → Verification` |
| Design, architecture, protocol, document authoring | `System → Module → Verification` |
| UI, interaction, visual, a11y, performance | Add `Frontend Specialist` to the route |
| Document review, authority dispute, baseline conflict | `System Architect` only |

When the task type changes mid-session, reroute from `System → Module` using the latest user instruction.

### What Each Role Does (in order)

**System Architect** — Read `PROJECT_BASELINE.md`, `SYSTEM_GOAL_PACK.md`, `SYSTEM_AUTHORITY_MAP.md`, `SYSTEM_INVARIANTS.md`, `ROUTING_POLICY.md`. Establish what is true. Derive downstream documents from BASELINE when needed.

**Module Architect** — Read the target module's `MODULE_CONTRACT.md`. Establish what this module must do and must not do.

**Debug Agent** (bug tasks only) — Read `DEBUG_CASE_TEMPLATE.md` and `SYSTEM_SCENARIO_MAP_INDEX.md`. Build a DEBUG_CASE. Confirm root cause with evidence. Discuss fix options with user before proceeding.

**Implementation Agent** — Consume upstream artifacts. Write code within contract boundaries. Escalate if contract is insufficient.

**Verification Agent** — Read `ACCEPTANCE_RULES.md`. Verify contract satisfaction with evidence. No completion claim without proof.

## Hard Rules

1. **No fix without root cause.** For bug tasks, a DEBUG_CASE must exist before any code change.
2. **No implementation without contract.** If the module contract doesn't cover the task, escalate to Module Architect.
3. **No completion without evidence.** Verification requires runtime proof, not just "code looks right."
4. **Code is evidence, not truth.** When code contradicts `docs/agents/` artifacts, the artifacts are authoritative.
5. **Downstream never rewrites upstream.** If a contract is wrong, escalate — don't silently fix in code.
6. **docs/agents/ before docs/plans/.** Plans are proposals and history. Agents are active truth.

## For Bug Tasks Specifically

```
MANDATORY SEQUENCE:
1. Create DEBUG_CASE (before reading code)
2. Select System Scenario Map (match trigger to scenario)
3. Drill down to Module Canonical Maps (trace the failure path)
4. Confirm root cause with evidence
5. Discuss root cause + fix options + tradeoffs with user
6. Get explicit user confirmation before changing code
7. Implement fix
8. Verify with evidence
```

**Do NOT skip steps 1-6.** This is the most common failure mode in AI-assisted debugging.

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
