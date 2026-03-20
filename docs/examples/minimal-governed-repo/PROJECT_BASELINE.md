---
artifact_type: project-baseline
status: active
owner_role: user
scope: system
downstream_consumers: [system-architect]
authority_tier: 0
---

# PROJECT_BASELINE

**Status:** active
**Owner:** User
**Last Updated:** 2026-03-20

## 1. Product Definition

TaskManager is a task management tool for small teams. It lets people create, organize, and track tasks together in real time.

## 2. Target Users

Small teams (2-15 people) who need a simple way to coordinate work. They want something lighter than Jira but more structured than a shared spreadsheet.

## 3. Core Capabilities

1. Users can create, edit, delete, and assign tasks
2. Multiple people can see each other's changes in real time
3. Administrators can create workspaces and manage who has access
4. Users can organize tasks with labels, due dates, and priorities

## 4. Business Rules (Non-Negotiable)

- User data must never be lost — shut the service down rather than lose or corrupt data
- People without permission must never see or modify other people's content
- When something goes wrong, tell the user clearly — don't pretend nothing happened
- Every action that changes data must be traceable to who did it and when

## 5. Success Criteria

- Users see their task list within 2 seconds of opening the page
- One person's edit shows up on collaborators' screens within 1 second
- A new user can create their first task within 5 minutes without reading a manual
- The system stays usable even when one backend component is temporarily down

## 6. Explicitly Out of Scope

- No project management features (Gantt charts, milestones, resource allocation)
- No instant messaging or chat
- No file storage or document editing
- No billing or payment processing
