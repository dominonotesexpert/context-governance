---
artifact_type: namespace-readme
status: proposed
owner_role: verification
scope: verification
downstream_consumers: [implementation, debug]
last_reviewed: 2026-03-20
---

# Verification Artifact Namespace

**Status:** active
**Owner:** Verification Agent
**Purpose:** Store verification governance artifacts for contract satisfaction evidence

---

## What Goes Here

1. `AGENT_SPEC.md` — Verification Agent role specification
2. `ACCEPTANCE_RULES.md` — Pass / pass-with-risk / fail / insufficient-evidence criteria
3. Per-module subdirectories containing:
   - `VERIFICATION_ORACLE.md` — Contract obligation to verification evidence mapping
   - `REGRESSION_MATRIX.md` — Known regressions and prevention checks
   - `VERIFICATION_BOOTSTRAP_PACK.md` — Module verification readiness tracking

## Directory Structure

```
docs/agents/verification/
├── README.md
├── AGENT_SPEC.md
├── ACCEPTANCE_RULES.md
├── <module-a>/
│   ├── VERIFICATION_ORACLE.md
│   ├── REGRESSION_MATRIX.md
│   └── VERIFICATION_BOOTSTRAP_PACK.md
└── <module-b>/
    └── ...
```

## Core Rule

**No completion without evidence.** Verification requires runtime proof, not just "code looks right."
