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

### 3A. Active Baseline Lock

- **Active authoritative constraints:** <!-- Exact current contracts/invariants/approved decisions -->
- **Retired or non-authoritative concepts:** <!-- Old plans, workarounds, stale docs -->
- **Observation-only inputs:** <!-- Code/log/test/runtime/UI evidence that may prove facts but not define truth -->
- **Allowed RCA space:** <!-- Layers and decisions this role may investigate -->

## 4. Trace

- **Scenario Path:** <!-- Which system scenario map was matched? -->
- **Suspect Module Chain:** <!-- Module A → Module B → Module C -->
- **Workflow Trace:** <!-- Which workflow steps were hit? Where did it deviate? -->
- **Dataflow Trace:** <!-- Which data transformations occurred? Where did data corrupt? -->
- **Code Path:** <!-- Specific files and functions involved -->

### 4A. Presentation / Handoff Checks (if applicable)

- **Expected semantic/source owner:** <!-- Contract-defined owner -->
- **Expected presentation/derived layer mounted?:** yes | no | unknown
- **Expected layer visible and participating in layout?:** yes | no | unknown
- **Superseded layer actually inactive/non-visible?:** yes | no | n/a | unknown
- **Current user-visible surface owner:** <!-- Exact observed layer -->
- **Authority warning:** <!-- Presentation observations must not silently redefine semantic identity/ownership -->

## 5. Root Cause

- **Confidence:** confirmed | partial | hypothesis
- **Which hop failed:** <!-- e.g., "Module B → Module C handoff" -->
- **Why it failed:** <!-- Technical explanation -->
- **Contract/Invariant violated:** <!-- Which specific contract or invariant was broken -->
- **Defect type:** single-point | pattern
- **Disproven alternatives:** <!-- Which tempting explanations were ruled out -->
- **Root Cause Level:** code | module | cross-module | engineering-constraint | architecture | baseline
- **Level Justification:** <!-- Why this level and not a lower/higher one -->
- **Authority Anchor:** <!-- Exact active contract/invariant/design reference -->
- **Observation Anchor:** <!-- Exact code/log/test/runtime evidence -->

## 5A. Root Cause Validation Gate

All items MUST be checked before setting Confidence to `confirmed`:

- [ ] **Anti-falsification:** At least 2 alternative hypotheses proposed AND disproven with evidence
- [ ] **Prediction verified:** A specific prediction derived from hypothesis was confirmed by observation
- [ ] **All symptoms explained:** Root cause accounts for every observed symptom, not just the primary one
- [ ] **Open gaps empty:** No items remain in Evidence Ledger > Open Evidence Gaps
- [ ] **Double anchor:** Both an authority anchor and an observation anchor independently support the conclusion

If ANY item unchecked, Confidence MUST remain `partial` or `hypothesis`.

Note: User confirmation is NOT part of this gate. This is the autonomous quality gate.
User escalation is governed by the business-semantics boundary (see Debug SKILL Step 8A).

## 6. Fix Scope

- **Recommended changes:** <!-- Files, functions, logic to modify -->
- **Verification targets:** <!-- What must be verified after fix -->
- **Truth updates required:** <!-- Do any maps, contracts, or invariants need updating? -->

### 6A. Scope Lock

- **Authorized outcome:** <!-- The one result requested -->
- **Allowed change surface:** <!-- Modules/files/behaviors allowed to change -->
- **Explicit exclusions:** <!-- Adjacent behaviors and concepts that remain unchanged -->
- **Smallest owning-layer change:** <!-- Why this is the minimum systemic repair -->

### 6B. Authority Diff

| Question | Before | After proposed fix |
|---|---|---|
| Who owns canonical truth? | <!-- --> | <!-- --> |
| What is observation-only? | <!-- --> | <!-- --> |
| Are new identity/state/ownership/gates introduced? | <!-- --> | <!-- --> |

If the proposal changes authority, stop and escalate to the owning upstream role before implementation.

### 6C. Family-Level Fix Scope

- **Observed failure shapes:** <!-- List manifestations -->
- **Shared violated invariant:** <!-- Or evidence that these are separate bugs -->
- **Owning enforcement layer:** <!-- Producer, contract, validator, runtime, etc. -->
- **Instance-specific branches rejected:** <!-- Labels/wrappers/examples that must not become production rules -->

### 6D. Blocking Gate Proof (only if the fix adds a blocker)

- **Correct outcome protected:** <!-- -->
- **Incorrect/unsafe result without blocker:** <!-- -->
- **Reachability evidence:** <!-- -->
- **Why warning/ignore/existing downstream owner is insufficient:** <!-- -->
- **Why this stage owns the decision:** <!-- -->
- **Deletion Counterfactual result:** <!-- Remove blocker and trace the minimum successful path -->

## 7. Promotion

- **Decision:** not_promoted | promoted
- **Reason:** <!-- Why this is/isn't a systemic pattern -->
- **Impact scope:** <!-- If promoted: what other modules/scenarios are affected? -->
- **Bug class:** <!-- If promoted: reference to BUG_CLASS_REGISTER entry -->
