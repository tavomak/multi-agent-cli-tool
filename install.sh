#!/usr/bin/env bash
set -euo pipefail

REPO_RAW="${SETUP_AGENTS_REPO_RAW:-https://raw.githubusercontent.com/tavomak/multi-agent-cli-tool/main}"
INSTALL_DIR="${HOME}/.local/bin"
BIN_NAME="setup-agents"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; exit 1; }

echo "Installing setup-agents..."

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

curl -fsSL "${REPO_RAW}/${BIN_NAME}" -o "$TMP" || fail "Download failed. Check your connection."
bash -n "$TMP" 2>/dev/null || fail "Downloaded file is not valid bash — aborting."

VERSION="$(grep '^VERSION=' "$TMP" | head -1 | cut -d'"' -f2)"
[[ -n "$VERSION" ]] || fail "Downloaded file has no VERSION — aborting."

mkdir -p "$INSTALL_DIR"
chmod 755 "$TMP"
mv "$TMP" "${INSTALL_DIR}/${BIN_NAME}"
trap - EXIT

ok "Installed setup-agents v${VERSION} to ${INSTALL_DIR}/${BIN_NAME}"

if ! echo ":${PATH}:" | grep -qF ":${INSTALL_DIR}:"; then
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
