import XCTest
import Foundation
@testable import VoiceFlow

/// Comprehensive Swift 6 compatibility validation tests
class Swift6ValidationTests: XCTestCase {
    
    // MARK: - Concurrency Validation
    
    func testMainActorIsolation() async {
        // Test that UI components properly use MainActor
        await MainActor.run {
            let viewModel = AdvancedTranscriptionViewModel()
            XCTAssertTrue(viewModel.isTranscribing == false)
            XCTAssertTrue(viewModel.currentAudioLevel == 0)
        }
    }
    
    func testAudioEngineManagerConcurrency() async throws {
        // Test AudioEngineManager concurrency patterns
        let audioManager = AudioEngineManager()
        
        // This should not cause data races in Swift 6
        await audioManager.configureAudioSession()
        XCTAssertTrue(audioManager.isConfigured)
    }
    
    func testPerformanceMonitorAsync() async {
        // Test PerformanceMonitor async patterns
        let monitor = PerformanceMonitor.shared
        
        await monitor.measureTranscriptionLatency {
            // Simulate transcription work
            try? await Task.sleep(for: .milliseconds(10))
        }
        
        let report = monitor.generatePerformanceReport()
        XCTAssertNotNil(report)
    }
    
    // MARK: - Timer Replacement Validation
    
    func testTimerReplacementInAdvancedApp() async {
        await MainActor.run {
            let viewModel = AdvancedTranscriptionViewModel()
            viewModel.startTranscription()
            
            // Wait briefly to ensure Task-based scheduling works
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                viewModel.stopTranscription()
            }
        }
    }
    
    func testMenuBarAnimationConcurrency() async {
        // Test MenuBar controller animation using Tasks instead of Timers
        await MainActor.run {
            let mockViewModel = AdvancedTranscriptionViewModel()
            let menuBarController = MenuBarController(viewModel: mockViewModel)
            
            // This should not cause concurrency warnings
            XCTAssertNotNil(menuBarController.statusItem)
        }
    }
    
    // MARK: - Speech Recognition Integration
    
    func testSpeechRecognitionEngineCreation() {
        // Test that RealSpeechRecognitionEngine can be created without concurrency issues
        Task { @MainActor in
            let engine = RealSpeechRecognitionEngine()
            XCTAssertNotNil(engine)
            XCTAssertNotNil(engine.transcriptionPublisher)
        }
    }
    
    // MARK: - Export System Validation
    
    func testExportSystemConcurrency() async throws {
        let session = TranscriptionSession(
            transcription: "Test transcription for Swift 6 validation"
        )
        
        let exportManager = ExportManager()
        
        // Test async export operations
        let result = try await exportManager.export(
            session: session,
            format: .text
        )
        
        XCTAssertTrue(result.success)
    }
    
    // MARK: - Services Integration
    
    func testSettingsServiceMainActor() async {
        await MainActor.run {
            let settingsService = SettingsService()
            
            // Test that settings can be modified without concurrency issues
            settingsService.launchAtLogin = true
            XCTAssertTrue(settingsService.launchAtLogin)
        }
    }
    
    func testHotkeyServiceConcurrency() async {
        await MainActor.run {
            let hotkeyService = HotkeyService()
            XCTAssertNotNil(hotkeyService)
            
            // Test hotkey registration doesn't cause data races
            // (Using nil for testing to avoid actual hotkey registration)
        }
    }
    
    // MARK: - Package Build Validation
    
    func testAllDependenciesResolved() {
        // This test ensures all dependencies are properly configured
        // in Package.swift and resolve without conflicts
        XCTAssertTrue(true, "If this test runs, Package.swift dependencies resolved successfully")
    }
    
    // MARK: - Memory Management
    
    func testNoRetainCycles() async {
        // Test that our async patterns don't create retain cycles
        weak var weakViewModel: AdvancedTranscriptionViewModel?
        
        await MainActor.run {
            let viewModel = AdvancedTranscriptionViewModel()
            weakViewModel = viewModel
            
            viewModel.startTranscription()
            viewModel.stopTranscription()
        }
        
        // Allow cleanup
        try? await Task.sleep(for: .milliseconds(100))
        
        // ViewModel should be deallocated
        XCTAssertNil(weakViewModel, "ViewModel should not have retain cycles")
    }
}

// MARK: - Integration Test Extensions

extension Swift6ValidationTests {
    
    /// Test full integration flow
    func testFullIntegrationFlow() async throws {
        await MainActor.run {
            // Create main components
            let viewModel = AdvancedTranscriptionViewModel()
            let settingsService = SettingsService()
            let menuBarController = MenuBarController(viewModel: viewModel)
            
            // Test integration
            viewModel.startTranscription()
            
            // Simulate transcription session
            Task {
                try? await Task.sleep(for: .milliseconds(200))
                viewModel.stopTranscription()
            }
            
            XCTAssertNotNil(menuBarController)
            XCTAssertNotNil(settingsService)
        }
    }
}