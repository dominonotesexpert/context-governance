# DEBUG_CASE: 2026-03-19-api-provider-max-tokens

**Status:** closed
**Owner:** Debug Agent
**Date:** 2026-03-19
**Severity:** high

---

## 1. Metadata

- **Trigger:** User clicks "Generate Style" button, API returns incomplete result
- **Environment:** Development server, Gemini API provider, form with 15+ fields
- **Reported By:** Product owner via screenshot

## 2. Reproduction Summary

- **Steps to Reproduce:**
  1. Open the style generation page for a complex form (15+ fields)
  2. Click "Generate Style"
  3. Wait for API response
- **Input / Parameters:** Full form DXL with 15 fields, 10 action buttons, embedded tables
- **Actual Behavior:** API returns `finishReason: MAX_TOKENS` — response is truncated JSON, validation fails, no style generated
- **Expected Behavior:** API returns complete JSON response, style is generated and previewed
- **Evidence:** Server log: `[ai-provider] Gemini response finishReason=MAX_TOKENS, output truncated at 8192 tokens`

## 3. Trace

- **Scenario Path:** `step2-step3-style-generation-deploy`
- **Suspect Module Chain:** style-generation (prompt assembly → API call → response parse)
- **Workflow Trace:**
  - CW-1 (intake): OK — form data received correctly
  - CW-3 (prompt assembly): OK — prompt built with all fields
  - CW-4 (provider call): FAIL — response truncated due to MAX_TOKENS
  - CW-5 (parse/validate): FAIL — JSON parse fails on truncated output
- **Dataflow Trace:**
  - CD-3 (prompt → provider): prompt size = ~4000 tokens, but response needs ~10000 tokens for full JSON
  - CD-4 (provider → parsed result): truncated at 8192 output tokens
- **Code Path:** `app/api/ai/generate-style/route.ts` → `lib/ai/gemini-provider.ts` → response handler

## 4. Root Cause

- **Which hop failed:** CW-4 (provider generation) — Gemini API `maxOutputTokens` defaulted to 8192
- **Why it failed:** The route handler did not set `maxOutputTokens` explicitly. Gemini's default (8192) is insufficient for complex forms that generate large JSON responses.
- **Contract violated:** MODULE_CONTRACT §4.3 — "Module must handle provider-specific token limits and retry or escalate when output is truncated"
- **Defect type:** pattern — any complex form with >8192 token response will hit this

## 5. Fix Scope

- **Recommended changes:**
  - Set `maxOutputTokens: 16384` explicitly in the Gemini provider call
  - Add `finishReason` check in the response handler — if `MAX_TOKENS`, log a diagnostic and retry with higher limit before failing
- **Verification targets:**
  - Generate style for the complex form → response should be complete JSON
  - Check that `finishReason` is `STOP` (not `MAX_TOKENS`)
  - Verify the retry logic with a mock truncated response
- **Truth updates required:**
  - Update `MODULE_CANONICAL_WORKFLOW.md` CW-4 to note the MAX_TOKENS failure mode
  - Add to `REGRESSION_MATRIX.md` as a new regression class

## 6. Promotion

- **Decision:** promoted
- **Reason:** This is a systemic pattern — any provider with default token limits will truncate complex form outputs. The same bug class can occur with OpenAI (4096 default) or Claude (depending on config). It's not a single-point defect but a class of "provider output limit" bugs.
- **Impact scope:** All AI provider integrations that generate structured JSON output
- **Bug class:** BC-001: Provider Output Token Limit Truncation
