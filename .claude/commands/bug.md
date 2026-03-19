This is a bug/debug task. Follow the Context Governance debug protocol:

1. Activate System Architect — read `docs/agents/system/SYSTEM_GOAL_PACK.md` and `SYSTEM_INVARIANTS.md`
2. Activate Module Architect — read the relevant module's `MODULE_CONTRACT.md`
3. Activate Debug Agent:
   - Read `docs/agents/debug/DEBUG_CASE_TEMPLATE.md`
   - Read `docs/agents/system/SYSTEM_SCENARIO_MAP_INDEX.md`
   - Create a DEBUG_CASE before reading any code
   - Match the bug to a system scenario map
   - Drill down to module canonical workflow/dataflow maps
   - Confirm root cause with concrete evidence
   - Discuss fix options and tradeoffs with me
   - Wait for my explicit confirmation before changing code
4. Only after confirmation, proceed to Implementation
5. Finish with Verification — evidence required, not just "looks right"

Bug description: $ARGUMENTS
