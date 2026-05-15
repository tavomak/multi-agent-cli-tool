# setup-agents

CLI tool that creates a single source of truth for AI documentation across any project.
One file (`AGENTS.md`) — every AI tool reads it automatically.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/tavomak/multi-agent-cli-tool/main/install.sh | sh
```

## What it creates

```
your-project/
├── AGENTS.md                              ← edit only this file
├── .agents/
│   ├── pending-work.md                    ← task tracking (AI reads every session)
│   ├── mcps.md                            ← MCP servers + skills registry
│   └── (your reference .md files)
├── .claude/
│   └── CLAUDE.md → ../AGENTS.md          ← symlink (Claude Code auto-loads)
├── .cursorrules → AGENTS.md              ← symlink (Cursor, with --all)
├── .windsurfrules → AGENTS.md            ← symlink (Windsurf, with --all)
├── .github/copilot-instructions.md → ..  ← symlink (Copilot, with --all)
└── .zed/rules.md → ../AGENTS.md          ← symlink (Zed, with --all)
```

| Tool | Reads | How |
|------|-------|-----|
| Claude Code | `.claude/CLAUDE.md` | symlink → AGENTS.md (auto-loaded) |
| OpenCode | `AGENTS.md` | native (auto-loaded) |
| Cursor | `.cursorrules` | symlink → AGENTS.md (auto-loaded) |
| Windsurf | `.windsurfrules` | symlink → AGENTS.md (auto-loaded) |
| GitHub Copilot | `.github/copilot-instructions.md` | symlink → AGENTS.md |
| Zed | `.zed/rules.md` | symlink → AGENTS.md |
| Codex, others | `AGENTS.md` | reference manually at session start |

## Usage

```bash
# Set up a project (current directory)
setup-agents init

# Set up with a starter template
setup-agents init --template node
setup-agents init --template python

# Set up + create all adapter symlinks
setup-agents init --all

# Set up a specific project path
setup-agents init ~/projects/myapp --template node

# Add adapters later
setup-agents add cursor
setup-agents add --all

# Check current setup state + validate AGENTS.md
setup-agents status

# Migrate existing .claude/ subdirectories to .agents/
setup-agents migrate
setup-agents migrate --yes        # use defaults, no prompts
setup-agents migrate --dry-run    # preview only

# Reverse init (remove symlinks, restore plain files)
setup-agents undo

# Self-upgrade to latest version
setup-agents update

# List available templates
setup-agents templates
```

## Session tracking

Every project gets `.agents/pending-work.md` — a shared task tracker that every AI tool reads at session start and updates when work completes.

```markdown
## Pending

| Priority | Action | Detail |
|----------|--------|--------|
| 🔴 High  | Audit active plugins | Check for vulnerabilities, unused plugins |
| ~~🟡 Medium~~ | ~~Add rate limiting~~ | ✅ Applied 22 Apr — burst 20→10 |

## Changelog

| # | Change | Date |
|---|--------|------|
| 1 | Added rate limiting | 22 Apr 2026 |
```

The session protocol in `AGENTS.md` tells the AI what to do:
- **Auto-loading tools** (Claude Code, Cursor, Windsurf, Zed): loads automatically
- **Manual tools** (OpenCode, Codex): paste `Read AGENTS.md and .agents/pending-work.md before we begin.` at session start

## Templates

| Name | Use for |
|------|---------|
| `default` | Any project — blank slate |
| `node` | Node.js / TypeScript |
| `python` | Python (ruff, pytest, mypy) |

```bash
setup-agents templates    # list all
```

## Migrating from .claude/

If you have an existing Claude Code project with `.claude/CLAUDE.md` and reference files:

```bash
setup-agents init     # moves .md files to .agents/, converts CLAUDE.md to symlink
setup-agents migrate  # handles subdirectories (commands/, specs/, etc.)
```

## Idempotent

Safe to run multiple times — skips any step already completed.
