# VoiceFlow - Build Instructions

## Prerequisites

### Required Software
1. **Xcode 15.0+** - Download from App Store or Apple Developer portal
2. **macOS 14.0+** - Required for latest Swift features
3. **Swift 5.9+** - Included with Xcode

### System Requirements
- macOS 14.0 Sonoma or later
- Apple Silicon (M1/M2/M3) or Intel processor
- 4GB RAM minimum, 8GB recommended
- 500MB disk space

## Build Steps

### 1. Install Xcode
```bash
# Option 1: Install from App Store
open "macappstore://itunes.apple.com/app/xcode/id497799835"

# Option 2: Download from Apple Developer (requires Apple ID)
# Visit: https://developer.apple.com/xcode/
```

### 2. Set Xcode as Active Developer Directory
```bash
# After installing Xcode, set it as the active developer directory
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# Verify the setup
xcode-select -p
# Should output: /Applications/Xcode.app/Contents/Developer
```

### 3. Accept Xcode License
```bash
sudo xcodebuild -license accept
```

### 4. Build the Project

#### Option A: Using Xcode GUI
```bash
# Open the project in Xcode
open VoiceFlow.xcodeproj

# In Xcode:
# 1. Select "VoiceFlow" scheme
# 2. Choose "My Mac" as destination
# 3. Press Cmd+B to build
# 4. Press Cmd+R to run
```

#### Option B: Using Command Line
```bash
# Navigate to project directory
cd /Users/lukaj/voiceflow

# Clean build
xcodebuild -project VoiceFlow.xcodeproj -scheme VoiceFlow -configuration Debug clean

# Build project
xcodebuild -project VoiceFlow.xcodeproj -scheme VoiceFlow -configuration Debug build

# Build and run
xcodebuild -project VoiceFlow.xcodeproj -scheme VoiceFlow -configuration Debug build -destination "platform=macOS"
```

#### Option C: Release Build for Distribution
```bash
# Archive for distribution
xcodebuild -project VoiceFlow.xcodeproj -scheme VoiceFlow -configuration Release archive -archivePath VoiceFlow.xcarchive

# Export for App Store
xcodebuild -exportArchive -archivePath VoiceFlow.xcarchive -exportPath ./Export -exportOptionsPlist ExportOptions.plist
```

## Build Configurations

### Debug Configuration
- Optimizations disabled
- Debug symbols included
- Assertions enabled
- Logging verbose
- Build time: ~30 seconds

### Release Configuration  
- Full optimizations enabled
- Debug symbols stripped
- Assertions disabled
- Logging minimal
- Build time: ~60 seconds

## Dependencies

The project uses Swift Package Manager for dependencies:

### Automatic Resolution
Dependencies are automatically resolved when building:
- **HotKey** (1.0.0+) - Global keyboard shortcuts
- **KeychainAccess** (4.0.0+) - Secure storage

### Manual Dependency Update
```bash
# Update dependencies
xcodebuild -resolvePackageDependencies -project VoiceFlow.xcodeproj
```

## Troubleshooting

### Common Build Issues

#### 1. "xcodebuild not found"
```bash
# Install command line tools
xcode-select --install

# Set correct Xcode path
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

#### 2. "Package resolution failed"
```bash
# Clear derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# Reset package caches
xcodebuild -resolvePackageDependencies -project VoiceFlow.xcodeproj
```

#### 3. "Code signing issues"
```bash
# In Xcode:
# 1. Select VoiceFlow target
# 2. Go to "Signing & Capabilities"
# 3. Set "Team" to your Apple Developer account
# 4. Enable "Automatically manage signing"
```

#### 4. "Permission denied"
```bash
# Fix file permissions
chmod -R 755 VoiceFlow.xcodeproj
```

### Performance Optimization
```bash
# Use parallel builds
xcodebuild -project VoiceFlow.xcodeproj -scheme VoiceFlow -configuration Release build -jobs 8

# Enable build timing
xcodebuild -project VoiceFlow.xcodeproj -scheme VoiceFlow -configuration Release build -showBuildTimingSummary
```

## Verification

### Post-Build Checks
```bash
# Check build products
ls -la build/Debug/VoiceFlow.app

# Verify app bundle
spctl --assess --verbose build/Debug/VoiceFlow.app

# Check dependencies
otool -L build/Debug/VoiceFlow.app/Contents/MacOS/VoiceFlow
```

### Test Build
```bash
# Run unit tests
xcodebuild test -project VoiceFlow.xcodeproj -scheme VoiceFlow -destination "platform=macOS"

# Run specific test
xcodebuild test -project VoiceFlow.xcodeproj -scheme VoiceFlow -destination "platform=macOS" -only-testing:VoiceFlowTests/AudioEngineTests
```

## App Store Build

### Prerequisites for Distribution
1. **Apple Developer Account** ($99/year)
2. **Distribution Certificate** 
3. **App Store Provisioning Profile**
4. **App Store Connect** app record

### Archive and Upload
```bash
# Create archive
xcodebuild -project VoiceFlow.xcodeproj -scheme VoiceFlow -configuration Release archive -archivePath VoiceFlow.xcarchive

# Validate archive
xcodebuild -exportArchive -archivePath VoiceFlow.xcarchive -exportPath ./Validation -exportOptionsPlist ExportOptions.plist -exportMethod app-store-connect -destination export

# Upload to App Store Connect
xcrun altool --upload-app --type macos --file VoiceFlow.pkg --username "your-apple-id" --password "app-specific-password"
```

## Build Environment

### Recommended Xcode Settings
- **Build Settings**: 
  - Enable "Whole Module Optimization" for Release
  - Set "Swift Optimization Level" to "Optimize for Speed"
  - Enable "Strip Debug Symbols" for Release
- **Capabilities**:
  - App Sandbox: Enabled
  - Microphone: Usage description provided
  - Network: Outgoing connections (for updates)

### CI/CD Integration
For automated builds, consider:
- **GitHub Actions** with macOS runners
- **Xcode Cloud** for Apple-native CI/CD
- **Fastlane** for deployment automation

---

## Quick Start

Once Xcode is installed:

```bash
# 1. Install Xcode from App Store
# 2. Set developer directory
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# 3. Build VoiceFlow
cd /Users/lukaj/voiceflow
xcodebuild -project VoiceFlow.xcodeproj -scheme VoiceFlow -configuration Debug build

# 4. Run the app
open build/Debug/VoiceFlow.app
```

The app should launch with the VoiceFlow splash screen and be ready for voice transcription!