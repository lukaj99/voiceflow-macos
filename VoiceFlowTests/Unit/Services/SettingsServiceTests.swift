import XCTest
@testable import VoiceFlow

/// Comprehensive tests for SettingsService with UserDefaults persistence
final class SettingsServiceTests: XCTestCase {

    private var settingsService: SettingsService!
    private let testSuiteName = "com.voiceflow.tests.settings"

    override func setUp() async throws {
        try await super.setUp()
        settingsService = SettingsService()

        // Clean up test UserDefaults
        if let testDefaults = UserDefaults(suiteName: testSuiteName) {
            testDefaults.removePersistentDomain(forName: testSuiteName)
        }
    }

    override func tearDown() async throws {
        await settingsService.resetAll()
        settingsService = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testSettingsServiceInitialization() async {
        // Then - service should be initialized
        XCTAssertNotNil(settingsService)
    }

    // MARK: - Get/Set Tests

    func testGetBooleanSetting() async throws {
        // When
        let value = try await settingsService.getBool(.launchAtLogin)

        // Then - should return default value
        XCTAssertFalse(value)
    }

    func testSetBooleanSetting() async throws {
        // When
        try await settingsService.setBool(.launchAtLogin, value: true)
        let value = try await settingsService.getBool(.launchAtLogin)

        // Then
        XCTAssertTrue(value)
    }

    func testGetStringSetting() async throws {
        // When
        let value = try await settingsService.getString(.transcriptionLanguage)

        // Then - should return default value
        XCTAssertEqual(value, "en-US")
    }

    func testSetStringSetting() async throws {
        // When
        try await settingsService.setString(.transcriptionLanguage, value: "es-ES")
        let value = try await settingsService.getString(.transcriptionLanguage)

        // Then
        XCTAssertEqual(value, "es-ES")
    }

    func testGetIntegerSetting() async throws {
        // When
        let value = try await settingsService.getInt(.fontSize)

        // Then - should return default value
        XCTAssertEqual(value, 14)
    }

    func testSetIntegerSetting() async throws {
        // When
        try await settingsService.setInt(.fontSize, value: 18)
        let value = try await settingsService.getInt(.fontSize)

        // Then
        XCTAssertEqual(value, 18)
    }

    func testGetDoubleSetting() async throws {
        // When
        let value = try await settingsService.getDouble(.audioLevel)

        // Then - should return default value
        XCTAssertEqual(value, 0.7, accuracy: 0.001)
    }

    func testSetDoubleSetting() async throws {
        // When
        try await settingsService.setDouble(.audioLevel, value: 0.9)
        let value = try await settingsService.getDouble(.audioLevel)

        // Then
        XCTAssertEqual(value, 0.9, accuracy: 0.001)
    }

    // MARK: - Default Values Tests

    func testDefaultValuesForAllSettings() async throws {
        // Given - test a sample of settings
        let boolSettings: [(SettingsService.SettingsKey, Bool)] = [
            (.launchAtLogin, false),
            (.showInDock, true),
            (.autoSave, true),
            (.noiseReduction, true),
            (.enableGlobalHotkeys, true)
        ]

        // When/Then
        for (key, expectedDefault) in boolSettings {
            let value = try await settingsService.getBool(key)
            XCTAssertEqual(value, expectedDefault, "Default value mismatch for \(key.rawValue)")
        }
    }

    func testStringDefaultValues() async throws {
        // Given
        let stringSettings: [(SettingsService.SettingsKey, String)] = [
            (.transcriptionLanguage, "en-US"),
            (.inputDevice, "Default"),
            (.theme, "system"),
            (.privacyMode, "balanced")
        ]

        // When/Then
        for (key, expectedDefault) in stringSettings {
            let value = try await settingsService.getString(key)
            XCTAssertEqual(value, expectedDefault, "Default value mismatch for \(key.rawValue)")
        }
    }

    // MARK: - Reset Tests

    func testResetSingleSetting() async throws {
        // Given
        try await settingsService.setBool(.launchAtLogin, value: true)
        XCTAssertTrue(try await settingsService.getBool(.launchAtLogin))

        // When
        await settingsService.reset(.launchAtLogin)

        // Then - should be back to default
        let value = try await settingsService.getBool(.launchAtLogin)
        XCTAssertFalse(value)
    }

    func testResetAllSettings() async throws {
        // Given - modify several settings
        try await settingsService.setBool(.launchAtLogin, value: true)
        try await settingsService.setString(.theme, value: "dark")
        try await settingsService.setInt(.fontSize, value: 20)

        // When
        await settingsService.resetAll()

        // Then - all should be back to defaults
        XCTAssertFalse(try await settingsService.getBool(.launchAtLogin))
        XCTAssertEqual(try await settingsService.getString(.theme), "system")
        XCTAssertEqual(try await settingsService.getInt(.fontSize), 14)
    }

    // MARK: - Bulk Operations Tests

    func testGetMultipleSettings() async {
        // Given
        let keys: [SettingsService.SettingsKey] = [
            .launchAtLogin,
            .theme,
            .fontSize
        ]

        // When
        let results = await settingsService.getMultiple(keys)

        // Then
        XCTAssertEqual(results.count, 3)
        XCTAssertNotNil(results[.launchAtLogin])
        XCTAssertNotNil(results[.theme])
        XCTAssertNotNil(results[.fontSize])
    }

    func testSetMultipleSettings() async throws {
        // Given
        let settings: [SettingsService.SettingsKey: Any] = [
            .launchAtLogin: true,
            .theme: "dark",
            .fontSize: 16
        ]

        // When
        try await settingsService.setMultiple(settings)

        // Then
        XCTAssertTrue(try await settingsService.getBool(.launchAtLogin))
        XCTAssertEqual(try await settingsService.getString(.theme), "dark")
        XCTAssertEqual(try await settingsService.getInt(.fontSize), 16)
    }

    // MARK: - Import/Export Tests

    func testExportSettings() async throws {
        // Given - set some custom values
        try await settingsService.setBool(.launchAtLogin, value: true)
        try await settingsService.setString(.theme, value: "dark")
        try await settingsService.setInt(.fontSize, value: 18)

        // When
        let exported = await settingsService.exportSettings()

        // Then
        XCTAssertGreaterThan(exported.count, 0)
        XCTAssertEqual(exported["launch_at_login"] as? Bool, true)
        XCTAssertEqual(exported["theme"] as? String, "dark")
        XCTAssertEqual(exported["font_size"] as? Int, 18)
    }

    func testImportSettings() async throws {
        // Given
        let settingsToImport: [String: Any] = [
            "launch_at_login": true,
            "theme": "light",
            "font_size": 20,
            "audio_level": 0.8
        ]

        // When
        try await settingsService.importSettings(settingsToImport)

        // Then
        XCTAssertTrue(try await settingsService.getBool(.launchAtLogin))
        XCTAssertEqual(try await settingsService.getString(.theme), "light")
        XCTAssertEqual(try await settingsService.getInt(.fontSize), 20)
        XCTAssertEqual(try await settingsService.getDouble(.audioLevel), 0.8, accuracy: 0.001)
    }

    func testImportSettingsWithInvalidKeys() async throws {
        // Given - mix of valid and invalid keys
        let settingsToImport: [String: Any] = [
            "launch_at_login": true,
            "invalid_key_123": "should be ignored",
            "theme": "dark"
        ]

        // When
        try await settingsService.importSettings(settingsToImport)

        // Then - valid settings should be imported
        XCTAssertTrue(try await settingsService.getBool(.launchAtLogin))
        XCTAssertEqual(try await settingsService.getString(.theme), "dark")
    }

    // MARK: - Type Safety Tests

    func testTypeMismatchError() async {
        // Given - set a string value
        try? await settingsService.setString(.theme, value: "dark")

        // When/Then - trying to get as wrong type should throw
        do {
            _ = try await settingsService.getInt(.theme)
            XCTFail("Should have thrown type mismatch error")
        } catch SettingsService.SettingsError.typeMismatch {
            // Expected error
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Caching Tests

    func testSettingsCaching() async throws {
        // Given
        try await settingsService.setBool(.launchAtLogin, value: true)

        // When - get the same setting multiple times
        let value1 = try await settingsService.getBool(.launchAtLogin)
        let value2 = try await settingsService.getBool(.launchAtLogin)
        let value3 = try await settingsService.getBool(.launchAtLogin)

        // Then - all should return the same cached value
        XCTAssertTrue(value1)
        XCTAssertTrue(value2)
        XCTAssertTrue(value3)
    }

    func testCacheInvalidationOnSet() async throws {
        // Given
        try await settingsService.setBool(.launchAtLogin, value: true)
        XCTAssertTrue(try await settingsService.getBool(.launchAtLogin))

        // When - update the setting
        try await settingsService.setBool(.launchAtLogin, value: false)

        // Then - should return new value, not cached
        XCTAssertFalse(try await settingsService.getBool(.launchAtLogin))
    }

    func testCacheInvalidationOnReset() async throws {
        // Given
        try await settingsService.setBool(.launchAtLogin, value: true)
        XCTAssertTrue(try await settingsService.getBool(.launchAtLogin))

        // When
        await settingsService.reset(.launchAtLogin)

        // Then - should return default value
        XCTAssertFalse(try await settingsService.getBool(.launchAtLogin))
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentReads() async throws {
        // Given
        try await settingsService.setBool(.launchAtLogin, value: true)

        // When - concurrent reads
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    return (try? await self.settingsService.getBool(.launchAtLogin)) ?? false
                }
            }

            // Then - all should succeed and return the same value
            for await result in group {
                XCTAssertTrue(result)
            }
        }
    }

    func testConcurrentWrites() async throws {
        // When - concurrent writes to different settings
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                try? await self.settingsService.setBool(.launchAtLogin, value: true)
            }
            group.addTask {
                try? await self.settingsService.setString(.theme, value: "dark")
            }
            group.addTask {
                try? await self.settingsService.setInt(.fontSize, value: 20)
            }
        }

        // Then - all writes should succeed
        XCTAssertTrue(try await settingsService.getBool(.launchAtLogin))
        XCTAssertEqual(try await settingsService.getString(.theme), "dark")
        XCTAssertEqual(try await settingsService.getInt(.fontSize), 20)
    }

    // MARK: - Settings Key Tests

    func testAllSettingsKeysHaveDefaults() {
        // When/Then - verify all keys have default values
        for key in SettingsService.SettingsKey.allCases {
            XCTAssertNotNil(key.defaultValue, "Missing default value for \(key.rawValue)")
        }
    }

    func testSettingsKeyRawValues() {
        // Given/When/Then - verify key naming convention
        XCTAssertEqual(SettingsService.SettingsKey.launchAtLogin.rawValue, "launch_at_login")
        XCTAssertEqual(SettingsService.SettingsKey.transcriptionLanguage.rawValue, "transcription_language")
        XCTAssertEqual(SettingsService.SettingsKey.audioLevel.rawValue, "audio_level")
    }

    // MARK: - Performance Tests

    func testGetSettingPerformance() async throws {
        // Given
        try await settingsService.setBool(.launchAtLogin, value: true)

        // When/Then
        measure {
            Task {
                _ = try? await self.settingsService.getBool(.launchAtLogin)
            }
        }
    }

    func testSetSettingPerformance() {
        measure {
            Task {
                try? await self.settingsService.setBool(.launchAtLogin, value: true)
            }
        }
    }

    func testBulkExportPerformance() async throws {
        // Given - populate settings
        try await settingsService.setBool(.launchAtLogin, value: true)
        try await settingsService.setString(.theme, value: "dark")
        try await settingsService.setInt(.fontSize, value: 16)

        // When/Then
        measure {
            Task {
                _ = await self.settingsService.exportSettings()
            }
        }
    }

    func testBulkImportPerformance() {
        // Given
        let settings: [String: Any] = [
            "launch_at_login": true,
            "theme": "dark",
            "font_size": 16,
            "audio_level": 0.8,
            "window_opacity": 0.95
        ]

        // When/Then
        measure {
            Task {
                try? await self.settingsService.importSettings(settings)
            }
        }
    }
}
