# Repository Semantic Router Design

**Date:** 2026-03-19
**Status:** Proposed
**Scope:** Upgrade repository task routing from trigger-phrase-driven to a semantic intent classification system

---

## Goal

Design a future-implementable semantic router that can classify multilingual repository tasks, detect task transitions, and map results stably into the `docs/agents/` role chain.

## Problem

Current routing relies on:

1. Outer skill gates
2. Rule-based task classification
3. Explicit trigger phrases

This is insufficient for multilingual input, ambiguous expressions, and mid-session task switches, leading to:

1. Outer gate triggers without repo agent chain activation
2. Design tasks incorrectly sink to implementation
3. Bug/debug tasks get absorbed by review or implementation
4. Same semantics in different languages produce different routes

## Design Summary

A **hybrid semantic router** with four layers:

### 1. Intent Classifier
- Input: user message + session context
- Output: unified `TaskIntent` schema

### 2. Task Transition Engine
- Compare active task with new intent
- Output: `reuse_current_route` / `reroute` / `ask_confirmation` / `exit_repo_protocol`

### 3. Repo Route Mapper
- Map unified intent schema to repo agent chain

### 4. Confirmation Gate
- Ask minimal confirmation on low-confidence or high-risk transitions

## Unified Intent Schema

```
TaskIntent:
  repoRelated: boolean
  languageHint: string
  primaryIntent: design | implementation | debug | review | verification | ui | general_non_repo
  secondaryIntents: [...]
  confidence: number
  evidence: [...]
  uiRelated: boolean
  routeDecision: reuse_current_route | reroute | ask_confirmation | exit_repo_protocol
```

## Confidence Policy

- `>= 0.80` — Auto-route
- `0.55 - 0.79` — Reuse if consistent with active task; confirm if entering Implementation or Debug
- `< 0.55` — Always confirm

## Route Mapping

| Intent | Route |
|--------|-------|
| design | System -> Module -> Verification |
| implementation | System -> Module -> Implementation -> Verification |
| debug | System -> Module -> Debug (then Implementation -> Verification after approval) |
| review | System -> Module -> Verification |
| verification | System -> Module -> Verification |
| general_non_repo | Exit repo protocol |

Modifiers:
- `uiRelated = true` — Add Frontend Specialist
- `debugRelated = true` — Increase debug/review conflict weight
- `moduleNotWarmBootstrapped = true` — Block implementation entry

## Failure Handling

Core principle: **May under-automate once; must not over-automate once.**

Must confirm before:
- Low confidence routing
- Design + implementation both score high
- Review + debug both score high without clear bug evidence
- Entering implementation without explicit signal
- Debug -> implementation without closure

## Multi-language Support

- Language detection is supplementary, not a routing factor
- All languages map to the same canonical intent ontology
- Trigger phrases serve as regression samples and confidence boosters only
- Unknown languages at low confidence get minimal confirmation, not failure

## Recommended Persistent Artifacts

To make the semantic router a long-term capability:

1. `docs/agents/system/ROUTING_POLICY.md`
2. Module contract for `repo-agent-routing`
3. Verification oracle for `repo-agent-routing`

## Verification Strategy

Four layers:

1. **Intent classification corpus** — Multilingual single-turn samples
2. **State transition matrix** — Multi-turn state switch sequences
3. **Route mapping oracle** — Route to `docs/agents` baseline mapping checks
4. **Transcript replay** — Real conversation history replay

## Artifact Layout

1. `docs/plans/agents/` — Agent system design documents and implementation plans
2. `docs/agents/` — Active truth / contract / oracle / bootstrap packs
3. `docs/agents/execution/` — Task-scoped execution document namespace
4. `docs/agents/task-checklists/` — Reusable task checklist namespace
