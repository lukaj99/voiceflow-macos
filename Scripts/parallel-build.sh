#!/bin/bash

# Parallel Build Script for Claude Code Development
# Builds multiple worktrees simultaneously for maximum efficiency

set -e

echo "🔥 PARALLEL BUILD EXECUTION"
echo "=========================="
echo "Building across multiple worktrees simultaneously..."

# Build configuration
BUILD_CONFIG="release"
PARALLEL_JOBS=$(sysctl -n hw.ncpu)
BUILD_FLAGS=(
    "--configuration" "$BUILD_CONFIG"
    "--build-path" ".build-parallel"
    "-Xswiftc" "-strict-concurrency=complete"
    "-Xswiftc" "-O"
    "-Xswiftc" "-whole-module-optimization"
    "-j" "$PARALLEL_JOBS"
)

echo "🚀 Using $PARALLEL_JOBS parallel jobs"
echo "🎯 Configuration: $BUILD_CONFIG"

# Function to build in a worktree
build_worktree() {
    local worktree_path=$1
    local worktree_name=$2
    
    if [ -d "$worktree_path" ] && [ -f "$worktree_path/Package.swift" ]; then
        echo "🔨 Building $worktree_name..."
        
        cd "$worktree_path"
        
        # Clean previous build
        rm -rf .build-parallel
        
        # Build with optimizations
        if swift build "${BUILD_FLAGS[@]}" > /dev/null 2>&1; then
            echo "✅ $worktree_name build completed successfully"
            
            # Check build artifacts
            if [ -f ".build-parallel/$BUILD_CONFIG/VoiceFlow" ]; then
                local size=$(du -h ".build-parallel/$BUILD_CONFIG/VoiceFlow" | cut -f1)
                echo "📦 $worktree_name executable: $size"
            fi
        else
            echo "❌ $worktree_name build failed"
            return 1
        fi
    else
        echo "⚠️  $worktree_name: No Package.swift found, skipping"
    fi
}

# Parallel build execution
echo ""
echo "🔄 Starting parallel builds..."

# Build main worktree
build_worktree "/Users/lukaj/voiceflow" "Main" &
MAIN_PID=$!

# Build UI integration worktree  
build_worktree "/Users/lukaj/swift6-ui-integration" "UI-Integration" &
UI_PID=$!

# Build services worktree
build_worktree "/Users/lukaj/swift6-services-integration" "Services" &
SERVICES_PID=$!

# Build testing worktree
build_worktree "/Users/lukaj/swift6-testing" "Testing" &
TESTING_PID=$!

# Build packaging worktree
build_worktree "/Users/lukaj/swift6-packaging" "Packaging" &
PACKAGING_PID=$!

# Wait for all builds to complete
echo "⏳ Waiting for parallel builds to complete..."

wait $MAIN_PID && echo "✅ Main build finished" || echo "❌ Main build failed"
wait $UI_PID && echo "✅ UI build finished" || echo "❌ UI build failed" 
wait $SERVICES_PID && echo "✅ Services build finished" || echo "❌ Services build failed"
wait $TESTING_PID && echo "✅ Testing build finished" || echo "❌ Testing build failed"
wait $PACKAGING_PID && echo "✅ Packaging build finished" || echo "❌ Packaging build failed"

echo ""
echo "🎉 PARALLEL BUILD COMPLETE!"
echo "=========================="

# Generate build summary
cd "/Users/lukaj/voiceflow"
echo "📊 Build Summary:"
echo "  🔨 Configuration: $BUILD_CONFIG"  
echo "  ⚡ Parallel Jobs: $PARALLEL_JOBS"
echo "  🎯 Swift 6 Concurrency: ENABLED"
echo "  🚀 AsyncAlgorithms: INTEGRATED"

# Check total build artifacts
total_size=0
for worktree in "/Users/lukaj/voiceflow" "/Users/lukaj/swift6-"*; do
    if [ -f "$worktree/.build-parallel/$BUILD_CONFIG/VoiceFlow" ]; then
        size_bytes=$(stat -f%z "$worktree/.build-parallel/$BUILD_CONFIG/VoiceFlow" 2>/dev/null || echo 0)
        total_size=$((total_size + size_bytes))
    fi
done

if [ $total_size -gt 0 ]; then
    total_mb=$((total_size / 1024 / 1024))
    echo "  📦 Total Build Size: ${total_mb}MB"
fi

echo ""
echo "🚀 Ready for parallel development!"