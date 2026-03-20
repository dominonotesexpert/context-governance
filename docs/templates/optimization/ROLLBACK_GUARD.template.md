---
artifact_type: rollback-guard
status: proposed
owner_role: verification
scope: optimization
downstream_consumers: [system-architect]
last_reviewed: YYYY-MM-DD
---

# ROLLBACK_GUARD

**Status:** proposed
**Owner:** Autoresearch process
**Last Updated:** YYYY-MM-DD

> Ensures every optimization is reversible. Zero tolerance for regression.

---

## 1. Automatic Rollback Conditions

A modification is **immediately reverted** if ANY of the following is true:

1. **Regression detected:** Any check item that passed before the modification now fails
2. **Invariant violation:** Any SYSTEM_INVARIANTS-related check item fails after modification
3. **Fix ineffective:** The target failure that triggered the modification still fails after it
4. **Backup missing:** The backup file for this round cannot be found or read

No exceptions. No "the regression is minor" justification. Any regression = revert.

## 2. Rollback Procedure

```
Step 1: Identify the backup file
  Path: docs/agents/optimization/backups/{skill-name}-SKILL.{round}.backup.md

Step 2: Replace the modified file with the backup
  cp backup → original SKILL.md location

Step 3: Verify restoration
  - Diff the restored file against the backup — must be identical
  - Re-run the check items — previously passing items must still pass

Step 4: Record in OPTIMIZATION_LOG
  - Decision: reverted
  - Reason: which regression was detected / which condition triggered
  - Backup used: path
```

## 3. Manual Rollback

The user can request rollback to any previous version at any time:

```
Step 1: List available backups
  ls docs/agents/optimization/backups/{skill-name}-SKILL.*.backup.md

Step 2: User selects which version to restore

Step 3: Follow Steps 2-4 from Automatic Rollback Procedure

Step 4: Reset regression baseline
  After manual rollback, the current state becomes the new baseline.
  Previous optimization rounds after the restored version are invalidated.
```

## 4. Backup Retention

- Keep the **10 most recent** backups per skill
- When creating backup #11, delete the oldest
- Never delete a backup that is the **only remaining version** before a known-good state
- Completed optimization sessions: archive all backups with the OPTIMIZATION_LOG round data

## 5. Recovery From Corrupted State

If SKILL.md and all backups are somehow corrupted or lost:

1. Check git history: `git log --oneline -- .claude/skills/{skill-name}/SKILL.md`
2. Restore from the most recent commit where the skill was known to work
3. Re-run check items to verify the restored version passes
4. Record the incident in OPTIMIZATION_LOG with `Decision: emergency_restore`
5. The restored state becomes the new baseline for future optimization
