#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$SCRIPT_DIR/ClaudeCodeUsageMonitor"
OUTPUT_DIR="$SCRIPT_DIR/build"
APP_NAME="Claude Code Usage Monitor"
APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"

echo "=================================================="
echo "🔨 Building $APP_NAME for macOS"
echo "=================================================="

# 1. Clean previous build
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 2. Compile Swift binary
echo "Compiling Swift source files with optimizations..."
cd "$SOURCE_DIR"
swiftc -parse-as-library \
    -O \
    -target arm64-apple-macosx14.0 \
    App.swift \
    Models.swift \
    CredentialManager.swift \
    SettingsManager.swift \
    UsagePoller.swift \
    Views/ProgressBarView.swift \
    Views/LimitCardView.swift \
    Views/DashboardView.swift \
    Views/SettingsView.swift \
    -o "$APP_BUNDLE/Contents/MacOS/ClaudeCodeUsageMonitor"

# 3. Copy Bundle Metadata and Resources
echo "Configuring App Bundle..."
cp "$SOURCE_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$SOURCE_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# 4. Ad-hoc codesign
echo "Applying ad-hoc code signature..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "✅ App bundle created successfully at: $APP_BUNDLE"
