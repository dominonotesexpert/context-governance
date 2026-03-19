# Contributing

## Scope

This repository is a governance framework, not an app. Contributions should improve:

- role definitions
- template quality
- platform installation guidance
- bootstrap clarity
- contract consistency across docs

## Contribution Rules

1. Keep `README.md`, platform install docs, and template docs aligned.
2. Do not introduce platform-specific claims unless the repository actually ships the needed files.
3. Do not treat `.template.md` files as active truth artifacts.
4. Preserve the core governance model:
   - downstream consumes upstream
   - no fix without root cause
   - code is evidence, not truth
5. When changing role structure, update:
   - `README.md`
   - `CLAUDE.md`
   - platform install docs
   - relevant templates

## Pull Request Checklist

- README links resolve
- install instructions are copy-pasteable
- template-to-active filename mapping is still correct
- role names are consistent across files
- examples still match the documented framework

## Documentation Style

- Prefer concise, direct Markdown
- Use exact filenames and paths
- Distinguish clearly between templates and active artifacts
