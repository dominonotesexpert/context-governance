---
artifact_type: optimization-log
status: proposed
owner_role: autoresearch
scope: system
downstream_consumers: [system-architect]
last_reviewed: YYYY-MM-DD
---

# OPTIMIZATION_LOG

**Status:** proposed
**Owner:** Verification Agent (autoresearch process)
**Last Updated:** YYYY-MM-DD

> Records every optimization attempt: what was changed, why, and whether it helped or was reverted.
> This is the audit trail for all SKILL.md and template modifications made by the autoresearch loop.

---

## 1. Optimization Rounds

### Round 001

- **Date:** YYYY-MM-DD
- **Target:** <!-- file modified, e.g., .claude/skills/verification/SKILL.md -->
- **Trigger:** <!-- what failure triggered this optimization, e.g., "GM-E1 not passing" -->
- **Change Description:** <!-- specific modification made -->
- **Rationale:** <!-- why this change was expected to help -->
- **Before:** <!-- list of check items that were not passing before this change -->
- **After:** <!-- pass/fail status of each check item after this change -->
- **Regressions:** <!-- any previously passing items that now fail — if any, must revert -->
- **Decision:** kept | reverted
- **Backup:** <!-- path to backup file, e.g., docs/agents/optimization/backups/verification-SKILL.001.backup.md -->

<!-- Add more rounds as the optimization loop runs -->

## 2. Regression Case Registry

<!-- Every failure fixed by optimization is added here. These must continue passing in all future rounds. -->

| Case ID | Description | Fixed In Round | Check Items |
|---------|------------|---------------|-------------|
| <!-- RC-001 --> | <!-- e.g., "Verification report missing file path evidence" --> | <!-- Round 001 --> | <!-- GM-E1 --> |

## 3. Summary

- Total rounds: 0
- Changes kept: 0
- Changes reverted: 0
- Current regression cases: 0
- Outstanding failures: (list check items still not passing)
