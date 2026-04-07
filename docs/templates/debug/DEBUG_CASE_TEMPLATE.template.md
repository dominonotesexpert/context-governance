---
artifact_type: debug-case
status: proposed
owner_role: debug
scope: debug
downstream_consumers: [implementation, verification]
last_reviewed: 2026-03-21
---

# DEBUG_CASE: [YYYY-MM-DD-topic]

**Status:** open | investigating | root-caused | closed
**Owner:** Debug Agent
**Date:** YYYY-MM-DD
**Severity:** critical | high | medium | low

---

## 1. Metadata

- **Trigger:** <!-- What user action or system event triggered the bug? -->
- **Environment:** <!-- Browser, OS, server version, relevant config -->
- **Reported By:** <!-- Who reported it? -->
- **Case Type:** regression-suspected | new defect | unknown
- **Last Known Good:** <!-- What definitely worked before? Link evidence if available -->
- **First Known Bad:** <!-- First confirmed failure state -->
- **Behavior Delta:** <!-- What changed from user-visible/system-visible perspective -->
- **Suspect Change Window:** <!-- Recent commits / sessions / design changes likely involved -->

## 2. Reproduction Summary

- **Steps to Reproduce:**
  1. <!-- Step 1 -->
  2. <!-- Step 2 -->
  3. <!-- Step 3 -->
- **Input / Parameters:** <!-- Specific values, request payloads, etc. -->
- **Actual Behavior:** <!-- What happened -->
- **Expected Behavior:** <!-- What should have happened -->
- **Evidence:** <!-- Logs, screenshots, stack traces, request/response samples -->

## 3. Evidence Ledger

- **Confirmed Evidence:** <!-- Facts directly supported by logs, DOM, screenshots, tests, or code-linked trace -->
- **Inference:** <!-- Plausible explanation not yet directly proven -->
- **Disproven:** <!-- Theories ruled out by evidence -->
- **Open Evidence Gaps:** <!-- What still needs to be captured before root cause is confirmed -->

## 4. Trace

- **Scenario Path:** <!-- Which system scenario map was matched? -->
- **Suspect Module Chain:** <!-- Module A → Module B → Module C -->
- **Workflow Trace:** <!-- Which workflow steps were hit? Where did it deviate? -->
- **Dataflow Trace:** <!-- Which data transformations occurred? Where did data corrupt? -->
- **Code Path:** <!-- Specific files and functions involved -->

### 4A. UI / Handoff Checks (if applicable)

- **Source hidden marker present?:** yes | no | n/a
- **Source actually non-visible?:** yes | no | unknown
- **Proxy/direct-html mounted?:** yes | no | unknown
- **Proxy/direct-html visible in layout?:** yes | no | unknown
- **Current visible surface owner:** source | proxy/direct-html | mixed | unknown

## 5. Root Cause

- **Confidence:** confirmed | partial | hypothesis
- **Which hop failed:** <!-- e.g., "Module B → Module C handoff" -->
- **Why it failed:** <!-- Technical explanation -->
- **Contract/Invariant violated:** <!-- Which specific contract or invariant was broken -->
- **Defect type:** single-point | pattern
- **Disproven alternatives:** <!-- Which tempting explanations were ruled out -->
- **Root Cause Level:** code | module | cross-module | engineering-constraint | architecture | baseline
- **Level Justification:** <!-- Why this level and not a lower/higher one -->

## 5A. Root Cause Validation Gate

All items MUST be checked before setting Confidence to `confirmed`:

- [ ] **Anti-falsification:** At least 2 alternative hypotheses proposed AND disproven with evidence
- [ ] **Prediction verified:** A specific prediction derived from hypothesis was confirmed by observation
- [ ] **All symptoms explained:** Root cause accounts for every observed symptom, not just the primary one
- [ ] **Open gaps empty:** No items remain in Evidence Ledger > Open Evidence Gaps

If ANY item unchecked, Confidence MUST remain `partial` or `hypothesis`.

Note: User confirmation is NOT part of this gate. This is the autonomous quality gate.
User escalation is governed by the business-semantics boundary (see Debug SKILL Step 8A).

## 6. Fix Scope

- **Recommended changes:** <!-- Files, functions, logic to modify -->
- **Verification targets:** <!-- What must be verified after fix -->
- **Truth updates required:** <!-- Do any maps, contracts, or invariants need updating? -->

## 7. Promotion

- **Decision:** not_promoted | promoted
- **Reason:** <!-- Why this is/isn't a systemic pattern -->
- **Impact scope:** <!-- If promoted: what other modules/scenarios are affected? -->
- **Bug class:** <!-- If promoted: reference to BUG_CLASS_REGISTER entry -->
