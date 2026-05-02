Manual setup: single source of truth for AI docs

Prerequisites

Any project where you want multiple AI tools to read same instructions.

---

Step 1 — Create .agents/ folder and move reference files

mkdir .agents
mv .claude/server-reference.md .agents/
mv .claude/security-status.md .agents/
mv .claude/infrastructure-status.md .agents/
mv .claude/pending-work.md .agents/

---

Step 2 — Create AGENTS.md at project root

Copy content from .claude/CLAUDE.md → AGENTS.md. Update any paths that pointed to .claude/ files:

# Before

`server-reference.md`

# After

`.agents/server-reference.md`

---

Step 3 — Replace CLAUDE.md with symlink

rm .claude/CLAUDE.md
ln -s ../AGENTS.md .claude/CLAUDE.md

Verify:
ls -la .claude/CLAUDE.md

# Should show: .claude/CLAUDE.md -> ../AGENTS.md

---

Step 4 — Add other tool adapters (when needed)

# Cursor

ln -s AGENTS.md .cursorrules

# Windsurf

ln -s AGENTS.md .windsurfrules

# GitHub Copilot

mkdir -p .github
ln -s ../AGENTS.md .github/copilot-instructions.md

---

Rule going forward

Only edit AGENTS.md. Never edit .claude/CLAUDE.md directly — it's a symlink, changes go to AGENTS.md anyway. Reference files live in .agents/.
