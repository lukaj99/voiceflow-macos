import XCTest
import AppKit
import Combine
@testable import VoiceFlowUI

class MenuBarControllerTests: XCTestCase {
    var controller: MenuBarController!
    var transcriptionViewModel: TranscriptionViewModel!
    
    override func setUp() {
        super.setUp()
        transcriptionViewModel = TranscriptionViewModel()
        controller = MenuBarController(viewModel: transcriptionViewModel)
    }
    
    override func tearDown() {
        controller = nil
        transcriptionViewModel = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testMenuBarInitialization() {
        XCTAssertNotNil(controller.statusItem)
        XCTAssertNotNil(controller.menu)
        XCTAssertNotNil(controller.statusItem.button)
    }
    
    func testMenuStructure() {
        // Verify menu items
        let menuItems = controller.menu.items
        
        // Should have: Start/Stop, separator, Settings, separator, Quit
        XCTAssertEqual(menuItems.count, 5)
        
        // Check specific items
        XCTAssertEqual(menuItems[0].tag, MenuBarController.Tags.startStop)
        XCTAssertTrue(menuItems[1].isSeparatorItem)
        XCTAssertEqual(menuItems[2].tag, MenuBarController.Tags.settings)
        XCTAssertTrue(menuItems[3].isSeparatorItem)
        XCTAssertEqual(menuItems[4].tag, MenuBarController.Tags.quit)
    }
    
    func testStatusItemIcon() {
        guard let button = controller.statusItem.button else {
            XCTFail("Status item button should exist")
            return
        }
        
        XCTAssertNotNil(button.image)
        XCTAssertEqual(button.image?.accessibilityDescription, "VoiceFlow")
    }
    
    // MARK: - Global Hotkey Tests
    
    func testGlobalHotkeyRegistration() {
        let registered = controller.registerGlobalHotkey()
        XCTAssertTrue(registered)
        
        // Verify hotkey configuration
        XCTAssertNotNil(controller.hotKey)
        XCTAssertEqual(controller.hotKey?.keyCombo?.key, .space)
        XCTAssertTrue(controller.hotKey?.keyCombo?.modifiers.contains(.command) ?? false)
        XCTAssertTrue(controller.hotKey?.keyCombo?.modifiers.contains(.option) ?? false)
    }
    
    func testHotkeyTogglesFunctionality() {
        _ = controller.registerGlobalHotkey()
        
        // Simulate hotkey press
        controller.handleHotkeyPress()
        
        // Should toggle transcription
        XCTAssertTrue(transcriptionViewModel.isTranscribing)
        
        // Press again to stop
        controller.handleHotkeyPress()
        XCTAssertFalse(transcriptionViewModel.isTranscribing)
    }
    
    // MARK: - Menu Item State Tests
    
    func testMenuItemStatesWhenTranscribing() {
        transcriptionViewModel.isTranscribing = true
        controller.updateMenuItems()
        
        let startStopItem = controller.menu.item(withTag: MenuBarController.Tags.startStop)
        XCTAssertEqual(startStopItem?.title, "Stop Transcription")
        
        // Icon should be filled
        guard let button = controller.statusItem.button else { return }
        XCTAssertEqual(button.image?.name(), "mic.circle.fill")
    }
    
    func testMenuItemStatesWhenNotTranscribing() {
        transcriptionViewModel.isTranscribing = false
        controller.updateMenuItems()
        
        let startStopItem = controller.menu.item(withTag: MenuBarController.Tags.startStop)
        XCTAssertEqual(startStopItem?.title, "Start Transcription")
        
        // Icon should not be filled
        guard let button = controller.statusItem.button else { return }
        XCTAssertEqual(button.image?.name(), "mic.circle")
    }
    
    // MARK: - Audio Level Animation Tests
    
    func testAudioLevelAnimation() {
        let expectation = XCTestExpectation(description: "Audio level animation")
        
        // Start transcription
        transcriptionViewModel.isTranscribing = true
        
        // Simulate audio level changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.transcriptionViewModel.currentAudioLevel = 0.5
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.transcriptionViewModel.currentAudioLevel = 0.8
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Verify icon updates (would need to check actual animation frames)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Menu Actions Tests
    
    func testToggleTranscriptionAction() {
        let startStopItem = controller.menu.item(withTag: MenuBarController.Tags.startStop)
        
        // Start transcription
        controller.toggleTranscription(startStopItem)
        XCTAssertTrue(transcriptionViewModel.isTranscribing)
        
        // Stop transcription
        controller.toggleTranscription(startStopItem)
        XCTAssertFalse(transcriptionViewModel.isTranscribing)
    }
    
    func testOpenSettingsAction() {
        let settingsItem = controller.menu.item(withTag: MenuBarController.Tags.settings)
        
        // Mock window controller
        let windowOpened = expectation(description: "Settings window opened")
        controller.onSettingsOpen = {
            windowOpened.fulfill()
        }
        
        controller.openSettings(settingsItem)
        wait(for: [windowOpened], timeout: 1.0)
    }
    
    func testQuitAction() {
        let quitItem = controller.menu.item(withTag: MenuBarController.Tags.quit)
        
        let appTerminated = expectation(description: "App terminated")
        controller.onQuit = {
            appTerminated.fulfill()
        }
        
        controller.quit(quitItem)
        wait(for: [appTerminated], timeout: 1.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorNotification() {
        let error = VoiceFlowError.microphonePermissionDenied
        controller.showError(error)
        
        // Verify error shown in menu
        let errorItem = controller.menu.item(withTag: MenuBarController.Tags.error)
        XCTAssertNotNil(errorItem)
        XCTAssertTrue(errorItem?.title.contains("Microphone access") ?? false)
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryManagement() {
        weak var weakController = controller
        
        controller = nil
        
        XCTAssertNil(weakController)
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabels() {
        let startStopItem = controller.menu.item(withTag: MenuBarController.Tags.startStop)
        XCTAssertNotNil(startStopItem?.accessibilityLabel)
        
        let settingsItem = controller.menu.item(withTag: MenuBarController.Tags.settings)
        XCTAssertNotNil(settingsItem?.accessibilityLabel)
        
        guard let button = controller.statusItem.button else { return }
        XCTAssertNotNil(button.accessibilityLabel)
    }
}

// MARK: - Mock View Model

class TranscriptionViewModel: ObservableObject {
    @Published var isTranscribing = false
    @Published var currentAudioLevel: Float = 0
    @Published var transcribedText = ""
    @Published var error: Error?
}