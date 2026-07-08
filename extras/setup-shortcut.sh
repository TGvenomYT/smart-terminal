#!/bin/bash
# setup-shortcut.sh — Installs OCR Explain app and helps set up a global hotkey
#
# Usage: ./extras/setup-shortcut.sh

set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
DIM='\033[2m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="OCR Explain"
APP_SOURCE="${SCRIPT_DIR}/${APP_NAME}.app"
APP_DEST="/Applications/${APP_NAME}.app"
SCRIPT_PATH="$HOME/.smart-terminal/bin/ocr-explain"

echo ""
echo -e "${BOLD}OCR Explain — Global Hotkey Setup${RESET}"
echo ""

# Check if ocr-explain is installed
if [[ ! -f "$SCRIPT_PATH" ]]; then
    echo -e "${RED}✗ ocr-explain not found. Run install.sh first.${RESET}"
    exit 1
fi

# Build the .app if it doesn't exist in extras
if [[ ! -d "$APP_SOURCE" ]]; then
    echo -e "  ${DIM}Building OCR Explain.app...${RESET}"
    mkdir -p "${APP_SOURCE}/Contents/MacOS"
    mkdir -p "${APP_SOURCE}/Contents/Resources"

    cat > "${APP_SOURCE}/Contents/Info.plist" << 'INFOPLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>OCR Explain</string>
	<key>CFBundleIconFile</key>
	<string>applet</string>
	<key>CFBundleIdentifier</key>
	<string>com.niranjan.ocr-explain</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>OCR Explain</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>12.0</string>
	<key>LSUIElement</key>
	<true/>
</dict>
</plist>
INFOPLIST

    cat > "${APP_SOURCE}/Contents/MacOS/${APP_NAME}" << 'LAUNCHER'
#!/bin/bash
# OCR Explain launcher — opens Terminal and runs ocr-explain
osascript -e 'tell application "Terminal"' -e 'activate' -e 'do script "$HOME/.smart-terminal/bin/ocr-explain"' -e 'end tell'
LAUNCHER
    chmod +x "${APP_SOURCE}/Contents/MacOS/${APP_NAME}"
fi

# Copy to /Applications
if [[ -d "$APP_DEST" ]]; then
    rm -rf "$APP_DEST"
fi
cp -r "$APP_SOURCE" "$APP_DEST"
echo -e "  ${GREEN}✓${RESET} Installed to /Applications/OCR Explain.app"

# Remove old Quick Action if it exists
if [[ -d "$HOME/Library/Services/OCR Explain.workflow" ]]; then
    rm -rf "$HOME/Library/Services/OCR Explain.workflow"
    echo -e "  ${DIM}Removed old Quick Action workflow${RESET}"
fi

echo ""
echo -e "${CYAN}To assign a global keyboard shortcut:${RESET}"
echo ""
echo -e "  ${BOLD}Option A — Spotlight (quick):${RESET}"
echo -e "    Press ⌘Space, type \"OCR Explain\", hit Enter"
echo ""
echo -e "  ${BOLD}Option B — Global hotkey (recommended):${RESET}"
echo -e "    1. Open ${CYAN}System Settings → Keyboard → Keyboard Shortcuts${RESET}"
echo -e "    2. Click ${CYAN}App Shortcuts${RESET} → click ${GREEN}+${RESET}"
echo -e "    3. Application: ${GREEN}All Applications${RESET}"
echo -e "       Menu title: ${GREEN}OCR Explain${RESET}"
echo -e "       Shortcut: ${GREEN}⌃⇧E${RESET} (or your preference)"
echo ""
echo -e "  ${BOLD}Option C — Automator:${RESET}"
echo -e "    1. Open Automator → New → Quick Action"
echo -e "    2. Add \"Launch Application\" action → select \"OCR Explain\""
echo -e "    3. Save, then assign shortcut in System Settings → Services"
echo ""
echo -e "${DIM}The app opens Terminal, captures your screen selection, OCRs it, and explains.${RESET}"
echo ""
