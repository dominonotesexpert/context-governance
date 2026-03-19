---
artifact_type: system-goal-pack
status: active
owner_role: system-architect
scope: system
downstream_consumers: [module-architect, implementation, verification, debug]
last_reviewed: 2026-03-20
---

# SYSTEM_GOAL_PACK

**Status:** active
**Owner:** System Architect Agent

## 1. Product Vision
TaskManager is a multi-user task management API with real-time collaboration. It serves frontend clients via REST and WebSocket.

## 2. Current Direction
Building v2 with team workspaces and role-based permissions. Core CRUD and real-time sync are stable.

## 3. Non-Negotiable Production Obligations
1. All API endpoints must validate input and return structured error responses
2. Authentication failures must fail-closed — deny access, never grant on ambiguity
3. Data mutations must be idempotent where possible
4. WebSocket connections must handle disconnection gracefully

## 4. Failure Philosophy
Correctness over availability. A 503 is better than corrupted data. Graceful degradation means read-only mode, not silent data loss.

## 5. Downstream Role Preconditions
Before any implementation or verification work begins:
- This document must be status: active
- SYSTEM_INVARIANTS must be established
- At least one module contract must exist for the affected area
