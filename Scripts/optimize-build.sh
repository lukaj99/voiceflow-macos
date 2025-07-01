#!/bin/bash

# VoiceFlow Build Optimization Script
# Optimizes Swift 6 build performance for parallel development

set -e

echo "🚀 VoiceFlow Build Optimization Script"
echo "======================================="

# Configuration
BUILD_DIR=".build"
SWIFT_VERSION=$(swift --version | head -n 1)
echo "Swift Version: $SWIFT_VERSION"

# Clean previous builds for fresh optimization
echo "🧹 Cleaning previous builds..."
rm -rf "$BUILD_DIR"

# Optimize for parallel compilation
echo "⚡ Configuring parallel compilation..."
export SWIFTPM_BUILD_JOBS=$(sysctl -n hw.ncpu)
echo "Using $SWIFTPM_BUILD_JOBS parallel jobs"

# Swift 6 optimized build flags
SWIFT_FLAGS=(
    "--configuration" "release"
    "--build-path" "$BUILD_DIR"
    "-Xswiftc" "-strict-concurrency=complete"
    "-Xswiftc" "-enable-upcoming-feature" "-Xswiftc" "StrictConcurrency"
    "-Xswiftc" "-warnings-as-errors"
    "-Xswiftc" "-O"
    "-Xswiftc" "-whole-module-optimization"
)

# Build with optimizations
echo "🔨 Building VoiceFlow with Swift 6 optimizations..."
swift build "${SWIFT_FLAGS[@]}"

# Verify build artifacts
echo "✅ Build completed successfully!"
echo "Build artifacts:"
find "$BUILD_DIR" -name "VoiceFlow" -type f 2>/dev/null || echo "No executable found"

# Performance metrics
BUILD_SIZE=$(du -sh "$BUILD_DIR" 2>/dev/null | cut -f1 || echo "Unknown")
echo "📊 Build directory size: $BUILD_SIZE"

echo ""
echo "🎯 Optimization complete! Ready for parallel development."
echo "Run 'swift run' to execute the optimized build."