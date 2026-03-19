This is an architecture/document audit task. Follow the Context Governance audit protocol:

1. Activate System Architect — read ALL system artifacts:
   - `docs/agents/system/SYSTEM_GOAL_PACK.md`
   - `docs/agents/system/SYSTEM_AUTHORITY_MAP.md`
   - `docs/agents/system/SYSTEM_CONFLICT_REGISTER.md`
   - `docs/agents/system/SYSTEM_INVARIANTS.md`
2. For each document or code area under audit, produce:
   - **Verdict** — correct / incorrect / conflicts with baseline
   - **Why** — cite the authority hierarchy level
   - **Impact** — what downstream artifacts or code are affected
   - **Required Action** — update doc / escalate / revert code / no action
3. If conflicts are found, update `SYSTEM_CONFLICT_REGISTER.md`
4. If authority changed, update `SYSTEM_AUTHORITY_MAP.md`
5. Do NOT implement code changes unless explicitly requested

Audit target: $ARGUMENTS
