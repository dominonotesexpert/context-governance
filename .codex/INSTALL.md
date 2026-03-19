# Installing Context Governance for Codex

## Prerequisites

- Git
- OpenAI Codex CLI installed (`npm i -g @openai/codex`)

## Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/anthropics/context-governance.git ~/.codex/context-governance
   ```

2. **Create the skills symlink:**
   ```bash
   mkdir -p ~/.agents/skills
   ln -s ~/.codex/context-governance/.claude/skills ~/.agents/skills/context-governance
   ```

   **Windows (PowerShell):**
   ```powershell
   New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.agents\skills"
   cmd /c mklink /J "$env:USERPROFILE\.agents\skills\context-governance" "$env:USERPROFILE\.codex\context-governance\.claude\skills"
   ```

3. **Restart Codex** to discover the skills.

## Bootstrap Your Project

Copy artifact templates into your project:

```bash
cp -r ~/.codex/context-governance/docs/templates/ your-project/docs/agents/
```

Then instantiate the templates into active `docs/agents/` filenames starting with `SYSTEM_GOAL_PACK.md`.

Project bootstrap example:

```bash
bash scripts/bootstrap-project.sh --target your-project --platform codex
```

## Verify

```bash
ls -la ~/.agents/skills/context-governance
```

You should see a symlink pointing to the context-governance skills directory containing:
- `system-architect/SKILL.md`
- `module-architect/SKILL.md`
- `debug/SKILL.md`
- `implementation/SKILL.md`
- `verification/SKILL.md`
- `frontend-specialist/SKILL.md`

## Updating

```bash
cd ~/.codex/context-governance && git pull
```

Skills update instantly through the symlink.

## Uninstalling

```bash
rm ~/.agents/skills/context-governance
rm -rf ~/.codex/context-governance
```
