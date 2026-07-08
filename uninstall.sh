#!/bin/bash
# ─────────────────────────────────────────────────────────────
# Smart Terminal Uninstaller
# ─────────────────────────────────────────────────────────────

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

INSTALL_DIR="$HOME/.smart-terminal"

if [[ -d "/opt/homebrew/bin" ]]; then
    BIN_DIR="/opt/homebrew/bin"
else
    BIN_DIR="/usr/local/bin"
fi

echo ""
echo -e "${BOLD}Smart Terminal Uninstaller${RESET}"
echo ""
echo -e "This will remove:"
echo -e "  - $INSTALL_DIR/"
echo -e "  - CLI tools: ai, git-changes, summarize"
echo -e "  - Smart Terminal lines from ~/.zshrc"
echo ""
echo -n -e "Proceed? [y/N]: "
read -r confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${DIM}Cancelled.${RESET}"
    exit 0
fi

echo ""

# Remove symlinks
TOOLS=(ai git-changes summarize ocr-explain)
for tool in "${TOOLS[@]}"; do
    if [[ -L "$BIN_DIR/$tool" ]]; then
        rm -f "$BIN_DIR/$tool" 2>/dev/null || sudo rm -f "$BIN_DIR/$tool"
        echo -e "  ${GREEN}✓${RESET} Removed $BIN_DIR/$tool"
    fi
done

# Remove install directory
if [[ -d "$INSTALL_DIR" ]]; then
    rm -rf "$INSTALL_DIR"
    echo -e "  ${GREEN}✓${RESET} Removed $INSTALL_DIR"
fi

# Clean .zshrc
ZSHRC="$HOME/.zshrc"
if [[ -f "$ZSHRC" ]]; then
    TMPFILE=$(mktemp)
    grep -v "smart-terminal" "$ZSHRC" | grep -v "# Smart Terminal" > "$TMPFILE" || true
    mv "$TMPFILE" "$ZSHRC"
    echo -e "  ${GREEN}✓${RESET} Cleaned ~/.zshrc"
fi

echo ""
echo -e "${GREEN}${BOLD}Done.${RESET} Restart your shell or run: source ~/.zshrc"
echo ""
