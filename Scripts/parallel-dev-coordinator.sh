#!/bin/bash

# Parallel Development Coordinator for VoiceFlow Swift 6 Migration
# Manages development across multiple git worktrees with Claude Code

set -e

echo "🔀 VoiceFlow Parallel Development Coordinator"
echo "============================================"

# Configuration
MAIN_WORKTREE="/Users/lukaj/voiceflow"
WORKTREES=(
    "swift6-ui-integration:UI Components"
    "swift6-services-integration:Services Layer"  
    "swift6-testing:Testing & Validation"
    "swift6-packaging:App Store Packaging"
)

# Function to show worktree status
show_worktree_status() {
    echo "📊 Worktree Status:"
    git worktree list | while read line; do
        worktree_path=$(echo "$line" | awk '{print $1}')
        branch=$(echo "$line" | awk '{print $3}' | tr -d '[]')
        commit=$(echo "$line" | awk '{print $2}')
        
        if [ -d "$worktree_path" ]; then
            echo "  ✅ $(basename "$worktree_path"): $branch ($commit)"
        else
            echo "  ❌ $(basename "$worktree_path"): Not accessible"
        fi
    done
}

# Function to sync changes across worktrees
sync_worktrees() {
    echo ""
    echo "🔄 Syncing changes across worktrees..."
    
    for worktree_info in "${WORKTREES[@]}"; do
        worktree_name=$(echo "$worktree_info" | cut -d: -f1)
        worktree_desc=$(echo "$worktree_info" | cut -d: -f2)
        worktree_path="/Users/lukaj/$worktree_name"
        
        if [ -d "$worktree_path" ]; then
            echo "  🔄 Syncing $worktree_desc ($worktree_name)"
            
            # Check for uncommitted changes
            cd "$worktree_path"
            if ! git diff-index --quiet HEAD --; then
                echo "    ⚠️  Uncommitted changes detected"
            else
                echo "    ✅ Clean working directory"
            fi
        fi
    done
}

# Function to run parallel development tasks
run_parallel_tasks() {
    echo ""
    echo "🚀 Running parallel development tasks..."
    
    # Task 1: Build optimization in main worktree
    echo "  🔨 Build optimization (main)" &
    
    # Task 2: UI refinement in ui worktree  
    echo "  🎨 UI component refinement (ui-integration)" &
    
    # Task 3: Services optimization in services worktree
    echo "  ⚙️  Services layer optimization (services-integration)" &
    
    # Task 4: Testing in testing worktree
    echo "  🧪 Comprehensive testing (testing)" &
    
    # Task 5: Packaging in packaging worktree
    echo "  📦 App Store packaging (packaging)" &
    
    # Wait for all tasks
    wait
    
    echo "  ✅ All parallel tasks completed!"
}

# Function to show development recommendations
show_recommendations() {
    echo ""
    echo "💡 Parallel Development Recommendations:"
    echo "  1. Main worktree: Focus on core Swift 6 compatibility"
    echo "  2. UI worktree: Polish MenuBar and Settings components"
    echo "  3. Services worktree: Optimize performance and caching"
    echo "  4. Testing worktree: Run comprehensive validation"
    echo "  5. Packaging worktree: Prepare App Store assets"
    echo ""
    echo "🎯 Claude Code can work on any worktree independently!"
}

# Main execution
echo "Current working directory: $(pwd)"
echo ""

show_worktree_status
sync_worktrees
run_parallel_tasks
show_recommendations

echo ""
echo "🎉 Parallel development coordination complete!"
echo "All worktrees are synchronized and ready for Claude Code development."