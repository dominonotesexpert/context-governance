---
artifact_type: project-baseline
status: proposed
owner_role: user
scope: system
downstream_consumers: [system-architect]
last_reviewed: YYYY-MM-DD
authority_tier: 0
---

# PROJECT_BASELINE

**Status:** proposed
**Owner:** User (this is the only document the user writes directly)
**Last Updated:** YYYY-MM-DD

> This is the root of all truth in the governance system.
> All other documents are derived from this one.
> Write in plain business language. No technical terms.
> Keep it under 100 lines.
> This is NOT a PRD. Do not include technical implementation details.
> When business meaning is ambiguous, clarifications are recorded in BASELINE_INTERPRETATION_LOG — not here.

---

## 1. Product Definition

<!-- One paragraph: what is this product? What problem does it solve? -->

## 2. Target Users

<!-- Who uses this product? What is their most important need? -->

## 3. Core Capabilities

<!-- Capabilities the product must have, listed by priority. One sentence each. -->
<!-- Example: -->
<!-- 1. Users can create, edit, and delete tasks -->
<!-- 2. Multiple people can collaborate in the same workspace in real time -->
<!-- 3. Administrators can assign roles and permissions -->

## 4. Business Rules (Non-Negotiable)

<!-- Rules that must never be violated. Use everyday language, no technical terms. -->
<!-- Example: -->
<!-- - User data must never be lost — shut the service down rather than lose data -->
<!-- - People without permission must never see other people's content -->
<!-- - When the system fails, tell the user what went wrong — don't pretend nothing happened -->

## 5. Success Criteria

<!-- How do you know it's working well? Use observable outcomes, not vague adjectives. -->
<!-- Example: -->
<!-- - Users see their task list within 2 seconds of opening the page -->
<!-- - One person's edit shows up on collaborators' screens within 1 second -->
<!-- - A new user can create their first task within 5 minutes without reading a manual -->

## 6. Explicitly Out of Scope

<!-- Product boundaries. What is this product NOT responsible for? -->
<!-- Example: -->
<!-- - No project management (Gantt charts, milestones, resource allocation) -->
<!-- - No instant messaging -->
