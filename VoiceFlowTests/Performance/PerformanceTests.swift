import XCTest
import os.log
@testable import VoiceFlowCore

class PerformanceTests: XCTestCase {
    let performanceMonitor = PerformanceMonitor.shared
    
    override func setUp() {
        super.setUp()
        // Reset any state if needed
    }
    
    // MARK: - Latency Tests
    
    func testTranscriptionLatencyP50() {
        measureMetrics([XCTClockMetric()], automaticallyStartMeasuring: false) {
            let expectation = XCTestExpectation(description: "Latency test")
            
            Task {
                // Warm up
                for _ in 0..<10 {
                    await simulateTranscriptionOperation()
                }
                
                // Measure
                self.startMeasuring()
                
                for _ in 0..<100 {
                    await performanceMonitor.measureTranscriptionLatency {
                        await simulateTranscriptionOperation()
                    }
                }
                
                self.stopMeasuring()
                
                // Verify P50
                let stats = performanceMonitor.latencyStatistics()
                XCTAssertLessThan(stats.p50, PerformanceMonitor.LatencyRequirements.transcriptionP50,
                                 "P50 latency (\(stats.p50 * 1000)ms) exceeds requirement (30ms)")
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testTranscriptionLatencyP95() {
        measureMetrics([XCTClockMetric()], automaticallyStartMeasuring: false) {
            let expectation = XCTestExpectation(description: "P95 latency test")
            
            Task {
                self.startMeasuring()
                
                for _ in 0..<200 {
                    await performanceMonitor.measureTranscriptionLatency {
                        await simulateTranscriptionOperation()
                    }
                }
                
                self.stopMeasuring()
                
                let stats = performanceMonitor.latencyStatistics()
                XCTAssertLessThan(stats.p95, PerformanceMonitor.LatencyRequirements.transcriptionP95,
                                 "P95 latency (\(stats.p95 * 1000)ms) exceeds requirement (50ms)")
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testTranscriptionLatencyP99() {
        let expectation = XCTestExpectation(description: "P99 latency test")
        
        Task {
            for _ in 0..<500 {
                await performanceMonitor.measureTranscriptionLatency {
                    await simulateTranscriptionOperation()
                }
            }
            
            let stats = performanceMonitor.latencyStatistics()
            XCTAssertLessThan(stats.p99, PerformanceMonitor.LatencyRequirements.transcriptionP99,
                             "P99 latency (\(stats.p99 * 1000)ms) exceeds requirement (100ms)")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 60)
    }
    
    // MARK: - Memory Tests
    
    func testMemoryUsageBaseline() {
        measure(metrics: [XCTMemoryMetric()]) {
            // Baseline memory usage
            let app = VoiceFlowTestApp()
            
            // Wait for initialization
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 1))
            
            let memoryUsage = performanceMonitor.currentMemoryUsage
            XCTAssertLessThan(memoryUsage, PerformanceMonitor.MemoryRequirements.baselineUsage,
                             "Baseline memory usage exceeds 150MB")
        }
    }
    
    func testMemoryUsageDuringTranscription() {
        measure(metrics: [XCTMemoryMetric()]) {
            let expectation = XCTestExpectation(description: "Memory test")
            
            Task {
                let engine = SpeechAnalyzerEngine()
                try await engine.startTranscription()
                
                // Simulate 30 seconds of transcription
                for _ in 0..<300 {
                    await simulateAudioBuffer(to: engine)
                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                }
                
                await engine.stopTranscription()
                
                let memoryUsage = performanceMonitor.currentMemoryUsage
                XCTAssertLessThan(memoryUsage, PerformanceMonitor.MemoryRequirements.activeTranscription,
                                 "Active transcription memory usage exceeds 200MB")
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 35)
        }
    }
    
    func testMemoryLeaks() {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        
        measure(metrics: [XCTMemoryMetric()], options: options) {
            autoreleasepool {
                let expectation = XCTestExpectation(description: "Memory leak test")
                
                Task {
                    // Create and destroy multiple engines
                    for _ in 0..<10 {
                        let engine = SpeechAnalyzerEngine()
                        try? await engine.startTranscription()
                        await engine.stopTranscription()
                    }
                    
                    expectation.fulfill()
                }
                
                wait(for: [expectation], timeout: 30)
            }
        }
    }
    
    // MARK: - CPU Tests
    
    func testCPUUsageIdle() {
        measure(metrics: [XCTCPUMetric()]) {
            // Idle state
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 5))
            
            let cpuUsage = performanceMonitor.currentCPUUsage
            XCTAssertLessThan(cpuUsage, PerformanceMonitor.CPURequirements.idleUsage,
                             "Idle CPU usage exceeds 1%")
        }
    }
    
    func testCPUUsageDuringTranscription() {
        measure(metrics: [XCTCPUMetric()]) {
            let expectation = XCTestExpectation(description: "CPU test")
            
            Task {
                let engine = SpeechAnalyzerEngine()
                try await engine.startTranscription()
                
                // Measure during active transcription
                var maxCPU: Double = 0
                for _ in 0..<100 {
                    await simulateAudioBuffer(to: engine)
                    maxCPU = max(maxCPU, performanceMonitor.currentCPUUsage)
                    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
                
                await engine.stopTranscription()
                
                XCTAssertLessThan(maxCPU, PerformanceMonitor.CPURequirements.activeTranscription,
                                 "Active transcription CPU usage exceeds 10%")
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10)
        }
    }
    
    // MARK: - UI Responsiveness Tests
    
    func testUIResponseTime() {
        measureMetrics([XCTClockMetric()], automaticallyStartMeasuring: false) {
            let expectation = XCTestExpectation(description: "UI response test")
            
            Task {
                let viewModel = TranscriptionViewModel()
                
                self.startMeasuring()
                
                // Measure UI update latency
                for text in testTranscriptionTexts {
                    let start = CACurrentMediaTime()
                    await MainActor.run {
                        viewModel.transcribedText = text
                    }
                    let duration = CACurrentMediaTime() - start
                    
                    XCTAssertLessThan(duration, PerformanceMonitor.LatencyRequirements.uiResponseTime,
                                     "UI update exceeds 16ms (60fps)")
                }
                
                self.stopMeasuring()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10)
        }
    }
    
    // MARK: - End-to-End Performance Test
    
    func testEndToEndPerformance() {
        let expectation = XCTestExpectation(description: "End-to-end test")
        
        Task {
            let report = await runEndToEndTest(duration: 60)
            
            print(report.summary)
            
            XCTAssertTrue(report.meetsRequirements,
                         "End-to-end performance does not meet requirements")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 70)
    }
    
    // MARK: - Helper Methods
    
    private func simulateTranscriptionOperation() async {
        // Simulate speech recognition processing
        let processingTime = Double.random(in: 0.020...0.040) // 20-40ms
        try? await Task.sleep(nanoseconds: UInt64(processingTime * 1_000_000_000))
    }
    
    private func simulateAudioBuffer(to engine: SpeechAnalyzerEngine) async {
        let buffer = createTestAudioBuffer()
        await engine.processAudioBuffer(buffer, at: AVAudioTime(hostTime: mach_absolute_time()))
    }
    
    private func createTestAudioBuffer() -> AVAudioPCMBuffer {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100,
            channels: 1,
            interleaved: false
        )!
        
        let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: 256
        )!
        
        buffer.frameLength = 256
        return buffer
    }
    
    private func runEndToEndTest(duration: TimeInterval) async -> PerformanceReport {
        let engine = SpeechAnalyzerEngine()
        let viewModel = TranscriptionViewModel()
        
        try? await engine.startTranscription()
        
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < duration {
            await simulateAudioBuffer(to: engine)
            try? await Task.sleep(nanoseconds: 5_800_000) // ~5.8ms (256 samples at 44.1kHz)
        }
        
        await engine.stopTranscription()
        
        return performanceMonitor.generatePerformanceReport()
    }
    
    private var testTranscriptionTexts: [String] {
        [
            "Hello world",
            "This is a test of the transcription system",
            "The quick brown fox jumps over the lazy dog",
            "Performance testing is important for real-time applications",
            "VoiceFlow provides high-quality voice transcription with low latency"
        ]
    }
}

// MARK: - Test App

class VoiceFlowTestApp {
    init() {
        // Initialize minimal app components
    }
}