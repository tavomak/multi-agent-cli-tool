#!/usr/bin/env bash
# setup-agents.sh
# Sets up a single source of truth for multi-AI documentation.
#
# Result:
#   AGENTS.md              ← canonical file (edit this one)
#   .agents/               ← all reference .md files (moved from .claude/)
#   .claude/CLAUDE.md      ← symlink → ../AGENTS.md  (Claude Code)
#   .cursorrules           ← symlink → AGENTS.md     (Cursor, --all only)
#   .windsurfrules         ← symlink → AGENTS.md     (Windsurf, --all only)
#   .github/copilot-instructions.md ← symlink        (Copilot, --all only)
#
# Usage:
#   ./setup-agents.sh              # core setup only
#   ./setup-agents.sh --all        # core + all tool adapters

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; exit 1; }

ALL_ADAPTERS=false
[[ "${1:-}" == "--all" ]] && ALL_ADAPTERS=true

# must run from project root
[[ -d ".claude" ]] || fail "No .claude/ folder found. Run from project root."

# ── 1. create .agents/ ────────────────────────────────────────────────────────
if [[ -d ".agents" ]]; then
    warn ".agents/ already exists — skipping"
else
    mkdir .agents
    ok "Created .agents/"
fi

# ── 2. move all .md files from .claude/ (except CLAUDE.md) ───────────────────
moved=0
for f in .claude/*.md .claude/*.MD; do
    [[ -e "$f" ]] || continue                          # no match → skip
    [[ -L "$f" ]] && { warn "Skipping symlink: $f"; continue; }
    base="$(basename "$f")"
    [[ "$base" == "CLAUDE.md" || "$base" == "CLAUDE.MD" ]] && continue
    target=".agents/$base"
    if [[ -e "$target" ]]; then
        warn "$target already exists — skipping"
    else
        mv "$f" "$target"
        ok "Moved $f → $target"
        ((moved++)) || true
    fi
done
[[ $moved -eq 0 ]] && warn "No reference files moved (already done or none found)"

# ── 3. create AGENTS.md ───────────────────────────────────────────────────────
if [[ -e "AGENTS.md" && ! -L "AGENTS.md" ]]; then
    warn "AGENTS.md already exists — skipping (update paths manually if needed)"
elif [[ -L ".claude/CLAUDE.md" ]]; then
    warn ".claude/CLAUDE.md already a symlink — AGENTS.md step already done"
elif [[ -f ".claude/CLAUDE.md" ]]; then
    cp .claude/CLAUDE.md AGENTS.md
    ok "Created AGENTS.md from .claude/CLAUDE.md"
    warn "Review AGENTS.md — update any paths from .claude/ to .agents/"
else
    cat > AGENTS.md << 'EOF'
# Project — AI instructions

## NEVER DO

-

## ALWAYS DO

-

## ASK FIRST

-

## Reference files

| File | When to read |
|------|-------------|
| `.agents/` | Add your reference files here |
EOF
    ok "Created AGENTS.md template (no CLAUDE.md found)"
fi

# ── 4. replace .claude/CLAUDE.md with symlink ─────────────────────────────────
if [[ -L ".claude/CLAUDE.md" ]]; then
    warn ".claude/CLAUDE.md already a symlink — skipping"
elif [[ -f ".claude/CLAUDE.md" ]]; then
    rm .claude/CLAUDE.md
    ln -s ../AGENTS.md .claude/CLAUDE.md
    ok "Replaced .claude/CLAUDE.md with symlink → ../AGENTS.md"
else
    ln -s ../AGENTS.md .claude/CLAUDE.md
    ok "Created .claude/CLAUDE.md symlink → ../AGENTS.md"
fi

# ── 5. optional tool adapters ─────────────────────────────────────────────────
if [[ "$ALL_ADAPTERS" == true ]]; then
    echo ""
    echo "Tool adapters:"

    if [[ -e ".cursorrules" ]]; then
        warn ".cursorrules already exists — skipping"
    else
        ln -s AGENTS.md .cursorrules
        ok "Created .cursorrules → AGENTS.md (Cursor)"
    fi

    if [[ -e ".windsurfrules" ]]; then
        warn ".windsurfrules already exists — skipping"
    else
        ln -s AGENTS.md .windsurfrules
        ok "Created .windsurfrules → AGENTS.md (Windsurf)"
    fi

    mkdir -p .github
    if [[ -e ".github/copilot-instructions.md" ]]; then
        warn ".github/copilot-instructions.md already exists — skipping"
    else
        ln -s ../AGENTS.md .github/copilot-instructions.md
        ok "Created .github/copilot-instructions.md → ../AGENTS.md (Copilot)"
    fi
fi

echo ""
echo "Done. Edit AGENTS.md — all tools read it."
[[ "$ALL_ADAPTERS" == false ]] && echo "Run with --all to also create Cursor/Windsurf/Copilot adapters."
