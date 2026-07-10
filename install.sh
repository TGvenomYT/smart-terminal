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

# ─── Offer to install missing deps ───

# Check if brew is available (needed to install things)
HAS_BREW=false
if command -v brew &>/dev/null; then
    HAS_BREW=true
fi

# Install missing required deps
if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo -e "${RED}Missing required dependencies:${RESET}"
    for dep in "${MISSING[@]}"; do
        echo -e "  • $dep"
    done
    echo ""

    if [[ "$HAS_BREW" == "true" ]]; then
        echo -n -e "Install them with Homebrew? [Y/n]: "
        read -r install_deps
        if [[ ! "$install_deps" =~ ^[Nn]$ ]]; then
            for dep in "${MISSING[@]}"; do
                case "$dep" in
                    apfel)
                        echo -e "  ${DIM}Installing apfel...${RESET}"
                        brew install apfel 2>/dev/null || {
                            # If not in homebrew core, try tap or direct install
                            echo -e "  ${YELLOW}△${RESET} apfel not in Homebrew. Trying direct install..."
                            curl -fsSL https://raw.githubusercontent.com/Arthur-Ficial/apfel/main/install.sh | bash 2>/dev/null || {
                                echo -e "  ${RED}✗${RESET} Could not auto-install apfel."
                                echo -e "    ${DIM}Install manually: https://github.com/Arthur-Ficial/apfel${RESET}"
                            }
                        }
                        ;;
                    perl)
                        echo -e "  ${DIM}Installing perl...${RESET}"
                        brew install perl
                        ;;
                    *)
                        echo -e "  ${DIM}Installing $dep...${RESET}"
                        brew install "$dep" 2>/dev/null || echo -e "  ${RED}✗${RESET} Could not install $dep"
                        ;;
                esac
            done
            echo ""
        else
            echo -e "Install them manually and run this script again."
            exit 1
        fi
    else
        echo -e "${YELLOW}Homebrew not found.${RESET} Install dependencies manually:"
        echo ""
        echo -e "  1. Install Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        echo -e "  2. Install apfel:    https://github.com/Arthur-Ficial/apfel"
        echo ""
        echo -e "Then run this script again."
        exit 1
    fi
fi

# Install optional deps
if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}Optional dependencies (some features won't work without them):${RESET}"
    for warn in "${WARNINGS[@]}"; do
        echo -e "  • $warn"
    done
    echo ""

    if [[ "$HAS_BREW" == "true" ]]; then
        echo -n -e "Install optional dependencies? [Y/n]: "
        read -r install_optional
        if [[ ! "$install_optional" =~ ^[Nn]$ ]]; then
            for warn in "${WARNINGS[@]}"; do
                case "$warn" in
                    *glow*)
                        echo -e "  ${DIM}Installing glow...${RESET}"
                        brew install glow 2>/dev/null && echo -e "  ${GREEN}✓${RESET} glow installed" || echo -e "  ${YELLOW}△${RESET} Could not install glow"
                        ;;
                    *python*)
                        echo -e "  ${DIM}Installing python3...${RESET}"
                        brew install python3 2>/dev/null && echo -e "  ${GREEN}✓${RESET} python3 installed" || echo -e "  ${YELLOW}△${RESET} Could not install python3"
                        ;;
                    *git*)
                        echo -e "  ${DIM}Installing git...${RESET}"
                        brew install git 2>/dev/null && echo -e "  ${GREEN}✓${RESET} git installed" || echo -e "  ${YELLOW}△${RESET} Could not install git"
                        ;;
                esac
            done
            echo ""
        fi
    fi
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

# Compile OCR tool (Swift → native binary for fast OCR)
if command -v swiftc &>/dev/null; then
    echo -e "  ${DIM}Compiling OCR tool...${RESET}"
    if swiftc -O -o "$INSTALL_DIR/bin/ocr-tool" "$SCRIPT_DIR/ocr-tool.swift" 2>/dev/null; then
        echo -e "  ${GREEN}✓${RESET} OCR tool compiled"
    else
        echo -e "  ${YELLOW}△${RESET} OCR tool compilation failed (will use slower Swift fallback)"
    fi
else
    echo -e "  ${YELLOW}△${RESET} swiftc not found (ocr-explain will use slower fallback)"
fi

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
echo -e "    ocr-explain      Screenshot → OCR → explain"
echo ""
echo -e "  ${DIM}Want a global hotkey for OCR Explain? See:${RESET}"
echo -e "    ${BOLD}extras/hammerspoon-init.lua${RESET}"
echo ""
