# Adapters — Porting notebooklm-skill to other AI assistants

The CLI setup (Layer 1) works the same everywhere. What changes between platforms
is how you deliver the instructions to your AI assistant (Layer 2).

This document explains the differences and how to create an adapter for any platform.

---

## How skills work on each platform

### Claude Code

Skills are `.md` files placed in `~/.claude/skills/`. They use YAML frontmatter
to declare a name, description, and trigger conditions. Claude Code loads them
automatically and activates them on `/skill-name` or matching intent.

```yaml
---
name: notebooklm
description: Activates on /notebooklm or intent like "create a podcast"
---
# Instructions in markdown...
```

### Cursor

Cursor uses "Rules" — `.mdc` files in `.cursor/rules/` (per project) or a global
rules directory. The frontmatter is different: it uses `description`,
`alwaysApply`, and optional `globs` for file matching. No trigger syntax —
rules are applied via context or by mentioning `@rule-name` in chat.

```yaml
---
description: NotebookLM integration for this project
alwaysApply: false
---
# Instructions in markdown...
```

### OpenAI Codex

Codex supports the same `/skill-name` trigger system as Claude Code. When you
type `/` in the Codex chat input, a skill picker appears showing all installed
skills with their name and description — identical UX to Claude Code.

Skills have two scopes:
- **Personal** — available across all projects, stored in `~/.codex/skills/`
- **Project** — scoped to one project (likely stored in the project directory)

The adapter files at `adapters/codex/` use the same YAML frontmatter format
(`name`, `description`) as Claude Code skills, since Codex appears to share
or closely mirror the same skill format.

Codex also supports `@filename` to reference files in chat, and reads
`AGENTS.md` from the project root as project-level context (equivalent to
`CLAUDE.md` in Claude Code).

Codex executes commands locally ("Trabajar localmente" mode), so all bash
commands in the adapter run on the user's machine with full file system access.

### GitHub Copilot

Copilot supports custom instructions via `.github/copilot-instructions.md` in
the repository. There is no trigger system — instructions are always active.
Paste the contents of `skills/notebooklm.md` (minus the YAML frontmatter) into
that file.

Limitation: Copilot's bash access varies by editor and configuration. The CLI
commands will work if Copilot can invoke terminal commands.

### Any other agent

If your agent can:
1. Read a markdown file as instructions
2. Run bash commands

Then you can use the skills directly. Strip the YAML frontmatter and paste the
markdown content as a system prompt, custom instruction, or workspace rule.

---

## What to change when porting

| Element | Claude Code | Cursor | OpenAI Codex | Generic |
|---|---|---|---|---|
| File extension | `.md` | `.mdc` | `.md` | any |
| Skills directory | `~/.claude/skills/` | `.cursor/rules/` | `~/.codex/skills/` | depends |
| Invocation | `/skill-name` | `@rule-name` in chat | `/skill-name` | depends |
| Frontmatter `name` | required | not used | required | remove |
| Frontmatter `description` | for picker | for context | for picker | optional |
| Frontmatter `alwaysApply` | not used | optional | not used | remove |
| Project context file | `CLAUDE.md` | `.cursor/rules/` | `AGENTS.md` | — |
| Memory system | `MEMORY.md` (native) | manual via rules | manual via `AGENTS.md` | remove or adapt |
| Bash execution | via Bash tool | via terminal | local (full access) | depends |
| Tool call refs (Read, Write) | native | remove | remove | remove |

The bash commands, config file structure, and CLI invocations are identical
across all platforms.

---

## Creating a new adapter

1. Copy `skills/notebooklm.md` to `adapters/<platform>/notebooklm.<ext>`
2. Update the frontmatter to match the platform's format
3. Replace `/notebooklm` trigger references with the platform's equivalent
4. Replace MEMORY.md references with the platform's memory/context system
5. Remove or adapt any Claude-specific tool call references (Read, Write, etc.)
6. Test and open a PR

Name your directory after the platform slug: `cursor`, `copilot`, `codex`, `windsurf`, etc.
