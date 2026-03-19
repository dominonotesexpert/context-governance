# Installing Context Governance for Gemini CLI

## Prerequisites

- Git
- Gemini CLI installed

## Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/anthropics/context-governance.git ~/.gemini/context-governance
   ```

2. **Create skill symlinks:**
   ```bash
   mkdir -p ~/.gemini/skills
   for skill in system-architect module-architect debug implementation verification frontend-specialist; do
     ln -s ~/.gemini/context-governance/.claude/skills/$skill ~/.gemini/skills/cg-$skill
   done
   ```

3. **Restart Gemini CLI** to discover the skills.

## Project-Level Installation

Alternatively, copy skills directly into your project:

```bash
mkdir -p your-project/.gemini/skills
cp -r ~/.gemini/context-governance/.claude/skills/* your-project/.gemini/skills/
```

## Bootstrap Your Project

Copy artifact templates into your project:

```bash
cp -r ~/.gemini/context-governance/docs/templates/ your-project/docs/agents/
```

Then instantiate the templates into active `docs/agents/` filenames starting with `SYSTEM_GOAL_PACK.md`.

Project bootstrap example:

```bash
bash scripts/bootstrap-project.sh --target your-project --platform gemini
```

## Verify

```bash
ls -la ~/.gemini/skills/cg-*
```

## Updating

```bash
cd ~/.gemini/context-governance && git pull
```

## Uninstalling

```bash
for skill in system-architect module-architect debug implementation verification frontend-specialist; do
  rm ~/.gemini/skills/cg-$skill
done
rm -rf ~/.gemini/context-governance
```
