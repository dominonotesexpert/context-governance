---
artifact_type: system-invariants
status: active
owner_role: system-architect
scope: system
downstream_consumers: [module-architect, implementation, verification, debug]
last_reviewed: 2026-03-20
---

# SYSTEM_INVARIANTS

**Status:** active

## 1. Purpose
Hard rules that no agent, no document, no code change may violate.

## 2. Invariants

### INV-001: Fail-Closed Authentication
All authentication checks must fail-closed. If the auth service is unavailable or returns an ambiguous response, deny access.

### INV-002: Input Validation at Boundaries
All external input (API requests, WebSocket messages) must be validated before processing. No raw user input reaches business logic.

### INV-003: Code is Evidence, Not Truth
When code contradicts docs/agents/ artifacts, the artifacts are authoritative. Code shows what IS, not what SHOULD BE.

### INV-004: Downstream Never Rewrites Upstream
If implementation discovers a contract gap, escalate to Module Architect. Do not silently "fix" the truth in code.
