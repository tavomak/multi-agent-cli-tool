# setup-agents

CLI tool that creates a single source of truth for AI documentation across any project.
One file (`AGENTS.md`) — every AI tool reads it automatically.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/tavomak/multi-agent-cli-tool/main/install.sh | bash
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
| Cursor | `AGENTS.md` | native; `.cursorrules` symlink for older versions |
| Windsurf | `AGENTS.md` | native; `.windsurfrules` symlink for older versions |
| GitHub Copilot | `AGENTS.md` | native; `.github/copilot-instructions.md` symlink for older versions |
| Zed | `AGENTS.md` | native; `.zed/rules.md` symlink for older versions |
| Codex, others | `AGENTS.md` | native (auto-loaded) |

> Modern Cursor, Windsurf, Copilot, Zed, and Codex all read `AGENTS.md` natively — the adapter symlinks (`--all`, `add <adapter>`) are legacy shims for older releases.

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
# (exits non-zero on problems — usable in CI)
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
| `next` | Next.js (next/image, Tailwind, specs workflow) |
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

## Releases

Automated on push to `main` (conventional commits):

| Commit | Bump |
|--------|------|
| `feat!:` / `BREAKING CHANGE` | major |
| `feat:` | minor |
| `fix:` / `perf:` | patch |
| anything else | no release |

The workflow writes `VERSION=` into `setup-agents`, runs the test suite, commits, tags `vX.Y.Z`, and creates a GitHub release. Never bump `VERSION` by hand — `setup-agents update` reads it from `main`.
