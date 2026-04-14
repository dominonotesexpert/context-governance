# Context Governance — Hermes Agent Adapter

Integrates Context Governance as a governance layer running on Hermes Agent infrastructure.

**Relationship:** Hermes provides runtime (memory, MCP, scheduling, messaging). CG provides governance semantics (authority hierarchy, role routing, contract enforcement, verification).

## Prerequisites

- [Hermes Agent](https://github.com/NousResearch/hermes-agent) v0.8.0+
- Python 3.8+ (for governance MCP server)
- `mcp>=1.0.0` Python package (`pip install mcp`)
- A project already bootstrapped with Context Governance

## Quick Start

### 1. Bootstrap your project with Hermes support

```bash
bash scripts/bootstrap-project.sh \
  --target /path/to/your/project \
  --platform hermes \
  --adapter hermes
```

This creates:
- `HERMES.md` — governance routing instructions for Hermes sessions
- `adapters/hermes/config.yaml.template` — MCP server registration
- `adapters/hermes/cron-jobs.yaml.template` — scheduled governance checks
- `adapters/hermes/notifications.yaml.template` — notification configuration
- `.hermes/skills/governance-check/SKILL.md` — governance compliance skill

### 2. Register the MCP server

Add the governance MCP server to your Hermes config (`~/.hermes/config.yaml`):

```yaml
mcp_servers:
  context-governance:
    type: stdio
    command: python3
    args:
      - governance-mcp-server/server.py
```

Hermes will auto-discover all 9 governance tools at startup.

### 3. Install governance skills

```bash
cp -r adapters/hermes/skills/governance-check ~/.hermes/skills/cg-governance-check
```

### 4. Set up cron jobs (optional)

```bash
# Governance consistency check every 4 hours
hermes cron add "every 4 hours" "Run governance_run_checks via MCP. Report pass/fail. Do NOT modify files."

# Escalation monitor every 2 hours
hermes cron add "every 2 hours" "Check .governance/escalations.jsonl for unresolved escalations. Report any older than 24 hours as urgent."

# Daily staleness detection
hermes cron add "every day at 8am" "Run bash scripts/check-staleness.sh. Report stale documents."
```

See `cron-jobs.yaml.template` for full job definitions.

### 5. Configure notifications (optional)

Edit `adapters/hermes/notifications.yaml.template` and configure your preferred platform (Slack, Telegram, Discord, webhook).

## Available MCP Tools

Once registered, Hermes has access to these governance tools:

| Tool | Purpose |
|------|---------|
| `governance_start_task` | Create a new governed task with receipt |
| `governance_update_receipt` | Update receipt claims and scope |
| `governance_record_debug_case` | Attach debug case evidence |
| `governance_record_escalation` | Record escalation (blocks commits) |
| `governance_record_verification` | Attach verification evidence |
| `governance_complete_task` | Finalize receipt and update index |
| `governance_start_autoresearch` | Begin autoresearch optimization |
| `governance_record_optimization` | Record optimization round results |
| `governance_run_checks` | Run full governance check suite |

## Design Principles

1. **Memory is context, documents are truth.** Hermes persistent memory supplements governance but never replaces artifact loading.
2. **Cron jobs are read-only.** Scheduled checks report via notifications; they never modify governance artifacts.
3. **CG can run without Hermes.** The Hermes adapter is an optional enhancement. Removing it has zero impact on governance.
4. **No self-evolution of governance.** Hermes self-improvement must not touch `docs/agents/`, `.governance/`, or governance scripts.

## Dual-Platform Support

You can use CG with both Claude Code and Hermes simultaneously on the same project:

```bash
# Bootstrap for Claude Code (primary)
bash scripts/bootstrap-project.sh --target /your/project --platform claude --adapter claude-code

# Add Hermes support (additive)
bash scripts/bootstrap-project.sh --target /your/project --platform hermes --adapter hermes --force
```

Both platforms share the same `.governance/` directory and `docs/agents/` namespace.

## Troubleshooting

**MCP server not discovered:**
- Ensure `governance-mcp-server/server.py` path is correct relative to project root
- Check: `python3 -c "import mcp"` — install with `pip install mcp` if missing
- Verify `.governance/` directory exists at project root

**Cron jobs not running:**
- Check Hermes gateway is running: `hermes gateway status`
- Verify jobs: `hermes cron list`

**Notifications not sending:**
- Verify platform adapter is configured in `~/.hermes/config.yaml`
- Check gateway logs for connection errors
