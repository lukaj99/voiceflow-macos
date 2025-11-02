import XCTest
@testable import VoiceFlow

/// Tests for SettingsService validation logic
final class SettingsValidationTests: XCTestCase {

    private var settingsService: SettingsService!

    override func setUp() async throws {
        try await super.setUp()
        settingsService = SettingsService()
    }

    override func tearDown() async throws {
        await settingsService.resetAll()
        settingsService = nil
        try await super.tearDown()
    }

    // MARK: - Audio Level Validation Tests

    func testAudioLevelValidRange() async throws {
        // When/Then - valid values should succeed
        try await settingsService.setDouble(.audioLevel, value: 0.0)
        try await settingsService.setDouble(.audioLevel, value: 0.5)
        try await settingsService.setDouble(.audioLevel, value: 1.0)

        // Verify
        let value = try await settingsService.getDouble(.audioLevel)
        XCTAssertEqual(value, 1.0, accuracy: 0.001)
    }

    func testAudioLevelBelowRange() async {
        // When/Then - below minimum should throw
        do {
            try await settingsService.setDouble(.audioLevel, value: -0.1)
            XCTFail("Should have thrown validation error")
        } catch SettingsService.SettingsError.invalidValue {
            // Expected error
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testAudioLevelAboveRange() async {
        // When/Then - above maximum should throw
        do {
            try await settingsService.setDouble(.audioLevel, value: 1.5)
            XCTFail("Should have thrown validation error")
        } catch SettingsService.SettingsError.invalidValue {
            // Expected error
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Auto-Save Interval Validation Tests

    func testAutoSaveIntervalValidRange() async throws {
        // When/Then - valid values should succeed
        try await settingsService.setDouble(.autoSaveInterval, value: 5.0)
        try await settingsService.setDouble(.autoSaveInterval, value: 30.0)
        try await settingsService.setDouble(.autoSaveInterval, value: 300.0)

        // Verify
        let value = try await settingsService.getDouble(.autoSaveInterval)
        XCTAssertEqual(value, 300.0, accuracy: 0.001)
    }

    func testAutoSaveIntervalTooSmall() async {
        // When/Then - below minimum should throw
        do {
            try await settingsService.setDouble(.autoSaveInterval, value: 2.0)
            XCTFail("Should have thrown validation error")
        } catch SettingsService.SettingsError.invalidValue(let message) {
            XCTAssertTrue(message.contains("at least 5 seconds"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Font Size Validation Tests

    func testFontSizeValidRange() async throws {
        // When/Then - valid values should succeed
        try await settingsService.setInt(.fontSize, value: 8)
        try await settingsService.setInt(.fontSize, value: 14)
        try await settingsService.setInt(.fontSize, value: 72)

        // Verify
        let value = try await settingsService.getInt(.fontSize)
        XCTAssertEqual(value, 72)
    }

    func testFontSizeTooSmall() async {
        // When/Then
        do {
            try await settingsService.setInt(.fontSize, value: 4)
            XCTFail("Should have thrown validation error")
        } catch SettingsService.SettingsError.invalidValue(let message) {
            XCTAssertTrue(message.contains("between 8 and 72"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testFontSizeTooLarge() async {
        // When/Then
        do {
            try await settingsService.setInt(.fontSize, value: 100)
            XCTFail("Should have thrown validation error")
        } catch SettingsService.SettingsError.invalidValue(let message) {
            XCTAssertTrue(message.contains("between 8 and 72"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Window Opacity Validation Tests

    func testWindowOpacityValidRange() async throws {
        // When/Then - valid values should succeed
        try await settingsService.setDouble(.windowOpacity, value: 0.1)
        try await settingsService.setDouble(.windowOpacity, value: 0.5)
        try await settingsService.setDouble(.windowOpacity, value: 1.0)

        // Verify
        let value = try await settingsService.getDouble(.windowOpacity)
        XCTAssertEqual(value, 1.0, accuracy: 0.001)
    }

    func testWindowOpacityTooLow() async {
        // When/Then
        do {
            try await settingsService.setDouble(.windowOpacity, value: 0.05)
            XCTFail("Should have thrown validation error")
        } catch SettingsService.SettingsError.invalidValue(let message) {
            XCTAssertTrue(message.contains("between 0.1 and 1.0"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testWindowOpacityTooHigh() async {
        // When/Then
        do {
            try await settingsService.setDouble(.windowOpacity, value: 1.5)
            XCTFail("Should have thrown validation error")
        } catch SettingsService.SettingsError.invalidValue {
            // Expected error
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Processing Threads Validation Tests

    func testProcessingThreadsValidRange() async throws {
        // When/Then - valid values should succeed
        try await settingsService.setInt(.processingThreads, value: 1)
        try await settingsService.setInt(.processingThreads, value: 4)
        try await settingsService.setInt(.processingThreads, value: 16)

        // Verify
        let value = try await settingsService.getInt(.processingThreads)
        XCTAssertEqual(value, 16)
    }

    func testProcessingThreadsTooFew() async {
        // When/Then
        do {
            try await settingsService.setInt(.processingThreads, value: 0)
            XCTFail("Should have thrown validation error")
        } catch SettingsService.SettingsError.invalidValue(let message) {
            XCTAssertTrue(message.contains("between 1 and 16"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testProcessingThreadsTooMany() async {
        // When/Then
        do {
            try await settingsService.setInt(.processingThreads, value: 32)
            XCTFail("Should have thrown validation error")
        } catch SettingsService.SettingsError.invalidValue {
            // Expected error
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Network Timeout Validation Tests

    func testNetworkTimeoutValidRange() async throws {
        // When/Then - valid values should succeed
        try await settingsService.setDouble(.networkTimeout, value: 5.0)
        try await settingsService.setDouble(.networkTimeout, value: 30.0)
        try await settingsService.setDouble(.networkTimeout, value: 300.0)

        // Verify
        let value = try await settingsService.getDouble(.networkTimeout)
        XCTAssertEqual(value, 300.0, accuracy: 0.001)
    }

    func testNetworkTimeoutTooShort() async {
        // When/Then
        do {
            try await settingsService.setDouble(.networkTimeout, value: 2.0)
            XCTFail("Should have thrown validation error")
        } catch SettingsService.SettingsError.invalidValue(let message) {
            XCTAssertTrue(message.contains("between 5 and 300 seconds"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testNetworkTimeoutTooLong() async {
        // When/Then
        do {
            try await settingsService.setDouble(.networkTimeout, value: 500.0)
            XCTFail("Should have thrown validation error")
        } catch SettingsService.SettingsError.invalidValue {
            // Expected error
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Settings Without Validation Tests

    func testUnvalidatedBooleanSettings() async throws {
        // When/Then - these should accept any boolean value
        try await settingsService.setBool(.launchAtLogin, value: true)
        try await settingsService.setBool(.showInDock, value: false)
        try await settingsService.setBool(.enableGlobalHotkeys, value: true)

        // Verify
        XCTAssertTrue(try await settingsService.getBool(.launchAtLogin))
        XCTAssertFalse(try await settingsService.getBool(.showInDock))
        XCTAssertTrue(try await settingsService.getBool(.enableGlobalHotkeys))
    }

    func testUnvalidatedStringSettings() async throws {
        // When/Then - these should accept any string value
        try await settingsService.setString(.theme, value: "custom")
        try await settingsService.setString(.transcriptionLanguage, value: "de-DE")
        try await settingsService.setString(.privacyMode, value: "maximum")

        // Verify
        XCTAssertEqual(try await settingsService.getString(.theme), "custom")
        XCTAssertEqual(try await settingsService.getString(.transcriptionLanguage), "de-DE")
    }

    // MARK: - Bulk Validation Tests

    func testBulkSetWithMixedValidation() async throws {
        // Given - mix of valid and invalid values
        let settings: [SettingsService.SettingsKey: Any] = [
            .launchAtLogin: true, // Valid
            .audioLevel: 0.5,     // Valid
            .fontSize: 150        // Invalid - too large
        ]

        // When/Then - should fail due to invalid value
        do {
            try await settingsService.setMultiple(settings)
            XCTFail("Should have thrown validation error")
        } catch SettingsService.SettingsError.invalidValue {
            // Expected - none of the settings should be applied
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testBulkSetWithAllValidValues() async throws {
        // Given - all valid values
        let settings: [SettingsService.SettingsKey: Any] = [
            .launchAtLogin: true,
            .audioLevel: 0.8,
            .fontSize: 16,
            .windowOpacity: 0.95
        ]

        // When
        try await settingsService.setMultiple(settings)

        // Then - all should be set
        XCTAssertTrue(try await settingsService.getBool(.launchAtLogin))
        XCTAssertEqual(try await settingsService.getDouble(.audioLevel), 0.8, accuracy: 0.001)
        XCTAssertEqual(try await settingsService.getInt(.fontSize), 16)
        XCTAssertEqual(try await settingsService.getDouble(.windowOpacity), 0.95, accuracy: 0.001)
    }

    // MARK: - Edge Case Tests

    func testValidationWithBoundaryValues() async throws {
        // Test exact boundary values
        try await settingsService.setDouble(.audioLevel, value: 0.0) // Min
        XCTAssertEqual(try await settingsService.getDouble(.audioLevel), 0.0, accuracy: 0.001)

        try await settingsService.setDouble(.audioLevel, value: 1.0) // Max
        XCTAssertEqual(try await settingsService.getDouble(.audioLevel), 1.0, accuracy: 0.001)

        try await settingsService.setInt(.fontSize, value: 8) // Min
        XCTAssertEqual(try await settingsService.getInt(.fontSize), 8)

        try await settingsService.setInt(.fontSize, value: 72) // Max
        XCTAssertEqual(try await settingsService.getInt(.fontSize), 72)
    }

    func testValidationWithNearBoundaryValues() async throws {
        // Test values just inside boundaries
        try await settingsService.setDouble(.audioLevel, value: 0.01)
        XCTAssertEqual(try await settingsService.getDouble(.audioLevel), 0.01, accuracy: 0.001)

        try await settingsService.setDouble(.audioLevel, value: 0.99)
        XCTAssertEqual(try await settingsService.getDouble(.audioLevel), 0.99, accuracy: 0.001)
    }

    // MARK: - Error Message Tests

    func testErrorMessageClarity() async {
        // Test that error messages are descriptive
        do {
            try await settingsService.setInt(.fontSize, value: 200)
            XCTFail("Should have thrown error")
        } catch SettingsService.SettingsError.invalidValue(let message) {
            XCTAssertTrue(message.contains("Font size"))
            XCTAssertTrue(message.contains("8"))
            XCTAssertTrue(message.contains("72"))
        } catch {
            XCTFail("Wrong error type")
        }
    }

    // MARK: - Performance Tests

    func testValidationPerformance() {
        measure {
            Task {
                // Test multiple validated settings
                _ = try? await self.settingsService.setDouble(.audioLevel, value: 0.7)
                _ = try? await self.settingsService.setInt(.fontSize, value: 14)
                _ = try? await self.settingsService.setDouble(.windowOpacity, value: 0.95)
                _ = try? await self.settingsService.setInt(.processingThreads, value: 4)
            }
        }
    }
}
