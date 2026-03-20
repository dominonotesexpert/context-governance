# Context Governance — Codex Auto-Routing

> This file is intended as the project-level entrypoint for Codex-style agents.
> It tells the agent what to read first and how to route tasks through the governance roles.

## Automatic Agent Routing Protocol

For every repository task:

1. Read `docs/agents/BOOTSTRAP_READINESS.md` if it exists.
   - If the project is not bootstrapped yet, use the framework bootstrap instructions first.
2. Treat `docs/agents/` as the active truth namespace.
3. Use this route by task type:

Note: `docs/agents/PROJECT_BASELINE.md` is the Tier 0 root of all truth, but only System Architect loads it directly. All other roles consume baseline constraints through derived documents. See ROUTING_POLICY §4 for each role's artifact loading list.

   - bug / regression / test failure / deploy failure / log analysis / unexpected behavior
     - `System -> Module -> Debug -> Implementation -> Verification`
   - implementation / refactor / feature
     - `System -> Module -> Implementation -> Verification`
   - design / architecture / protocol / contract authoring
     - `System -> Module -> Verification` (NO implementation unless explicitly requested)
   - UI / interaction / accessibility / performance
     - add `Frontend Specialist` to the applicable route above
   - document review / authority dispute / baseline conflict
     - `System Architect` only

## Role Activation

**System Architect**
- Read:
  - `docs/agents/PROJECT_BASELINE.md` (Tier 0 — only System Architect loads this directly)
  - `docs/agents/system/SYSTEM_GOAL_PACK.md`
  - `docs/agents/system/SYSTEM_AUTHORITY_MAP.md`
  - `docs/agents/system/SYSTEM_INVARIANTS.md`

**Module Architect**
- Read the target module's `MODULE_CONTRACT.md`

**Debug Agent** (bug tasks only)
- Read:
  - `docs/agents/debug/DEBUG_CASE_TEMPLATE.md`
  - `docs/agents/system/SYSTEM_SCENARIO_MAP_INDEX.md`
- Build a `DEBUG_CASE` before changing code
- Confirm root cause with evidence
- Discuss fix options with the user before implementation

**Implementation Agent**
- Write code within upstream contracts
- Escalate instead of silently rewriting upstream truth

**Verification Agent**
- Read `docs/agents/verification/ACCEPTANCE_RULES.md`
- Verify with evidence before any completion claim

## Hard Rules

1. No fix without root cause.
2. No implementation without contract.
3. No completion without evidence.
4. Code is evidence, not truth.
5. Downstream does not rewrite upstream truth.
6. Derived documents never hand-edited. Changes flow upstream through the derivation chain.
7. Constraints by mechanism, not expectation.
