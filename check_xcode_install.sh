#!/bin/bash

echo "🔍 Checking Xcode Installation Status..."
echo "======================================="

# Check if download is in progress
if [ -d "/Applications/Xcode.appdownload" ]; then
    SIZE=$(du -sh /Applications/Xcode.appdownload 2>/dev/null | cut -f1)
    echo "📥 Status: DOWNLOADING"
    echo "📁 Current size: $SIZE"
    echo "⏱️  Estimated completion: 30-60 minutes"
    echo ""
    echo "💡 Tip: Keep your Mac awake and connected to power"
    echo "🌐 Download requires stable internet connection"
fi

# Check if Xcode is installed
if [ -d "/Applications/Xcode.app" ]; then
    echo "✅ Status: INSTALLED"
    XCODE_VERSION=$(xcodebuild -version 2>/dev/null | head -1)
    echo "📱 Version: $XCODE_VERSION"
    echo ""
    echo "🎉 Ready to build VoiceFlow!"
    echo "Run: cd /Users/lukaj/voiceflow && xcodebuild -project VoiceFlow.xcodeproj -scheme VoiceFlow build"
fi

# Check App Store process
if pgrep -f "App Store" > /dev/null; then
    echo "🏪 App Store is running (downloading in background)"
else
    echo "⚠️  App Store not running - download may have paused"
    echo "💡 Open App Store to resume download"
fi

echo ""
echo "🔄 Run this script again to check progress: ./check_xcode_install.sh"