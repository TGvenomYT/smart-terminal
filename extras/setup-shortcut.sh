#!/bin/bash
# setup-shortcut.sh — Creates a macOS Service/Quick Action for OCR Explain
# This allows you to bind it to a global keyboard shortcut.
#
# After running this script:
# 1. Go to System Settings → Keyboard → Keyboard Shortcuts → Services
# 2. Find "OCR Explain" under General
# 3. Assign your preferred shortcut (e.g., Ctrl+Shift+E)

set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
DIM='\033[2m'
RED='\033[0;31m'
RESET='\033[0m'

SERVICE_NAME="OCR Explain"
SERVICE_DIR="$HOME/Library/Services/${SERVICE_NAME}.workflow"
SCRIPT_PATH="$HOME/.smart-terminal/bin/ocr-explain"

echo ""
echo -e "${CYAN}Setting up OCR Explain keyboard shortcut...${RESET}"
echo ""

# Check if ocr-explain is installed
if [[ ! -f "$SCRIPT_PATH" ]]; then
    echo -e "${RED}✗ ocr-explain not found at $SCRIPT_PATH${RESET}"
    echo -e "${DIM}Run install.sh first.${RESET}"
    exit 1
fi

# Create the Automator workflow directory structure
mkdir -p "${SERVICE_DIR}/Contents"

# Write the Info.plist
cat > "${SERVICE_DIR}/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSServices</key>
	<array>
		<dict>
			<key>NSMenuItem</key>
			<dict>
				<key>default</key>
				<string>OCR Explain</string>
			</dict>
			<key>NSMessage</key>
			<string>runWorkflowAsService</string>
		</dict>
	</array>
</dict>
</plist>
PLIST

# Write the workflow document
cat > "${SERVICE_DIR}/Contents/document.wflow" << WFLOW
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AMApplicationBuild</key>
	<string>523</string>
	<key>AMApplicationVersion</key>
	<string>2.10</string>
	<key>AMDocumentVersion</key>
	<string>2</string>
	<key>actions</key>
	<array>
		<dict>
			<key>action</key>
			<dict>
				<key>AMAccepts</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Optional</key>
					<true/>
					<key>Types</key>
					<array>
						<string>com.apple.cocoa.string</string>
					</array>
				</dict>
				<key>AMActionVersion</key>
				<string>2.0.3</string>
				<key>AMApplication</key>
				<array>
					<string>Automator</string>
				</array>
				<key>AMBundleIdentifier</key>
				<string>com.apple.RunShellScript</string>
				<key>AMCategory</key>
				<array>
					<string>AMCategoryUtilities</string>
				</array>
				<key>AMIconName</key>
				<string>Automator</string>
				<key>AMKeywords</key>
				<array>
					<string>Shell</string>
					<string>Script</string>
				</array>
				<key>AMName</key>
				<string>Run Shell Script</string>
				<key>AMRequiredResources</key>
				<array/>
				<key>AMTag</key>
				<string>AMTagUtilities</string>
				<key>ActionBundlePath</key>
				<string>/System/Library/Automator/Run Shell Script.action</string>
				<key>ActionName</key>
				<string>Run Shell Script</string>
				<key>ActionParameters</key>
				<dict>
					<key>COMMAND_STRING</key>
					<string>\$HOME/.smart-terminal/bin/ocr-explain 2>/dev/null &amp;</string>
					<key>CheckedForUserDefaultShell</key>
					<true/>
					<key>inputMethod</key>
					<integer>1</integer>
					<key>shell</key>
					<string>/bin/bash</string>
					<key>source</key>
					<string></string>
				</dict>
				<key>BundleIdentifier</key>
				<string>com.apple.RunShellScript</string>
				<key>CFBundleVersion</key>
				<string>2.0.3</string>
				<key>CanShowSelectedItemsWhenRun</key>
				<false/>
				<key>CanShowWhenRun</key>
				<true/>
				<key>Category</key>
				<array>
					<string>AMCategoryUtilities</string>
				</array>
				<key>Class Name</key>
				<string>RunShellScriptAction</string>
				<key>InputUUID</key>
				<string>E1A2B3C4-D5E6-F7A8-B9C0-D1E2F3A4B5C6</string>
				<key>Keywords</key>
				<array>
					<string>Shell</string>
					<string>Script</string>
				</array>
				<key>OutputUUID</key>
				<string>A1B2C3D4-E5F6-A7B8-C9D0-E1F2A3B4C5D6</string>
				<key>UUID</key>
				<string>F1E2D3C4-B5A6-9870-1234-567890ABCDEF</string>
				<key>UnlocalizedApplications</key>
				<array>
					<string>Automator</string>
				</array>
			</dict>
		</dict>
	</array>
	<key>connectors</key>
	<dict/>
	<key>workflowMetaData</key>
	<dict>
		<key>workflowTypeIdentifier</key>
		<string>com.apple.Automator.servicesMenu</string>
	</dict>
</dict>
</plist>
WFLOW

echo -e "  ${GREEN}✓${RESET} Created Quick Action: ${SERVICE_NAME}"
echo ""
echo -e "${CYAN}Next steps:${RESET}"
echo -e "  1. Open ${CYAN}System Settings → Keyboard → Keyboard Shortcuts → Services${RESET}"
echo -e "  2. Find ${GREEN}\"OCR Explain\"${RESET} under ${DIM}General${RESET}"
echo -e "  3. Click it and assign a shortcut (e.g., ${GREEN}⌃⇧E${RESET})"
echo ""
echo -e "${DIM}After that, press your shortcut from anywhere to screenshot + OCR + explain.${RESET}"
echo ""
