# Context Governance — Claude Code Auto-Routing

> This file is read automatically by Claude Code at session start.
> It routes every task through the correct agent sequence without manual prompts.

## Automatic Agent Routing Protocol

For **every** repository task, always:

1. Read `docs/agents/BOOTSTRAP_READINESS.template.md` (or the project's instantiated version at `docs/agents/BOOTSTRAP_READINESS.md`)
2. Treat `docs/agents/` as the **active truth namespace**
3. Classify the task before touching any code:

### Task Classification → Agent Route

| If the task involves... | Route |
|------------------------|-------|
| Bug, regression, test failure, deploy failure, log analysis, unexpected behavior | `System → Module → Debug → Implementation → Verification` |
| Feature implementation, code change, refactoring | `System → Module → Implementation → Verification` |
| UI, interaction, visual, a11y, performance | Add `Frontend Specialist` to the route |
| Architecture, contract, audit, document governance | `System → Module` only — implement only if explicitly required |
| Document review, authority dispute, baseline conflict | `System Architect` only |

### What Each Role Does (in order)

**System Architect** — Read `docs/agents/system/SYSTEM_GOAL_PACK.md`, `SYSTEM_AUTHORITY_MAP.md`, `SYSTEM_INVARIANTS.md`. Establish what is true.

**Module Architect** — Read the target module's `MODULE_CONTRACT.md`. Establish what this module must do and must not do.

**Debug Agent** (bug tasks only) — Read `docs/agents/debug/DEBUG_CASE_TEMPLATE.md` and `docs/agents/system/SYSTEM_SCENARIO_MAP_INDEX.md`. Build a DEBUG_CASE. Confirm root cause with evidence. Discuss fix options with user before proceeding.

**Implementation Agent** — Consume upstream artifacts. Write code within contract boundaries. Escalate if contract is insufficient.

**Verification Agent** — Read `docs/agents/verification/ACCEPTANCE_RULES.md`. Verify contract satisfaction with evidence. No completion claim without proof.

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
