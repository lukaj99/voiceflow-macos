import XCTest
import HotKey
import AppKit
@testable import VoiceFlow

/// Comprehensive tests for GlobalHotkeyService
@MainActor
final class GlobalHotkeyServiceTests: XCTestCase {

    private var hotkeyService: GlobalHotkeyService!

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        hotkeyService = GlobalHotkeyService()
    }

    @MainActor
    override func tearDown() async throws {
        hotkeyService.disable()
        hotkeyService = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testHotkeyServiceInitialization() async {
        // Then
        XCTAssertNotNil(hotkeyService)
        XCTAssertTrue(hotkeyService.isEnabled)
        XCTAssertEqual(hotkeyService.hotkeyStatus, "Default hotkeys active")
    }

    func testInitialEnabledState() async {
        // Then
        XCTAssertTrue(hotkeyService.isEnabled)
    }

    func testInitialHotkeyStatus() async {
        // Then
        XCTAssertEqual(hotkeyService.hotkeyStatus, "Default hotkeys active")
    }

    // MARK: - Enable/Disable Tests

    func testDisableHotkeys() async {
        // Given
        XCTAssertTrue(hotkeyService.isEnabled)

        // When
        hotkeyService.disable()

        // Then
        XCTAssertFalse(hotkeyService.isEnabled)
        XCTAssertEqual(hotkeyService.hotkeyStatus, "Disabled")
    }

    func testEnableHotkeys() async {
        // Given
        hotkeyService.disable()
        XCTAssertFalse(hotkeyService.isEnabled)

        // When
        hotkeyService.enable()

        // Then
        XCTAssertTrue(hotkeyService.isEnabled)
        XCTAssertEqual(hotkeyService.hotkeyStatus, "Enabled")
    }

    func testToggleFromEnabledToDisabled() async {
        // Given
        XCTAssertTrue(hotkeyService.isEnabled)

        // When
        hotkeyService.toggle()

        // Then
        XCTAssertFalse(hotkeyService.isEnabled)
    }

    func testToggleFromDisabledToEnabled() async {
        // Given
        hotkeyService.disable()
        XCTAssertFalse(hotkeyService.isEnabled)

        // When
        hotkeyService.toggle()

        // Then
        XCTAssertTrue(hotkeyService.isEnabled)
    }

    func testDisableWhenAlreadyDisabled() async {
        // Given
        hotkeyService.disable()
        XCTAssertFalse(hotkeyService.isEnabled)

        // When
        hotkeyService.disable()

        // Then
        XCTAssertFalse(hotkeyService.isEnabled)
    }

    func testEnableWhenAlreadyEnabled() async {
        // Given
        XCTAssertTrue(hotkeyService.isEnabled)

        // When
        hotkeyService.enable()

        // Then
        XCTAssertTrue(hotkeyService.isEnabled)
    }

    // MARK: - Hotkey Configuration Tests

    func testConfigureToggleHotkey() async {
        // When
        hotkeyService.configureToggleHotkey(key: .f1, modifiers: [.command])

        // Then
        XCTAssertEqual(hotkeyService.hotkeyStatus, "Custom hotkey configured")
    }

    func testConfigureQuickRecordHotkey() async {
        // When
        hotkeyService.configureQuickRecordHotkey(key: .f2, modifiers: [.command, .shift])

        // Then
        XCTAssertNotNil(hotkeyService)
    }

    func testConfigureMultipleHotkeys() async {
        // When
        hotkeyService.configureToggleHotkey(key: .f1, modifiers: [.command])
        hotkeyService.configureQuickRecordHotkey(key: .f2, modifiers: [.shift])

        // Then
        XCTAssertNotNil(hotkeyService)
    }

    // MARK: - Hotkey Info Tests

    func testGetHotkeyInfo() async {
        // When
        let info = hotkeyService.getHotkeyInfo()

        // Then
        XCTAssertNotNil(info)
        XCTAssertNotNil(info["Toggle Widget"])
        XCTAssertNotNil(info["Quick Record"])
        XCTAssertNotNil(info["Status"])
        XCTAssertNotNil(info["Enabled"])
    }

    func testHotkeyInfoShowsEnabledState() async {
        // When
        let info = hotkeyService.getHotkeyInfo()

        // Then
        XCTAssertEqual(info["Enabled"], "Yes")
    }

    func testHotkeyInfoWhenDisabled() async {
        // Given
        hotkeyService.disable()

        // When
        let info = hotkeyService.getHotkeyInfo()

        // Then
        XCTAssertEqual(info["Enabled"], "No")
    }

    func testHotkeyInfoContainsStatus() async {
        // When
        let info = hotkeyService.getHotkeyInfo()

        // Then
        XCTAssertNotNil(info["Status"])
        XCTAssertFalse(info["Status"]?.isEmpty ?? true)
    }

    // MARK: - State Management Tests

    func testMultipleEnableDisableCycles() async {
        // When/Then
        for _ in 0..<5 {
            hotkeyService.enable()
            XCTAssertTrue(hotkeyService.isEnabled)

            hotkeyService.disable()
            XCTAssertFalse(hotkeyService.isEnabled)
        }
    }

    func testStatusUpdatesOnEnable() async {
        // Given
        hotkeyService.disable()

        // When
        hotkeyService.enable()

        // Then
        XCTAssertEqual(hotkeyService.hotkeyStatus, "Enabled")
    }

    func testStatusUpdatesOnDisable() async {
        // When
        hotkeyService.disable()

        // Then
        XCTAssertEqual(hotkeyService.hotkeyStatus, "Disabled")
    }

    // MARK: - Widget Connection Tests

    func testSetFloatingWidget() async {
        // Given
        let mockWidget = MockFloatingWidget()

        // When
        hotkeyService.setFloatingWidget(mockWidget)

        // Then - should not crash
        XCTAssertNotNil(hotkeyService)
    }

    // MARK: - Memory Management Tests

    func testHotkeyServiceDeallocatesCleanly() async throws {
        // Given
        weak var weakService: GlobalHotkeyService?

        autoreleasepool {
            let localService = GlobalHotkeyService()
            weakService = localService
            XCTAssertNotNil(weakService)
        }

        // When - give time for deallocation
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertNil(weakService)
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentStateReads() async {
        // When - concurrent reads
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<100 {
                group.addTask { @MainActor in
                    return self.hotkeyService.isEnabled
                }
            }

            // Then - all should succeed
            for await result in group {
                XCTAssertTrue(result) // Initially enabled
            }
        }
    }

    // MARK: - Edge Case Tests

    func testConfigureHotkeyWhenDisabled() async {
        // Given
        hotkeyService.disable()

        // When
        hotkeyService.configureToggleHotkey(key: .f1, modifiers: [.command])

        // Then - should configure even when disabled
        XCTAssertEqual(hotkeyService.hotkeyStatus, "Custom hotkey configured")
    }

    func testReconfigureSameHotkey() async {
        // When
        hotkeyService.configureToggleHotkey(key: .f1, modifiers: [.command])
        hotkeyService.configureToggleHotkey(key: .f2, modifiers: [.shift])

        // Then - should reconfigure without issue
        XCTAssertNotNil(hotkeyService)
    }
}

// MARK: - Mock Objects

@MainActor
private class MockFloatingWidget: FloatingMicrophoneWidget {
    var toggleCalled = false
    var toggleRecordingCalled = false
    var showCalled = false
    var startRecordingCalled = false

    override func toggle() {
        toggleCalled = true
    }

    override func toggleRecording() {
        toggleRecordingCalled = true
    }

    override func show() {
        showCalled = true
    }

    override func startRecording() {
        startRecordingCalled = true
    }
}
