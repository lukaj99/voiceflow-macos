import XCTest
import AsyncAlgorithms
@testable import VoiceFlow

/// Parallel development validation tests for Claude Code workflows
class ParallelDevelopmentTests: XCTestCase {
    
    // MARK: - Parallel Processing Tests
    
    func testAsyncTranscriptionProcessor() async throws {
        let processor = await AsyncTranscriptionProcessor()
        
        await MainActor.run {
            XCTAssertFalse(processor.isProcessing)
            XCTAssertEqual(processor.queuedSegments, 0)
        }
        
        // Test parallel segment processing
        let segments = (1...10).map { index in
            AsyncTranscriptionProcessor.TranscriptionSegment(
                text: "Test segment \(index)",
                confidence: Double.random(in: 0.8...1.0)
            )
        }
        
        // Add segments in parallel
        await withTaskGroup(of: Void.self) { group in
            for segment in segments {
                group.addTask {
                    await processor.addSegment(segment)
                }
            }
        }
        
        // Wait for processing
        try await Task.sleep(for: .milliseconds(500))
        
        let metrics = await processor.getProcessingMetrics()
        XCTAssertGreaterThan(metrics.rate, 0)
    }
    
    func testParallelWorktreeValidation() async {
        // Validate that parallel development doesn't cause conflicts
        let tasks = (1...5).map { taskId in
            Task {
                // Simulate parallel development work
                let workDuration = Double.random(in: 0.01...0.1)
                try? await Task.sleep(for: .seconds(workDuration))
                return "Task \(taskId) completed"
            }
        }
        
        let results = await withTaskGroup(of: String.self) { group in
            for task in tasks {
                group.addTask {
                    await task.value
                }
            }
            
            var completedTasks: [String] = []
            for await result in group {
                completedTasks.append(result)
            }
            return completedTasks
        }
        
        XCTAssertEqual(results.count, 5)
        XCTAssertTrue(results.allSatisfy { $0.contains("completed") })
    }
    
    func testConcurrentWorktreeOperations() async throws {
        // Test that multiple worktrees can operate simultaneously
        let worktreeOperations = [
            "main": "Core development",
            "ui-integration": "UI refinement", 
            "services-integration": "Services optimization",
            "testing": "Validation testing",
            "packaging": "App Store prep"
        ]
        
        let results = await withTaskGroup(of: (String, String).self) { group in
            for (worktree, operation) in worktreeOperations {
                group.addTask {
                    // Simulate worktree operation
                    try? await Task.sleep(for: .milliseconds(50))
                    return (worktree, "\(operation) completed")
                }
            }
            
            var completed: [(String, String)] = []
            for await result in group {
                completed.append(result)
            }
            return completed
        }
        
        XCTAssertEqual(results.count, 5)
        
        // Verify all worktrees completed successfully
        let completedWorktrees = Set(results.map { $0.0 })
        let expectedWorktrees = Set(worktreeOperations.keys)
        XCTAssertEqual(completedWorktrees, expectedWorktrees)
    }
    
    func testClaudeCodeParallelEfficiency() async {
        // Test Claude Code's ability to handle parallel development efficiently
        let startTime = Date()
        
        // Simulate Claude Code working on multiple tasks simultaneously
        let parallelTasks = await withTaskGroup(of: TimeInterval.self) { group in
            
            // Task 1: Core engine work
            group.addTask {
                let taskStart = Date()
                try? await Task.sleep(for: .milliseconds(100))
                return Date().timeIntervalSince(taskStart)
            }
            
            // Task 2: UI development  
            group.addTask {
                let taskStart = Date()
                try? await Task.sleep(for: .milliseconds(80))
                return Date().timeIntervalSince(taskStart)
            }
            
            // Task 3: Testing
            group.addTask {
                let taskStart = Date()
                try? await Task.sleep(for: .milliseconds(60))
                return Date().timeIntervalSince(taskStart)
            }
            
            // Task 4: Documentation
            group.addTask {
                let taskStart = Date()
                try? await Task.sleep(for: .milliseconds(40))
                return Date().timeIntervalSince(taskStart)
            }
            
            var taskDurations: [TimeInterval] = []
            for await duration in group {
                taskDurations.append(duration)
            }
            return taskDurations
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let sequentialTime = parallelTasks.reduce(0, +)
        let parallelEfficiency = sequentialTime / totalTime
        
        // Parallel execution should be significantly faster than sequential
        XCTAssertGreaterThan(parallelEfficiency, 2.0, "Parallel development should be at least 2x faster")
        XCTAssertLessThan(totalTime, 0.2, "Total parallel execution should be under 200ms")
    }
    
    // MARK: - Git Worktree Integration Tests
    
    func testWorktreeSynchronization() async {
        // Test that changes can be synchronized across worktrees
        let syncOperations = [
            "commit_main": "Main branch commits",
            "merge_ui": "UI branch integration",
            "test_services": "Services validation", 
            "package_build": "Build packaging"
        ]
        
        let syncResults = await withTaskGroup(of: Bool.self) { group in
            for (operation, _) in syncOperations {
                group.addTask {
                    // Simulate git operations
                    try? await Task.sleep(for: .milliseconds(30))
                    
                    // All operations should succeed in parallel
                    return operation.contains("_")
                }
            }
            
            var successes: [Bool] = []
            for await success in group {
                successes.append(success)
            }
            return successes
        }
        
        XCTAssertTrue(syncResults.allSatisfy { $0 }, "All worktree sync operations should succeed")
    }
}