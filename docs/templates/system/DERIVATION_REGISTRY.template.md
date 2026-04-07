---
artifact_type: derivation-registry
status: proposed
owner_role: system-architect
scope: system
downstream_consumers: [system-architect]
last_reviewed: YYYY-MM-DD
---

# DERIVATION_REGISTRY

**Status:** proposed
**Owner:** System Architect
**Last Updated:** YYYY-MM-DD

> This is a system-level registry tracking the last-known-good derivation state for each derived document.
> It is a meta-artifact — it does not participate in the authority tier hierarchy.
> Updated by System Architect after each successful derivation + verification cycle.

---

## 1. Purpose

When re-derivation produces unexpected changes, this registry provides a comparison baseline and rollback path. Each entry records the derivation context and git commit of the last verified-good version of a derived document.

## 2. Registry

| Document | Last Verified Good Version | derivation_context | git commit | Verification Date |
|----------|--------------------------|-------------------|------------|-------------------|
| SYSTEM_GOAL_PACK.md | — | — | — | — |
| SYSTEM_INVARIANTS.md | — | — | — | — |
| MODULE_CONTRACT.md | — | — | — | — |
| ACCEPTANCE_RULES.md | — | — | — | — |
| VERIFICATION_ORACLE.md | — | — | — | — |
| SYSTEM_ARCHITECTURE.md | — | — | — | — |

## 3. Update Protocol

1. System Architect completes a derivation cycle for a document
2. Verification Agent confirms the derived document satisfies upstream contracts
3. System Architect updates the corresponding row in this registry:
   - Copy `derivation_context` from the verified document's frontmatter
   - Record the current git commit hash
   - Set Verification Date to today
4. If a future re-derivation is rejected, the `git commit` column provides the rollback target

## 4. Rules

1. This registry is append-only for new documents, update-in-place for existing entries
2. Only System Architect may update this registry
3. Entries are never deleted — if a derived document is retired, mark its row as `retired`
4. This registry is NOT in the authority tier chain — it is operational metadata
