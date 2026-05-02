# setup-agents — Plan de implementación

## Objetivo

CLI tool instalable desde GitHub. Automatiza la creación de una fuente única de verdad para documentación de AI en cualquier proyecto. Cualquier AI (Claude Code, OpenCode, Cursor, Windsurf, Copilot) lee el mismo archivo `AGENTS.md`.

---

## Contexto: qué hace el tool

Dado un directorio de proyecto con `.claude/CLAUDE.md` (u otro AI config), el tool:

1. Crea `.agents/` y mueve todos los archivos `.md` de `.claude/` (excepto `CLAUDE.md`) hacia `.agents/`
2. Crea `AGENTS.md` en la raíz (copia de `.claude/CLAUDE.md`, o template si no existe)
3. Reemplaza `.claude/CLAUDE.md` con symlink `→ ../AGENTS.md`
4. Opcionalmente crea symlinks para otros tools: `.cursorrules`, `.windsurfrules`, `.github/copilot-instructions.md`

**Resultado:**
```
proyecto/
├── AGENTS.md                          ← editar solo este
├── .agents/
│   ├── server-reference.md
│   ├── security-status.md
│   └── (cualquier .md de referencia)
└── .claude/
    └── CLAUDE.md → ../AGENTS.md       ← symlink, Claude Code lo carga automático
```

**Por qué funciona:**
| Tool | Lee | Cómo |
|------|-----|------|
| Claude Code | `.claude/CLAUDE.md` | symlink → AGENTS.md |
| OpenCode | `AGENTS.md` | lectura directa (soporte nativo) |
| Cursor | `.cursorrules` | symlink → AGENTS.md (opcional) |
| Windsurf | `.windsurfrules` | symlink → AGENTS.md (opcional) |
| GitHub Copilot | `.github/copilot-instructions.md` | symlink → AGENTS.md (opcional) |

---

## Estructura del repo

```
setup-agents/              ← nuevo repo GitHub
├── setup-agents           ← script principal (el que se instala)
├── install.sh             ← installer via curl | sh
└── README.md
```

**Instalación (usuario final):**
```bash
curl -fsSL https://raw.githubusercontent.com/USER/setup-agents/main/install.sh | sh
```

**Uso:**
```bash
setup-agents init                     # directorio actual
setup-agents init /ruta/al/proyecto   # directorio específico
setup-agents init --all               # + adapters para Cursor/Windsurf/Copilot
setup-agents init /ruta --all

setup-agents add cursor               # agregar adapter después
setup-agents add windsurf
setup-agents add copilot

setup-agents --help
setup-agents --version
```

---

## Archivo: `install.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION="1.0.0"
REPO_RAW="https://raw.githubusercontent.com/USER/setup-agents/main"
INSTALL_DIR="${HOME}/.local/bin"
BIN_NAME="setup-agents"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }

echo "Installing setup-agents v${VERSION}..."

mkdir -p "$INSTALL_DIR"
curl -fsSL "${REPO_RAW}/${BIN_NAME}" -o "${INSTALL_DIR}/${BIN_NAME}"
chmod +x "${INSTALL_DIR}/${BIN_NAME}"

ok "Installed to ${INSTALL_DIR}/${BIN_NAME}"

# PATH check
if ! echo ":${PATH}:" | grep -q ":${INSTALL_DIR}:"; then
    warn "Add to your shell profile:"
    echo ""
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
    warn "Then restart your terminal or run: source ~/.zshrc"
else
    ok "PATH already includes ${INSTALL_DIR}"
    echo ""
    echo "Run: setup-agents --help"
fi
```

---

## Archivo: `setup-agents`

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION="1.0.0"

# ── colors ─────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; exit 1; }
bold() { echo -e "${BOLD}$*${NC}"; }

# ── help ───────────────────────────────────────────────────────────────────
usage() {
    cat << EOF
setup-agents v${VERSION}
Single source of truth for multi-AI documentation.

USAGE:
  setup-agents init [PATH] [--all]
  setup-agents add <adapter>
  setup-agents --help | --version

COMMANDS:
  init [PATH]    Set up AGENTS.md structure in PATH (default: current dir)
  add <adapter>  Add a tool adapter symlink to current project
                 Adapters: cursor | windsurf | copilot

OPTIONS:
  --all          Create all tool adapter symlinks (cursor, windsurf, copilot)
  --help         Show this help
  --version      Show version

EXAMPLES:
  setup-agents init
  setup-agents init ~/projects/myapp
  setup-agents init --all
  setup-agents init ~/projects/myapp --all
  setup-agents add cursor
EOF
}

# ── arg parsing ────────────────────────────────────────────────────────────
CMD=""
TARGET_DIR=""
ALL_ADAPTERS=false
ADAPTER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        init)       CMD="init"; shift ;;
        add)        CMD="add"; shift; ADAPTER="${1:-}"; shift || true ;;
        --all)      ALL_ADAPTERS=true; shift ;;
        --help|-h)  usage; exit 0 ;;
        --version)  echo "setup-agents v${VERSION}"; exit 0 ;;
        -*)         fail "Unknown option: $1" ;;
        *)
            if [[ -z "$TARGET_DIR" ]]; then
                TARGET_DIR="$1"
            else
                fail "Unexpected argument: $1"
            fi
            shift
            ;;
    esac
done

# default command
[[ -z "$CMD" ]] && { usage; exit 0; }

# ── resolve target directory ───────────────────────────────────────────────
if [[ -z "$TARGET_DIR" ]]; then
    TARGET_DIR="$PWD"
fi

TARGET_DIR="$(cd "$TARGET_DIR" 2>/dev/null && pwd)" || fail "Directory not found: $TARGET_DIR"

# ── command: add ───────────────────────────────────────────────────────────
cmd_add() {
    [[ -z "$ADAPTER" ]] && fail "Specify adapter: cursor | windsurf | copilot"
    [[ -f "AGENTS.md" ]] || fail "No AGENTS.md found. Run 'setup-agents init' first."

    case "$ADAPTER" in
        cursor)
            if [[ -e ".cursorrules" ]]; then
                warn ".cursorrules already exists — skipping"
            else
                ln -s AGENTS.md .cursorrules
                ok "Created .cursorrules → AGENTS.md (Cursor)"
            fi
            ;;
        windsurf)
            if [[ -e ".windsurfrules" ]]; then
                warn ".windsurfrules already exists — skipping"
            else
                ln -s AGENTS.md .windsurfrules
                ok "Created .windsurfrules → AGENTS.md (Windsurf)"
            fi
            ;;
        copilot)
            mkdir -p .github
            if [[ -e ".github/copilot-instructions.md" ]]; then
                warn ".github/copilot-instructions.md already exists — skipping"
            else
                ln -s ../AGENTS.md .github/copilot-instructions.md
                ok "Created .github/copilot-instructions.md → ../AGENTS.md (Copilot)"
            fi
            ;;
        *)
            fail "Unknown adapter: $ADAPTER. Options: cursor | windsurf | copilot"
            ;;
    esac
}

# ── command: init ──────────────────────────────────────────────────────────
cmd_init() {
    bold "setup-agents init → ${TARGET_DIR}"
    echo ""

    cd "$TARGET_DIR"

    # 1. create .agents/
    if [[ -d ".agents" ]]; then
        warn ".agents/ already exists — skipping"
    else
        mkdir .agents
        ok "Created .agents/"
    fi

    # 2. move all .md files from .claude/ (except CLAUDE.md)
    moved=0
    if [[ -d ".claude" ]]; then
        for f in .claude/*.md .claude/*.MD; do
            [[ -e "$f" ]] || continue
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
    fi
    [[ $moved -eq 0 ]] && warn "No reference files moved (already done or none found)"

    # 3. create AGENTS.md
    if [[ -e "AGENTS.md" && ! -L "AGENTS.md" ]]; then
        warn "AGENTS.md already exists — skipping"
        warn "Review paths inside AGENTS.md — should reference .agents/ not .claude/"
    elif [[ -L ".claude/CLAUDE.md" ]]; then
        warn ".claude/CLAUDE.md already a symlink — AGENTS.md already set up"
    elif [[ -f ".claude/CLAUDE.md" ]]; then
        cp .claude/CLAUDE.md AGENTS.md
        ok "Created AGENTS.md from .claude/CLAUDE.md"
        warn "Review AGENTS.md — update any paths from .claude/ to .agents/"
    else
        # no CLAUDE.md — create minimal template
        cat > AGENTS.md << 'TEMPLATE'
# Project — AI instructions

## NEVER DO

-

## ALWAYS DO

-

## ASK FIRST

-

## Reference files

Consult based on task context — don't load all at once:

| File | When to read |
|------|-------------|
| `.agents/` | Add your reference files here |
TEMPLATE
        ok "Created AGENTS.md template"
    fi

    # 4. replace .claude/CLAUDE.md with symlink
    if [[ ! -d ".claude" ]]; then
        mkdir .claude
        ok "Created .claude/"
    fi

    if [[ -L ".claude/CLAUDE.md" ]]; then
        warn ".claude/CLAUDE.md already a symlink — skipping"
    elif [[ -f ".claude/CLAUDE.md" ]]; then
        rm .claude/CLAUDE.md
        ln -s ../AGENTS.md .claude/CLAUDE.md
        ok "Replaced .claude/CLAUDE.md with symlink → ../AGENTS.md"
    else
        ln -s ../AGENTS.md .claude/CLAUDE.md
        ok "Created .claude/CLAUDE.md → ../AGENTS.md"
    fi

    # 5. optional adapters
    if [[ "$ALL_ADAPTERS" == true ]]; then
        echo ""
        bold "Tool adapters:"
        ADAPTER="cursor";  cmd_add
        ADAPTER="windsurf"; cmd_add
        ADAPTER="copilot";  cmd_add
    fi

    echo ""
    ok "Done. Edit AGENTS.md — all tools read it automatically."
    [[ "$ALL_ADAPTERS" == false ]] && echo "   Run with --all to create Cursor/Windsurf/Copilot adapters."
}

# ── dispatch ───────────────────────────────────────────────────────────────
case "$CMD" in
    init) cmd_init ;;
    add)  cd "$TARGET_DIR"; cmd_add ;;
esac
```

---

## Archivo: `README.md`

````markdown
# setup-agents

CLI tool that sets up a single source of truth for AI documentation across any project.
Any AI tool (Claude Code, OpenCode, Cursor, Windsurf, Copilot) reads the same `AGENTS.md` file.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/USER/setup-agents/main/install.sh | sh
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
````

---

## Pasos de implementación

1. **Crear directorio del repo:**
   ```bash
   mkdir ~/setup-agents && cd ~/setup-agents
   git init
   ```

2. **Crear los 3 archivos** con el contenido exacto de las secciones anteriores:
   - `setup-agents` (el script principal)
   - `install.sh`
   - `README.md`

3. **Hacer ejecutables:**
   ```bash
   chmod +x setup-agents install.sh
   ```

4. **Actualizar `USER`** en `install.sh` y `README.md` con el username real de GitHub.

5. **Push a GitHub:**
   ```bash
   git add .
   git commit -m "Initial release"
   git remote add origin https://github.com/USER/setup-agents.git
   git push -u origin main
   ```

6. **Probar install:**
   ```bash
   curl -fsSL https://raw.githubusercontent.com/USER/setup-agents/main/install.sh | sh
   ```

---

## Tests de verificación

```bash
# Test básico
mkdir /tmp/test-project && cd /tmp/test-project
mkdir .claude
echo "# instrucciones AI" > .claude/CLAUDE.md
echo "# referencia servidor" > .claude/server-reference.md

setup-agents init
ls -la .claude/CLAUDE.md        # debe mostrar → ../AGENTS.md
cat AGENTS.md                   # debe mostrar contenido de CLAUDE.md
ls .agents/                     # debe contener server-reference.md

# Test --all
setup-agents init --all
ls -la .cursorrules .windsurfrules .github/copilot-instructions.md

# Test add
mkdir /tmp/test2 && cd /tmp/test2 && mkdir .claude && echo "#" > .claude/CLAUDE.md
setup-agents init
setup-agents add cursor
ls -la .cursorrules              # debe mostrar → AGENTS.md

# Test idempotencia
setup-agents init                # debe advertir "already done", no fallar

# Test directorio específico
setup-agents init /tmp/test3
setup-agents init ~/projects/miproyecto --all
```

---

## Notas importantes

- Script es **idempotente** — cualquier paso ya hecho genera warning y sigue
- Mueve **todos** los `.md` de `.claude/` excepto `CLAUDE.md` — nombres no importan
- Si no existe `.claude/CLAUDE.md`, crea `AGENTS.md` con template mínimo
- `~/.local/bin/` es el directorio de instalación por default — requiere estar en `$PATH`
- No tiene dependencias externas — solo bash y curl para instalar
