#!/bin/bash
set -e

# VoiceFlow Build and Install Script
# This script builds VoiceFlow and installs it to /Applications/

echo "🎙️  Building VoiceFlow..."

# Get the project directory (parent of scripts/)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

source "$PROJECT_DIR/scripts/swiftpm-preflight.sh"
ensure_swiftpm_manifest_is_healthy "$PROJECT_DIR" || exit 1

# Build for current architecture (Apple Silicon)
echo "📦 Building release binary for arm64..."
swift build -c release --arch arm64

# Check if build succeeded
if [ ! -f ".build/arm64-apple-macosx/release/VoiceFlow" ]; then
    echo "❌ Build failed - executable not found"
    exit 1
fi

echo "✅ Build complete"

# Create app bundle structure
echo "📁 Creating app bundle..."
rm -rf VoiceFlow.app
mkdir -p VoiceFlow.app/Contents/{MacOS,Resources,Resources/bin}

# Copy executable
cp .build/arm64-apple-macosx/release/VoiceFlow VoiceFlow.app/Contents/MacOS/
chmod +x VoiceFlow.app/Contents/MacOS/VoiceFlow

# Copy Python scripts and ml package
cp Sources/*.py VoiceFlow.app/Contents/Resources/ 2>/dev/null || true
if [ -d "Sources/ml" ]; then
    cp -R Sources/ml VoiceFlow.app/Contents/Resources/
    # Clean up Python cache
    find VoiceFlow.app/Contents/Resources/ml -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
fi

# Copy uv binary if available
if command -v uv &> /dev/null; then
    cp "$(command -v uv)" VoiceFlow.app/Contents/Resources/bin/uv 2>/dev/null || true
fi

# Create Info.plist
cat > VoiceFlow.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>VoiceFlow</string>
    <key>CFBundleIdentifier</key>
    <string>com.voiceflow.app</string>
    <key>CFBundleName</key>
    <string>VoiceFlow</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>VoiceFlow needs microphone access to record your voice for transcription.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>VoiceFlow needs permission to paste transcribed text into other applications.</string>
</dict>
</plist>
EOF

echo "✅ App bundle created"

# Sign the app with ad-hoc signature
echo "✍️  Signing app..."
codesign --force --deep --sign - --identifier "com.voiceflow.app" VoiceFlow.app
echo "✅ App signed"

# Kill running instance
echo "🛑 Stopping any running instances..."
pkill -x VoiceFlow 2>/dev/null || true
sleep 1

# Install to Applications
echo "📲 Installing to /Applications/..."
rm -rf /Applications/VoiceFlow.app
cp -R VoiceFlow.app /Applications/

echo ""
echo "✅ VoiceFlow successfully installed to /Applications/VoiceFlow.app"
echo ""
echo "⚠️  IMPORTANT: Since the code signature changed, you must re-grant permissions:"
echo "   1. Open System Settings → Privacy & Security → Accessibility"
echo "   2. Remove VoiceFlow from the list (if present)"
echo "   3. Click + and add /Applications/VoiceFlow.app"
echo "   4. Ensure the toggle is ON"
echo ""
echo "🚀 Launch VoiceFlow with: open /Applications/VoiceFlow.app"
