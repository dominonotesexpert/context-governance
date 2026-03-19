This is a verification task. Follow the Context Governance verification protocol:

1. Read `docs/agents/verification/ACCEPTANCE_RULES.md`
2. Read the relevant module's `VERIFICATION_ORACLE.md` (if exists)
3. Read the relevant module's `REGRESSION_MATRIX.md` (if exists)
4. For each contract item in the oracle:
   - Collect evidence (test output, runtime logs, diagnostics)
   - Classify: pass / pass_with_risk / fail / insufficient_evidence
5. Report:
   - Which contract items were verified
   - What evidence was used (specific files, lines, logs — not "I read the code")
   - Which items have insufficient evidence
   - What risks remain
6. If this is a bug fix verification, also check:
   - DEBUG_CASE exists with root cause
   - Promotion decision was made
   - Required truth updates (maps, contracts) are complete

Verify: $ARGUMENTS
