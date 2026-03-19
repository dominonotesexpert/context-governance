# Verification Templates

These templates define verification truth.

Instantiate:

- `ACCEPTANCE_RULES.template.md` -> `docs/agents/verification/ACCEPTANCE_RULES.md`
- `VERIFICATION_ORACLE.template.md` -> `docs/agents/verification/<module>/VERIFICATION_ORACLE.md`
- `REGRESSION_MATRIX.template.md` -> `docs/agents/verification/<module>/REGRESSION_MATRIX.md`
- `VERIFICATION_BOOTSTRAP_PACK.template.md` -> `docs/agents/verification/<module>/VERIFICATION_BOOTSTRAP_PACK.md`

The verification layer answers:

- What counts as pass/fail?
- Which module contracts must be checked?
- Which regressions must never come back?
