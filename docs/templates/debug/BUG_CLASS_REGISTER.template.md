# BUG_CLASS_REGISTER

**Status:** proposed
**Owner:** Debug Agent
**Last Updated:** YYYY-MM-DD

---

## 1. Purpose

Long-term registry of systemic bug classes. Not every bug enters here — only those promoted by the Debug Agent as patterns that the system should prevent from recurring.

## 2. Registry Rules

1. Only the Debug Agent may add entries (via promotion decision in a DEBUG_CASE)
2. Each entry must cite the originating DEBUG_CASE
3. Each entry must link to at least one RECURRENCE_PREVENTION_RULE
4. Status: `active` | `superseded` | `historical`

## 3. Registry

### BC-001: [Bug Class Name]

- **Status:** active
- **Originating Case:** <!-- Link to DEBUG_CASE -->
- **Pattern:** <!-- What makes this a class, not a single incident? -->
- **Affected Modules:** <!-- Which modules are susceptible? -->
- **Root Cause Pattern:** <!-- The systemic cause, not just one instance -->
- **Prevention Rule:** <!-- Link to RECURRENCE_PREVENTION_RULES entry -->
- **Detection Signal:** <!-- How to detect this class early -->
- **Date Registered:** YYYY-MM-DD

<!-- Add more entries as bugs are promoted -->
