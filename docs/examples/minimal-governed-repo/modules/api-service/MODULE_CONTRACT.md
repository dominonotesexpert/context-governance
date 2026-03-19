---
artifact_type: module-contract
status: active
owner_role: module-architect
scope: module
module: api-service
downstream_consumers: [implementation, verification, debug]
last_reviewed: 2026-03-20
---

# MODULE_CONTRACT: api-service

**Status:** active

## 1. Responsibility
Handles all REST API endpoints for task CRUD, authentication, and team management. Owns request validation, business logic dispatch, and response formatting.

## 2. Boundaries
- Owns: HTTP request handling, input validation, response formatting, auth middleware
- Does NOT own: database schema migrations, WebSocket connections, frontend rendering
- Peer: websocket-service handles real-time sync

## 3. Inputs
- HTTP requests from frontend clients
- Auth tokens from identity provider
- Database query results from data layer

## 4. Outputs
- JSON API responses to frontend clients
- Validated command objects to data layer
- Auth context to downstream middleware

## 5. Upstream Dependencies
- identity-provider: provides auth token validation
- data-layer: provides persistence

## 6. Downstream Consumers
- frontend-client: consumes JSON API responses
- websocket-service: reads task state for real-time broadcast

## 7. Shared Interfaces
- TaskDTO: shared between api-service and websocket-service
- AuthContext: shared between api-service and all authenticated services

## 8. Invariants
- All endpoints validate input before processing (INV-002)
- Auth failures fail-closed (INV-001)
- Response format never exposes internal error details to clients

## 9. Breaking Change Policy
Changes to TaskDTO or AuthContext require notification to all downstream consumers. Changes to response format require frontend-client coordination.

## 10. Verification Expectations
- Input validation: test with malformed payloads
- Auth: test with expired/invalid/missing tokens
- Response format: test against API schema
- Error handling: test with database unavailable
