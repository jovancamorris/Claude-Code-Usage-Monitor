#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/dist"
APP_NAME="Claude Code Usage Monitor"
APP_BUNDLE="$SCRIPT_DIR/build/$APP_NAME.app"
DMG_NAME="Claude-Code-Usage-Monitor-macOS.dmg"
FINAL_DMG="$OUTPUT_DIR/$DMG_NAME"
STAGING_DIR="/tmp/claude_dmg_staging_$$"

echo "=================================================="
echo "📦 Packaging $APP_NAME into .DMG Installer"
echo "=================================================="

# Ensure the app is built first
if [ ! -d "$APP_BUNDLE" ]; then
    echo "App bundle not found. Building first..."
    "$SCRIPT_DIR/build_app.sh"
fi

# Prepare staging
rm -rf "$STAGING_DIR" "$OUTPUT_DIR"
mkdir -p "$STAGING_DIR"
mkdir -p "$OUTPUT_DIR"

echo "Copying application bundle to staging area..."
cp -R "$APP_BUNDLE" "$STAGING_DIR/"

echo "Creating Applications symlink..."
ln -s /Applications "$STAGING_DIR/Applications"

cat << 'EOF' > "$STAGING_DIR/INSTALL_INSTRUCTIONS.txt"
Claude Code Usage Monitor for macOS
===================================

Installation:
1. Drag "Claude Code Usage Monitor.app" to the "Applications" folder.
2. Open the app from your Applications folder or Spotlight.
3. The monitor icon will appear in your macOS Menu Bar.

Usage & Authentication:
- Automatically detects OAuth credentials from macOS Keychain ("Claude Code-credentials") or ~/.claude/.credentials.json.
- Click the Menu Bar icon to see your 5-Hour Session Limit, 7-Day Weekly Limit, and Spend.
- Open Preferences (gear icon) to adjust display mode, polling intervals, or enter a custom token.

Developed & Recreated for macOS by jovancamorris
GitHub: https://github.com/jovancamorris/Claude-Code-Usage-Monitor
EOF

echo "Creating compressed disk image with hdiutil..."
hdiutil create -volname "Claude Code Usage Monitor" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$FINAL_DMG"

rm -rf "$STAGING_DIR"

echo ""
echo "=================================================="
echo "🎉 DMG Packaging Complete!"
echo "Location: $FINAL_DMG"
echo "Size: $(du -h "$FINAL_DMG" | cut -f1)"
echo "=================================================="
