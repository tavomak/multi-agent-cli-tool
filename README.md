# setup-agents

CLI tool that sets up a single source of truth for AI documentation across any project.
Any AI tool (Claude Code, OpenCode, Cursor, Windsurf, Copilot) reads the same `AGENTS.md` file.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/tavomak/setup-agents/main/install.sh | sh
```

## Usage

```bash
# Run in current project
setup-agents init

# Run on a specific project
setup-agents init ~/projects/myapp

# Also create adapters for Cursor, Windsurf, Copilot
setup-agents init --all

# Add a single adapter later
setup-agents add cursor
setup-agents add windsurf
setup-agents add copilot
```

## What it creates

```
your-project/
├── AGENTS.md                    ← edit only this file
├── .agents/
│   └── (reference .md files)   ← moved from .claude/
└── .claude/
    └── CLAUDE.md → ../AGENTS.md ← symlink (Claude Code auto-loads)
```

| Tool | Reads | Via |
|------|-------|-----|
| Claude Code | `.claude/CLAUDE.md` | symlink |
| OpenCode | `AGENTS.md` | native |
| Cursor | `.cursorrules` | symlink (--all) |
| Windsurf | `.windsurfrules` | symlink (--all) |
| GitHub Copilot | `.github/copilot-instructions.md` | symlink (--all) |

## Idempotent

Safe to run multiple times — skips any step already completed.
