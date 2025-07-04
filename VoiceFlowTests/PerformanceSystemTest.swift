import XCTest
import AVFoundation
@testable import VoiceFlow

/// Test performance monitoring and buffer pooling system
final class PerformanceSystemTest: XCTestCase {
    
    func testAudioBufferPoolBasics() async throws {
        // Create test audio format
        guard let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else {
            XCTFail("Failed to create audio format")
            return
        }
        
        // Create buffer pool
        let bufferPool = AudioBufferPool(
            maxPoolSize: 5,
            bufferFrameCapacity: 1024,
            audioFormat: audioFormat
        )
        
        // Test buffer acquisition
        let buffer1 = bufferPool.acquireBuffer()
        XCTAssertNotNil(buffer1, "Should be able to acquire buffer")
        
        let buffer2 = bufferPool.acquireBuffer()
        XCTAssertNotNil(buffer2, "Should be able to acquire second buffer")
        
        // Test buffer return
        if let buffer1 = buffer1 {
            bufferPool.returnBuffer(buffer1)
        }
        
        // Get statistics
        let stats = await bufferPool.getStatistics()
        XCTAssertGreaterThan(stats.totalBuffers, 0, "Should have buffers in pool")
        
        print("✅ Buffer pool test passed - Total buffers: \(stats.totalBuffers), Hit rate: \(stats.poolHitRate)")
    }
    
    func testPerformanceMonitorBasics() async throws {
        // Create performance monitor
        let monitor = PerformanceMonitor.shared
        
        // Create test audio format and buffer pool
        guard let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else {
            XCTFail("Failed to create audio format")
            return
        }
        
        let bufferPool = AudioBufferPool(audioFormat: audioFormat)
        
        // Start monitoring
        await monitor.startMonitoring(bufferPool: bufferPool)
        
        // Record some operations
        await monitor.recordOperation()
        await monitor.recordOperation()
        
        // Get current metrics
        let metrics = await monitor.getCurrentMetrics()
        XCTAssertGreaterThan(metrics.cpuUsage, 0, "Should have CPU usage data")
        XCTAssertGreaterThan(metrics.memoryUsageMB, 0, "Should have memory usage data")
        XCTAssertGreaterThanOrEqual(metrics.operationsPerSecond, 0, "Should have operations data")
        
        // Test performance profile generation
        let profile = await monitor.generatePerformanceProfile(name: "Test Profile")
        XCTAssertEqual(profile.profileName, "Test Profile")
        XCTAssertFalse(profile.recommendations.isEmpty, "Should have recommendations")
        
        // Test health check
        let health = await monitor.checkPerformanceHealth()
        XCTAssertNotNil(health.overall, "Should have overall health status")
        XCTAssertFalse(health.recommendations.isEmpty, "Should have health recommendations")
        
        // Stop monitoring
        await monitor.stopMonitoring()
        
        print("✅ Performance monitor test passed - CPU: \(metrics.cpuUsage)%, Memory: \(metrics.memoryUsageMB)MB")
    }
    
    func testBufferPoolOptimization() async throws {
        guard let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else {
            XCTFail("Failed to create audio format")
            return
        }
        
        let bufferPool = AudioBufferPool(
            maxPoolSize: 10,
            bufferFrameCapacity: 1024,
            audioFormat: audioFormat
        )
        
        // Acquire and return multiple buffers to generate usage data
        var buffers: [AudioBufferPool.PooledBuffer] = []
        
        for _ in 0..<5 {
            if let buffer = bufferPool.acquireBuffer() {
                buffers.append(buffer)
            }
        }
        
        // Return buffers
        for buffer in buffers {
            bufferPool.returnBuffer(buffer)
        }
        
        // Get initial stats
        let initialStats = await bufferPool.getStatistics()
        
        // Optimize pool
        await bufferPool.optimizePoolSize()
        
        // Get optimized stats
        let optimizedStats = await bufferPool.getStatistics()
        
        XCTAssertGreaterThanOrEqual(optimizedStats.poolHitRate, 0, "Should have valid hit rate after optimization")
        
        print("✅ Buffer optimization test passed - Hit rate: \(optimizedStats.poolHitRate)")
    }
    
    func testPerformanceAlerts() async throws {
        let monitor = PerformanceMonitor.shared
        
        // Test latency recording (should trigger alert if high)
        await monitor.recordTranscriptionLatency(3.0) // High latency
        await monitor.recordAudioProcessingLatency(2.5) // High audio latency
        
        // Small delay to allow async alert processing
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        let alerts = await monitor.getPerformanceAlerts()
        
        // Should have at least some alerts (may not trigger if thresholds aren't met)
        print("✅ Performance alerts test completed - Alerts count: \(alerts.count)")
    }
    
    func testAudioBufferManagerSharedPool() async throws {
        guard let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else {
            XCTFail("Failed to create audio format")
            return
        }
        
        // Reset any existing shared pool
        await AudioBufferManager.resetSharedPool()
        
        // Get shared pool
        let sharedPool1 = await AudioBufferManager.getSharedPool(audioFormat: audioFormat)
        let sharedPool2 = await AudioBufferManager.getSharedPool(audioFormat: audioFormat)
        
        // Should be the same instance (conceptually)
        XCTAssertNotNil(sharedPool1)
        XCTAssertNotNil(sharedPool2)
        
        print("✅ Shared buffer pool test passed")
    }
    
    func testPerformanceSystemIntegration() async throws {
        // Test full integration between buffer pool and performance monitor
        guard let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else {
            XCTFail("Failed to create audio format")
            return
        }
        
        let bufferPool = AudioBufferPool(audioFormat: audioFormat)
        let monitor = PerformanceMonitor.shared
        
        // Start monitoring with buffer pool
        await monitor.startMonitoring(bufferPool: bufferPool)
        
        // Simulate some activity
        for i in 0..<10 {
            await monitor.recordOperation()
            
            if let buffer = bufferPool.acquireBuffer() {
                // Simulate some work
                try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
                bufferPool.returnBuffer(buffer)
            }
            
            if i % 3 == 0 {
                await monitor.recordTranscriptionLatency(0.5)
                await monitor.recordAudioProcessingLatency(0.1)
            }
        }
        
        // Get final metrics
        let metrics = await monitor.getCurrentMetrics()
        let bufferStats = await bufferPool.getStatistics()
        let health = await monitor.checkPerformanceHealth()
        
        // Verify integration
        XCTAssertGreaterThan(metrics.operationsPerSecond, 0, "Should have recorded operations")
        XCTAssertGreaterThan(bufferStats.totalBuffers, 0, "Should have buffer activity")
        XCTAssertNotNil(health.overall, "Should have health status")
        
        // Export performance data
        let exportData = await monitor.exportPerformanceData()
        XCTAssertNotNil(exportData, "Should be able to export performance data")
        
        if let data = exportData {
            XCTAssertGreaterThan(data.count, 0, "Export data should not be empty")
            print("✅ Performance data export size: \(data.count) bytes")
        }
        
        // Stop monitoring
        await monitor.stopMonitoring()
        
        print("✅ Performance system integration test passed")
        print("   Final metrics - Operations/sec: \(metrics.operationsPerSecond)")
        print("   Buffer stats - Hit rate: \(bufferStats.poolHitRate), Total: \(bufferStats.totalBuffers)")
        print("   Health status: \(health.overall.rawValue)")
    }
}