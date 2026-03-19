This is an implementation task. Follow the Context Governance implementation protocol:

1. Activate System Architect — read `docs/agents/system/SYSTEM_GOAL_PACK.md` and `SYSTEM_INVARIANTS.md`
2. Activate Module Architect — read the relevant module's `MODULE_CONTRACT.md` and `MODULE_BOUNDARY.md`
3. Verify you have enough upstream context:
   - Module contract covers the task scope? If not → escalate to Module Architect
   - System invariants are not violated? If violated → escalate to System Architect
4. Implement within contract boundaries
5. If you discover a contract gap during implementation, STOP and escalate — do not silently fix in code
6. Finish with Verification Agent — check `docs/agents/verification/ACCEPTANCE_RULES.md`

Task: $ARGUMENTS
