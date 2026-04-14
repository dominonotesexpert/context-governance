# Context Governance — Hermes Agent Auto-Routing

> This file is loaded into Hermes Agent sessions via AGENTS.md or context file injection.
> It routes every task through the correct governance sequence.
> Hermes provides infrastructure (memory, MCP, scheduling); CG provides governance semantics.

## Critical Principle: Memory Is Context, Documents Are Truth

Hermes persistent memory may contain governance state from prior sessions. This is supplementary context only. You MUST still load the documents specified by each role's HARD-GATE requirements. Never substitute a memory recall for an actual file read of a governance artifact.

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
  - `docs/agents/system/BASELINE_INTERPRETATION_LOG.md` (Tier 0.5)
  - `docs/agents/system/SYSTEM_GOAL_PACK.md`
  - `docs/agents/system/SYSTEM_AUTHORITY_MAP.md`
  - `docs/agents/system/SYSTEM_INVARIANTS.md`
  - `docs/agents/system/ENGINEERING_CONSTRAINTS.md` (Tier 1.5)
  - `docs/agents/PROJECT_ARCHITECTURE_BASELINE.md` (Tier 0.8)
  - `docs/agents/execution/GOVERNANCE_MODE.md`
  - `docs/agents/system/SYSTEM_ARCHITECTURE.md` (Tier 2)

**Module Architect**
- Read the target module's `MODULE_CONTRACT.md`

**Debug Agent** (bug tasks only)
- Read:
  - `docs/agents/debug/DEBUG_CASE_TEMPLATE.md`
  - `docs/agents/system/SYSTEM_SCENARIO_MAP_INDEX.md`
- Build a `DEBUG_CASE` before changing code
- Separate `Confirmed Evidence`, `Inference`, and `Disproven` in the case
- If the user says it used to work, establish `Last Known Good`, `First Known Bad`, and `Behavior Delta` before claiming root cause
- Confirm root cause with evidence
- Classify root cause level: code | module | cross-module | engineering-constraint | architecture | baseline
- Escalation gate: user confirmation for baseline, or architecture requiring Tier 0.8 change

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
8. Design tasks default to a complete draft, not a section-by-section approval loop.
9. MODULE_CONTRACT is approved module truth maintained by the system, not a snapshot of current code behavior.
10. In bug work, inference must never be presented as confirmed root cause.

## Hermes-Specific Integration Rules

11. **Memory is context, documents are truth.** Hermes persistent memory supplements but never replaces governance artifact loading.
12. **Cron jobs are read-only.** Scheduled governance checks report findings via notifications. They never modify governance artifacts, documents, or code.
13. **Notifications are informational.** Escalation notifications sent via Slack/Telegram/Discord reflect `.governance/escalations.jsonl` state but are not authoritative. Always check the canonical file.
14. **MCP tools are the interface.** Use `governance_start_task`, `governance_update_receipt`, `governance_record_debug_case`, `governance_record_escalation`, `governance_record_verification`, `governance_complete_task`, and `governance_run_checks` via the auto-discovered `context-governance` MCP server.
15. **No self-evolution of governance artifacts.** Hermes self-improvement must not modify files in `docs/agents/`, `.governance/`, or governance scripts. These are governed by the autoresearch protocol only.

## Receipt Management

Use the governance MCP tools (auto-discovered by Hermes from `context-governance` MCP server):

- Call `governance_start_task` to create a receipt
- Call `governance_update_receipt` as evidence is produced
- Call `governance_complete_task` when done

If MCP is unavailable:

- Create receipt manually per `docs/templates/governance/MANUAL_ATTESTATION_POLICY.md`
- Set `attestation_mode: manual_attestation` with reason
