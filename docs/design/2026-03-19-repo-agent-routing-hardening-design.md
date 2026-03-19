# Repository Agent Routing Hardening Design

**Date:** 2026-03-19
**Status:** Proposed
**Scope:** Strengthen the automatic task classification protocol to handle design tasks and mid-session task-type switches explicitly

---

## Goal

Harden repository entry rules into a more stable auto-classification protocol that prevents sessions from triggering only the outer skill gate without continuing into the `docs/agents/` role chain (System / Module / Debug / Implementation / Verification / Frontend).

## Problem

Current rules require automatic routing for repository tasks, but design-class tasks and mid-session task-type switches are not explicit enough. This leads to:

1. Outer skill gates trigger but repo agents do not continue starting
2. Design tasks remain in free discussion without entering `System -> Module`
3. Consecutive conversation turns incorrectly reuse old routing chains

## Decisions

### 1. Outer Skill Gate vs Repo Agents

Outer skills (brainstorming, writing-plans, etc.) handle method selection only — they do not count as repo agent activation. Once a repository task is established, it must continue into the `docs/agents/` role chain.

### 2. Design Task Default Route

The following tasks are classified as design tasks:

- New feature design
- Module design
- Architecture design
- Protocol design
- Design document authoring

Default route: `System -> Module -> Verification`

Add `Frontend Specialist` only when design involves UI / interaction / layout / a11y / perf. Enter `Implementation` only when the user explicitly requests it or the task transitions to code/implementation artifact modification.

### 3. Task-Type Switch Requires Rerouting

When the task type changes within a session, reroute from `System -> Module` using the user's latest instruction. Covered transitions include:

- review -> design
- design -> implementation
- implementation -> verification
- debug / RCA -> approved fix

Consecutive conversation turns do NOT justify reusing old agent state.

## Scope

This change only updates documentation and entry rules:

1. Platform entrypoint files
2. Agent routing tables
3. Bootstrap readiness docs

## Non-Goals

- No new sub-agent types
- No changes to `docs/agents/` directory structure
- No new runtime behavior or code paths

## Acceptance

Updated docs must satisfy:

1. Design task default route is explicitly stated
2. Task-type switch rerouting is mandatory
3. Outer skill gate is clearly distinguished from repo agent activation
