#!/bin/bash
set -e

# Sightline App Builder
# Creates a proper macOS app bundle and optionally installs it

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="Sightline"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
ICONSET_DIR="$BUILD_DIR/Sightline.iconset"
BUNDLE_ID="com.github.mhersson.sightline"
VERSION="1.0.0"

echo "Building Sightline..."
cd "$PROJECT_DIR"

# Build release version
swift build -c release

# Create app bundle structure
echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/release/Sightline" "$APP_BUNDLE/Contents/MacOS/"

# Generate icon
echo "Generating app icon..."
mkdir -p "$ICONSET_DIR"
swift "$SCRIPT_DIR/generate-icon.swift" "$ICONSET_DIR"

# Convert iconset to icns
iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Sightline</string>
    <key>CFBundleDisplayName</key>
    <string>Sightline</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>Sightline</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

echo "App bundle created at: $APP_BUNDLE"

# Check for install flag
if [[ "$1" == "--install" ]]; then
    echo ""
    echo "Installing to /Applications..."

    # Kill running instance if any
    pkill -f "Sightline.app" 2>/dev/null || true
    pkill -f "/Sightline$" 2>/dev/null || true
    sleep 0.5

    # Remove old version and copy new
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP_BUNDLE" "/Applications/"

    echo "Installed to /Applications/$APP_NAME.app"

    # Set up Launch Agent for auto-start
    if [[ "$2" == "--autostart" ]]; then
        echo ""
        echo "Setting up auto-start on login..."

        LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
        LAUNCH_AGENT="$LAUNCH_AGENT_DIR/$BUNDLE_ID.plist"

        mkdir -p "$LAUNCH_AGENT_DIR"

        cat > "$LAUNCH_AGENT" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$BUNDLE_ID</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/Sightline.app/Contents/MacOS/Sightline</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
EOF

        # Load the launch agent
        launchctl unload "$LAUNCH_AGENT" 2>/dev/null || true
        launchctl load "$LAUNCH_AGENT"

        echo "Auto-start enabled. Sightline will start automatically on login."
    fi

    echo ""
    echo "Launching Sightline..."
    open "/Applications/$APP_NAME.app"

    echo ""
    echo "Done! Sightline is now running from /Applications."
else
    echo ""
    echo "To install to /Applications and set up auto-start, run:"
    echo "  $0 --install --autostart"
    echo ""
    echo "Or just install without auto-start:"
    echo "  $0 --install"
fi
