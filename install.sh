#!/usr/bin/env bash
set -euo pipefail

VERSION="1.0.0"
REPO_RAW="https://raw.githubusercontent.com/tavomak/multi-agent-cli-tool/main"
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
