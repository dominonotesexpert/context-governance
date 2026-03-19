# Scenario: [scenario-name]

**Status:** proposed
**Owner:** System Architect Agent
**Last Updated:** YYYY-MM-DD

---

## 1. Scenario Name

<!-- Descriptive name for this end-to-end flow -->

## 2. Entry Trigger

<!-- What user action or system event starts this scenario? -->

## 3. Module Chain

<!-- Ordered list of modules this scenario passes through -->
<!-- Module A → Module B → Module C → Module D -->

### Code/Route Anchors

<!-- Key entry points with file paths -->
<!-- - `path/to/file.ts` — description -->

## 4. Cross-Module Hops

<!-- Where does data/control pass between modules? -->

| # | From | To | Mechanism | Data Transferred |
|---|------|----|-----------|-----------------|
| 1 | <!-- Module A --> | <!-- Module B --> | <!-- API call / event / direct import --> | <!-- what data --> |

## 5. Failure Points

<!-- Known failure modes at each stage -->

| # | Location | Failure Mode | Impact | Severity |
|---|----------|-------------|--------|----------|
| 1 | <!-- Module A output --> | <!-- e.g., timeout, invalid response --> | <!-- what breaks downstream --> | high |

## 6. Drilldown Links

### Module Truth (read first)
<!-- - Module A: `docs/agents/modules/<module-a>/MODULE_CONTRACT.md` -->
<!-- - Module B: `docs/agents/modules/<module-b>/MODULE_CANONICAL_WORKFLOW.md` -->

### Code Anchors (read second)
<!-- - `path/to/key-file.ts#L100-L200` — description -->

## 7. Update Rules

This scenario map must be updated when:
1. A new module is added to the chain
2. A cross-module hop mechanism changes
3. A new failure mode is discovered
4. Module boundaries shift
