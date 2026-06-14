# Skills

This directory is the repository-neutral source for local agent skills.

Each skill lives in `.skills/<skill-name>/SKILL.md`. Agent-specific adapters should keep only the minimum wrapper needed by that agent and point back to this canonical file.

Current adapter:

- Codex: `.codex/skills/<skill-name>/SKILL.md` contains `@../../../.skills/<skill-name>/SKILL.md`.

Planned adapters:

- Generic agents: `.agents/`
- Claude: `.claude/`
