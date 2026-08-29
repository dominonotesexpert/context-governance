---
artifact_type: regression-matrix
status: proposed
owner_role: verification
scope: verification
downstream_consumers: [implementation, debug]
last_reviewed: 2026-03-20
---

# REGRESSION_MATRIX: [module-name]

**Status:** proposed
**Owner:** Verification Agent
**Last Updated:** YYYY-MM-DD

---

## 1. Purpose

Known regression classes for [module-name]. When reviewing changes, check each class. If any trigger matches, follow the escalation path.

## 2. Regression Classes

### RG-001: [Regression Class Name]

**Description:** <!-- What kind of regression is this? -->
**Triggers:** <!-- When should you suspect this regression? -->
**Checklist:**
<!-- - [ ] Check A -->
<!-- - [ ] Check B -->
**Escalation:** <!-- Who to notify if triggered? -->

### RG-002: [Regression Class Name]

<!-- Repeat for each known regression class -->

<!-- TIP: Seed this with regressions you've actually seen. -->
<!-- Don't invent hypothetical regressions — add them when they happen. -->

## 3. Evidence Selection

- Localized change: focused incident pin plus relevant existing tests.
- Reusable failure class: incident pin plus representative family/corpus replay when artifacts exist.
- Cross-module change: assert the contract at every affected handoff.
- Release/deploy/live change: verify the built/deployed artifact and the exact affected environment path.
- Preserve missing modes or artifacts as `UNTESTABLE: <reason>`; never silently exclude them.
- Compare failing test names or identities against baseline, not only counts.
