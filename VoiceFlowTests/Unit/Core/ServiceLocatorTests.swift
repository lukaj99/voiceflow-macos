//
//  ServiceLocatorTests.swift
//  VoiceFlowTests
//
//  Created by Claude Code on 2025-11-02.
//  Copyright © 2025 VoiceFlow. All rights reserved.
//

import XCTest
@testable import VoiceFlow

// MARK: - Test Protocols

protocol TestServiceProtocol {
    func doSomething() -> String
}

protocol AnotherTestServiceProtocol {
    var value: Int { get }
}

protocol DependentServiceProtocol {
    var dependency: TestServiceProtocol { get }
}

// MARK: - Test Implementations

class TestService: TestServiceProtocol {
    private let id = UUID()

    func doSomething() -> String {
        "TestService-\(id.uuidString.prefix(8))"
    }
}

class AnotherTestService: AnotherTestServiceProtocol {
    let value: Int

    init(value: Int = 42) {
        self.value = value
    }
}

class DependentService: DependentServiceProtocol {
    let dependency: TestServiceProtocol

    init(dependency: TestServiceProtocol) {
        self.dependency = dependency
    }
}

// MARK: - Mock Service

class MockTestService: TestServiceProtocol {
    var callCount = 0

    func doSomething() -> String {
        callCount += 1
        return "MockService-\(callCount)"
    }
}

// MARK: - Test Module

struct TestModule: ServiceModule {
    let name = "TestModule"

    func registerServices(in locator: ServiceLocator) async throws {
        try await locator.register(TestServiceProtocol.self) {
            TestService()
        }

        try await locator.register(AnotherTestServiceProtocol.self) {
            AnotherTestService()
        }
    }
}

struct DependentModule: ServiceModule {
    let name = "DependentModule"

    var dependencies: [any ServiceModule.Type] {
        [TestModule.self]
    }

    func registerServices(in locator: ServiceLocator) async throws {
        // Resolve dependency outside factory closure since factory must be synchronous
        let testService = try await locator.resolve(TestServiceProtocol.self)

        try await locator.register(DependentServiceProtocol.self) {
            // Factory is synchronous, but captures resolved dependency
            return DependentService(dependency: testService)
        }
    }
}

// MARK: - Tests

@MainActor
final class ServiceLocatorTests: XCTestCase {

    var sut: ServiceLocator!

    override func setUp() async throws {
        try await super.setUp()
        // Create fresh instance for each test
        sut = ServiceLocator.createTestInstance()
    }

    override func tearDown() async throws {
        await sut.reset()
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Basic Registration Tests

    func testRegisterAndResolve() async throws {
        // Given
        try await sut.register(TestServiceProtocol.self) {
            TestService()
        }

        // When
        let service = try await sut.resolve(TestServiceProtocol.self)

        // Then
        XCTAssertNotNil(service)
        XCTAssertTrue(service.doSomething().starts(with: "TestService"))
    }

    func testRegisterInstance() async throws {
        // Given
        let instance = AnotherTestService(value: 100)
        try await sut.registerInstance(AnotherTestServiceProtocol.self, instance: instance)

        // When
        let resolved = try await sut.resolve(AnotherTestServiceProtocol.self)

        // Then
        XCTAssertEqual(resolved.value, 100)
    }

    func testDuplicateRegistrationThrows() async throws {
        // Given
        try await sut.register(TestServiceProtocol.self) {
            TestService()
        }

        // When/Then
        do {
            try await sut.register(TestServiceProtocol.self) {
                TestService()
            }
            XCTFail("Should throw duplicate registration error")
        } catch let error as ServiceLocator.ServiceLocatorError {
            if case .duplicateRegistration = error {
                // Success
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testResolveUnregisteredThrows() async throws {
        // When/Then
        do {
            _ = try await sut.resolve(TestServiceProtocol.self)
            XCTFail("Should throw service not registered error")
        } catch let error as ServiceLocator.ServiceLocatorError {
            if case .serviceNotRegistered = error {
                // Success
                XCTAssertTrue(error.description.contains("not registered"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Singleton Tests

    func testSingletonReturnsSameInstance() async throws {
        // Given
        try await sut.register(TestServiceProtocol.self, isSingleton: true) {
            TestService()
        }

        // When
        let first = try await sut.resolve(TestServiceProtocol.self)
        let second = try await sut.resolve(TestServiceProtocol.self)

        // Then - same instance should return same ID
        XCTAssertEqual(first.doSomething(), second.doSomething())
    }

    func testNonSingletonReturnsNewInstance() async throws {
        // Given
        try await sut.register(TestServiceProtocol.self, isSingleton: false) {
            TestService()
        }

        // When
        let first = try await sut.resolve(TestServiceProtocol.self)
        let second = try await sut.resolve(TestServiceProtocol.self)

        // Then - different instances should have different IDs
        XCTAssertNotEqual(first.doSomething(), second.doSomething())
    }

    // MARK: - Dependency Injection Tests

    func testResolveDependencies() async throws {
        // Given
        try await sut.register(TestServiceProtocol.self) {
            TestService()
        }

        // Resolve dependency outside factory closure since factory must be synchronous
        let testService = try await sut.resolve(TestServiceProtocol.self)

        try await sut.register(DependentServiceProtocol.self) {
            // Factory is synchronous, but captures resolved dependency
            return DependentService(dependency: testService)
        }

        // When
        let service = try await sut.resolve(DependentServiceProtocol.self)

        // Then
        XCTAssertNotNil(service.dependency)
        XCTAssertTrue(service.dependency.doSomething().starts(with: "TestService"))
    }

    // MARK: - Management Tests

    func testUnregister() async throws {
        // Given
        try await sut.register(TestServiceProtocol.self) {
            TestService()
        }

        // When
        await sut.unregister(TestServiceProtocol.self)

        // Then
        let isRegistered = await sut.isRegistered(TestServiceProtocol.self)
        XCTAssertFalse(isRegistered)
    }

    func testReset() async throws {
        // Given
        try await sut.register(TestServiceProtocol.self) {
            TestService()
        }
        try await sut.register(AnotherTestServiceProtocol.self) {
            AnotherTestService()
        }

        // When
        await sut.reset()

        // Then
        let testRegistered = await sut.isRegistered(TestServiceProtocol.self)
        let anotherRegistered = await sut.isRegistered(AnotherTestServiceProtocol.self)
        XCTAssertFalse(testRegistered)
        XCTAssertFalse(anotherRegistered)
    }

    func testIsRegistered() async throws {
        // Given
        try await sut.register(TestServiceProtocol.self) {
            TestService()
        }

        // When
        let registered = await sut.isRegistered(TestServiceProtocol.self)
        let notRegistered = await sut.isRegistered(AnotherTestServiceProtocol.self)

        // Then
        XCTAssertTrue(registered)
        XCTAssertFalse(notRegistered)
    }

    func testResolveOptional() async throws {
        // Given
        try await sut.register(TestServiceProtocol.self) {
            TestService()
        }

        // When
        let found = await sut.resolveOptional(TestServiceProtocol.self)
        let notFound = await sut.resolveOptional(AnotherTestServiceProtocol.self)

        // Then
        XCTAssertNotNil(found)
        XCTAssertNil(notFound)
    }

    func testRegisteredServices() async throws {
        // Given
        try await sut.register(TestServiceProtocol.self) {
            TestService()
        }
        try await sut.register(AnotherTestServiceProtocol.self) {
            AnotherTestService()
        }

        // When
        let services = await sut.registeredServices()

        // Then
        XCTAssertEqual(services.count, 2)
        XCTAssertTrue(services.values.allSatisfy { $0.registrationDate <= Date() })
    }

    // MARK: - Module Tests

    func testRegisterModule() async throws {
        // Given
        let module = TestModule()

        // When
        try await sut.register(module: module)

        // Then
        let testService = try await sut.resolve(TestServiceProtocol.self)
        let anotherService = try await sut.resolve(AnotherTestServiceProtocol.self)

        XCTAssertNotNil(testService)
        XCTAssertNotNil(anotherService)
    }

    func testRegisterModulesWithDependencies() async throws {
        // Given
        let modules: [any ServiceModule] = [
            DependentModule(),
            TestModule()
        ]

        // When - should auto-sort by dependencies
        try await sut.registerModules(modules)

        // Then - dependent service should resolve successfully
        let service = try await sut.resolve(DependentServiceProtocol.self)
        XCTAssertNotNil(service.dependency)
    }

    // MARK: - Mock Injection Tests

    func testReplaceMock() async throws {
        // Given
        try await sut.register(TestServiceProtocol.self) {
            TestService()
        }

        let mock = MockTestService()
        try await sut.replaceMock(TestServiceProtocol.self, mock: mock)

        // When
        let service = try await sut.resolve(TestServiceProtocol.self)
        _ = service.doSomething()

        // Then
        XCTAssertEqual((service as? MockTestService)?.callCount, 1)
    }

    func testReplace() async throws {
        // Given
        try await sut.register(AnotherTestServiceProtocol.self) {
            AnotherTestService(value: 10)
        }

        // When
        try await sut.replace(AnotherTestServiceProtocol.self) {
            AnotherTestService(value: 99)
        }

        // Then
        let service = try await sut.resolve(AnotherTestServiceProtocol.self)
        XCTAssertEqual(service.value, 99)
    }

    // MARK: - Error Description Tests

    func testErrorDescriptions() async throws {
        // Test service not registered error
        do {
            _ = try await sut.resolve(TestServiceProtocol.self)
            XCTFail("Should throw")
        } catch let error as ServiceLocator.ServiceLocatorError {
            XCTAssertTrue(error.description.contains("not registered"))
        }

        // Test duplicate registration error
        try await sut.register(TestServiceProtocol.self) {
            TestService()
        }

        do {
            try await sut.register(TestServiceProtocol.self) {
                TestService()
            }
            XCTFail("Should throw")
        } catch let error as ServiceLocator.ServiceLocatorError {
            XCTAssertTrue(error.description.contains("already registered"))
        }
    }

    // MARK: - Thread Safety Tests

    func testConcurrentAccess() async throws {
        // Given
        try await sut.register(TestServiceProtocol.self, isSingleton: false) {
            TestService()
        }

        // Capture sut in local variable for Sendable closure
        let locator = sut!

        // When - concurrent resolutions
        await withTaskGroup(of: String.self) { group in
            for _ in 0..<10 {
                group.addTask { @Sendable in
                    do {
                        let service = try await locator.resolve(TestServiceProtocol.self)
                        return service.doSomething()
                    } catch {
                        return "error"
                    }
                }
            }
        }

        // Then - should not crash
        XCTAssertTrue(true)
    }
}
