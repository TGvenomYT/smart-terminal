#!/bin/bash
# ─────────────────────────────────────────────────────────────
# Smart Terminal — Installer
# https://github.com/TGvenomYT/smart-terminal
#
# Usage:
#   git clone https://github.com/TGvenomYT/smart-terminal.git
#   cd smart-terminal
#   ./install.sh
# ─────────────────────────────────────────────────────────────

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

INSTALL_DIR="$HOME/.smart-terminal"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="/usr/local/bin"

# Use Homebrew bin if available (Apple Silicon vs Intel)
if [[ -d "/opt/homebrew/bin" ]]; then
    BIN_DIR="/opt/homebrew/bin"
elif [[ -d "/usr/local/bin" ]]; then
    BIN_DIR="/usr/local/bin"
fi

echo ""
echo -e "${BOLD}Smart Terminal Installer${RESET}"
echo -e "${DIM}Local AI-powered shell for macOS${RESET}"
echo ""

# ─── Pre-flight checks ───

echo -e "${CYAN}Checking requirements...${RESET}"
echo ""

MISSING=()
WARNINGS=()

# macOS check
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}✗ This tool is designed for macOS only.${RESET}"
    exit 1
fi
echo -e "  ${GREEN}✓${RESET} macOS detected"

# zsh check
if ! command -v zsh &>/dev/null; then
    MISSING+=("zsh")
    echo -e "  ${RED}✗${RESET} zsh not found"
else
    echo -e "  ${GREEN}✓${RESET} zsh"
fi

# apfel check (required for LLM features)
if ! command -v apfel &>/dev/null; then
    MISSING+=("apfel")
    echo -e "  ${RED}✗${RESET} apfel not found"
    echo -e "    ${DIM}Install from: https://github.com/Arthur-Ficial/apfel${RESET}"
else
    APFEL_VER=$(apfel --version 2>/dev/null | head -1 || echo "unknown")
    echo -e "  ${GREEN}✓${RESET} apfel ($APFEL_VER)"
fi

# python3 check (required for summarize)
if ! command -v python3 &>/dev/null; then
    WARNINGS+=("python3 — needed for 'summarize' command")
    echo -e "  ${YELLOW}△${RESET} python3 not found (summarize won't work)"
else
    PY_VER=$(python3 --version 2>/dev/null)
    echo -e "  ${GREEN}✓${RESET} $PY_VER"
fi

# glow check (optional, for markdown rendering)
if ! command -v glow &>/dev/null; then
    WARNINGS+=("glow — for rendered markdown output")
    echo -e "  ${YELLOW}△${RESET} glow not found (output won't be formatted)"
    echo -e "    ${DIM}Install with: brew install glow${RESET}"
else
    echo -e "  ${GREEN}✓${RESET} glow"
fi

# perl check (for ANSI stripping)
if ! command -v perl &>/dev/null; then
    MISSING+=("perl")
    echo -e "  ${RED}✗${RESET} perl not found"
else
    echo -e "  ${GREEN}✓${RESET} perl"
fi

# git check
if ! command -v git &>/dev/null; then
    WARNINGS+=("git — needed for git-changes and smart-commit")
    echo -e "  ${YELLOW}△${RESET} git not found"
else
    echo -e "  ${GREEN}✓${RESET} git"
fi

echo ""

# Abort if critical deps missing
if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo -e "${RED}Missing required dependencies:${RESET}"
    for dep in "${MISSING[@]}"; do
        echo -e "  • $dep"
    done
    echo ""
    echo -e "Install them and run this script again."
    exit 1
fi

# Show warnings
if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}Optional dependencies (some features won't work without them):${RESET}"
    for warn in "${WARNINGS[@]}"; do
        echo -e "  • $warn"
    done
    echo ""
fi

# ─── Check Python packages for summarize ───

if command -v python3 &>/dev/null; then
    echo -e "${CYAN}Checking Python packages for document summarizer...${RESET}"
    PY_MISSING=()

    python3 -c "import pdfplumber" 2>/dev/null || PY_MISSING+=("pdfplumber")
    python3 -c "import docx" 2>/dev/null || PY_MISSING+=("python-docx")
    python3 -c "import openpyxl" 2>/dev/null || PY_MISSING+=("openpyxl")
    python3 -c "import pptx" 2>/dev/null || PY_MISSING+=("python-pptx")

    if [[ ${#PY_MISSING[@]} -gt 0 ]]; then
        echo -e "  ${YELLOW}△${RESET} Missing: ${PY_MISSING[*]}"
        echo ""
        echo -n -e "  Install them now? [Y/n]: "
        read -r install_py
        if [[ ! "$install_py" =~ ^[Nn]$ ]]; then
            echo -e "  ${DIM}Installing...${RESET}"
            pip3 install --break-system-packages ${PY_MISSING[*]} 2>/dev/null || \
            pip3 install ${PY_MISSING[*]} 2>/dev/null || \
            python3 -m pip install ${PY_MISSING[*]} 2>/dev/null || {
                echo -e "  ${YELLOW}△${RESET} Could not auto-install. Run manually:"
                echo -e "    pip3 install ${PY_MISSING[*]}"
            }
        fi
    else
        echo -e "  ${GREEN}✓${RESET} All packages installed"
    fi
    echo ""
fi

# ─── Install ───

echo -e "${CYAN}Installing Smart Terminal...${RESET}"
echo ""

# Copy files to ~/.smart-terminal
if [[ -d "$INSTALL_DIR" ]]; then
    echo -e "  ${DIM}Updating existing installation at $INSTALL_DIR${RESET}"
else
    echo -e "  ${DIM}Installing to $INSTALL_DIR${RESET}"
fi

mkdir -p "$INSTALL_DIR"

# Copy core files
cp "$SCRIPT_DIR/smart-terminal.zsh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/commands.zsh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/system-prompt.txt" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/ocr.py" "$INSTALL_DIR/"

# Only copy config if it doesn't exist (don't overwrite user config)
if [[ ! -f "$INSTALL_DIR/config.zsh" ]]; then
    cp "$SCRIPT_DIR/config.zsh" "$INSTALL_DIR/"
else
    echo -e "  ${DIM}Keeping existing config.zsh${RESET}"
fi

# Create custom-commands.zsh if it doesn't exist
if [[ ! -f "$INSTALL_DIR/custom-commands.zsh" ]]; then
    cp "$SCRIPT_DIR/custom-commands.zsh" "$INSTALL_DIR/"
fi

echo -e "  ${GREEN}✓${RESET} Core files installed"

# Install CLI tools
echo -e "  ${DIM}Linking CLI tools to $BIN_DIR${RESET}"

for tool in "$SCRIPT_DIR/bin/"*; do
    tool_name=$(basename "$tool")
    # Check for conflicts
    if [[ -e "$BIN_DIR/$tool_name" ]] && [[ ! -L "$BIN_DIR/$tool_name" ]]; then
        echo -e "  ${YELLOW}△${RESET} Skipping $tool_name (file already exists at $BIN_DIR/$tool_name)"
        continue
    fi
    ln -sf "$INSTALL_DIR/bin/$tool_name" "$BIN_DIR/$tool_name" 2>/dev/null || {
        echo -e "  ${YELLOW}△${RESET} Need sudo to link $tool_name"
        sudo ln -sf "$INSTALL_DIR/bin/$tool_name" "$BIN_DIR/$tool_name"
    }
    echo -e "  ${GREEN}✓${RESET} $tool_name"
done

# Copy bin files to install dir too (so symlinks work after repo is moved)
mkdir -p "$INSTALL_DIR/bin"
cp "$SCRIPT_DIR/bin/"* "$INSTALL_DIR/bin/"
chmod +x "$INSTALL_DIR/bin/"*

# Update symlinks to point to install dir
for tool in "$INSTALL_DIR/bin/"*; do
    tool_name=$(basename "$tool")
    ln -sf "$INSTALL_DIR/bin/$tool_name" "$BIN_DIR/$tool_name" 2>/dev/null || \
    sudo ln -sf "$INSTALL_DIR/bin/$tool_name" "$BIN_DIR/$tool_name" 2>/dev/null
done

echo -e "  ${GREEN}✓${RESET} CLI tools linked"

# ─── Shell integration ───

echo ""
echo -e "${CYAN}Setting up shell integration...${RESET}"

ZSHRC="$HOME/.zshrc"
SOURCE_LINE='source ~/.smart-terminal/config.zsh'
SOURCE_LINE2='source ~/.smart-terminal/smart-terminal.zsh'
MARKER="# Smart Terminal"

if grep -q "smart-terminal.zsh" "$ZSHRC" 2>/dev/null; then
    echo -e "  ${DIM}Already in .zshrc — skipping${RESET}"
else
    echo "" >> "$ZSHRC"
    echo "$MARKER" >> "$ZSHRC"
    echo "$SOURCE_LINE" >> "$ZSHRC"
    echo "$SOURCE_LINE2" >> "$ZSHRC"
    echo -e "  ${GREEN}✓${RESET} Added to ~/.zshrc"
fi

# ─── Done ───

echo ""
echo -e "${GREEN}${BOLD}✓ Smart Terminal installed successfully!${RESET}"
echo ""
echo -e "  Reload your shell:  ${BOLD}source ~/.zshrc${RESET}"
echo ""
echo -e "  ${DIM}Commands:${RESET}"
echo -e "    ? <query>        Natural language → shell command"
echo -e "    explain <error>  Explain an error message"
echo -e "    port <number>    Check what's using a port"
echo -e "    ai <question>    Chat with local AI"
echo -e "    summarize <file> Summarize a document"
echo -e "    git-changes      Explain your code changes"
echo -e "    smart-commit     Generate commit messages"
echo ""
