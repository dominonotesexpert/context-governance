---
artifact_type: debug-case
status: proposed
owner_role: debug
scope: debug
downstream_consumers: [implementation, verification]
last_reviewed: 2026-03-20
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

## 2. Reproduction Summary

- **Steps to Reproduce:**
  1. <!-- Step 1 -->
  2. <!-- Step 2 -->
  3. <!-- Step 3 -->
- **Input / Parameters:** <!-- Specific values, request payloads, etc. -->
- **Actual Behavior:** <!-- What happened -->
- **Expected Behavior:** <!-- What should have happened -->
- **Evidence:** <!-- Logs, screenshots, stack traces, request/response samples -->

## 3. Trace

- **Scenario Path:** <!-- Which system scenario map was matched? -->
- **Suspect Module Chain:** <!-- Module A → Module B → Module C -->
- **Workflow Trace:** <!-- Which workflow steps were hit? Where did it deviate? -->
- **Dataflow Trace:** <!-- Which data transformations occurred? Where did data corrupt? -->
- **Code Path:** <!-- Specific files and functions involved -->

## 4. Root Cause

- **Which hop failed:** <!-- e.g., "Module B → Module C handoff" -->
- **Why it failed:** <!-- Technical explanation -->
- **Contract/Invariant violated:** <!-- Which specific contract or invariant was broken -->
- **Defect type:** single-point | pattern

## 5. Fix Scope

- **Recommended changes:** <!-- Files, functions, logic to modify -->
- **Verification targets:** <!-- What must be verified after fix -->
- **Truth updates required:** <!-- Do any maps, contracts, or invariants need updating? -->

## 6. Promotion

- **Decision:** not_promoted | promoted
- **Reason:** <!-- Why this is/isn't a systemic pattern -->
- **Impact scope:** <!-- If promoted: what other modules/scenarios are affected? -->
- **Bug class:** <!-- If promoted: reference to BUG_CLASS_REGISTER entry -->
