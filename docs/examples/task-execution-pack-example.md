# TASK_EXECUTION_PACK: fix-provider-max-tokens

**Status:** completed
**Owner:** Implementation Agent
**Date:** 2026-03-19
**Module:** style-generation
**Upstream Artifacts:**
- `docs/agents/modules/style-generation/MODULE_CONTRACT.md` §4.3
- `docs/agents/debug/cases/2026-03-19-api-provider-max-tokens.md`

---

## 1. Task Summary

Fix the Gemini provider's default `maxOutputTokens` limit (8192) that truncates complex form style generation responses. Add explicit token limit configuration and truncation detection with retry logic.

## 2. Scope

### In Scope
1. Set explicit `maxOutputTokens: 16384` in the Gemini provider configuration
2. Add `finishReason` check after API response — detect `MAX_TOKENS` truncation
3. Implement single retry with doubled token limit when truncation detected
4. Add diagnostic logging for truncation events

### Out of Scope
1. Changing other AI providers (OpenAI, Claude) — separate task if needed
2. Restructuring the prompt to reduce output size — optimization, not a fix
3. Changing the JSON response schema

## 3. Contract Alignment

- CONTRACT §4.3: "Module must handle provider-specific token limits" — this fix directly addresses the gap
- INVARIANT INV-003 (fail-closed): truncation is now detected and fails gracefully instead of silently producing invalid JSON

## 4. Implementation Steps

1. `lib/ai/gemini-provider.ts#L45-L60` — add `maxOutputTokens: 16384` to the generation config
2. `lib/ai/gemini-provider.ts#L80-L95` — add `finishReason` check after response
3. `lib/ai/gemini-provider.ts#L100-L120` — implement retry logic: if `MAX_TOKENS`, retry once with `maxOutputTokens: 32768`
4. `lib/ai/gemini-provider.ts#L125-L135` — add diagnostic log: `[ai-provider] MAX_TOKENS truncation detected, retrying with limit=${newLimit}`
5. `lib/ai/gemini-provider.test.ts` — add test: mock truncated response → verify retry → verify final success or fail-closed

## 5. Verification Targets

1. Generate style for the complex 15-field form → complete JSON response
2. Server log shows `finishReason: STOP` (not `MAX_TOKENS`)
3. Mock test: truncated first attempt → retry → success
4. Mock test: truncated both attempts → fail-closed with diagnostic log

## 6. Risk Assessment

- **Risk:** doubled token limit increases API cost per request → **Mitigation:** only applies to retries, not default calls; log frequency for monitoring
- **Risk:** retry adds latency (~3-5 seconds) → **Mitigation:** acceptable for generation tasks that already take 10-15 seconds

## 7. Required Truth Updates

- [x] Module canonical workflow CW-4: add MAX_TOKENS failure mode note
- [x] Regression matrix: add RG-003 "Provider Output Token Limit Truncation"
- [ ] System scenario map: no change needed (failure point already documented)
