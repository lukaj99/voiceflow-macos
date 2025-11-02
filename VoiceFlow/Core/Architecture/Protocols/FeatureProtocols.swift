//
//  FeatureProtocols.swift
//  VoiceFlow
//
//  Created by Claude Code on 2025-11-02.
//  Copyright © 2025 VoiceFlow. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: - Feature Coordinator Protocol

/// Protocol for coordinating feature modules
/// Manages feature lifecycle, navigation, and dependency injection
@MainActor
protocol FeatureCoordinatorProtocol: Sendable {
    /// Type of view provided by this feature
    associatedtype FeatureView: View

    /// Unique identifier for the feature
    var featureID: String { get }

    /// Starts the feature and prepares it for use
    /// - Throws: FeatureError if feature cannot start
    func start() async throws

    /// Stops the feature and performs cleanup
    /// - Throws: FeatureError if feature cannot stop cleanly
    func stop() async throws

    /// Creates the root view for this feature
    /// - Returns: SwiftUI view representing the feature
    func makeView() -> FeatureView

    /// Whether the feature is currently active
    var isActive: Bool { get }

    /// Dependencies required by this feature
    var dependencies: [FeatureDependency] { get }
}

/// Dependency required by a feature
struct FeatureDependency: Sendable, Identifiable {
    let id: String
    let type: DependencyType
    let isRequired: Bool

    enum DependencyType: Sendable {
        case service(String)
        case feature(String)
        case configuration(String)
    }
}

// MARK: - View Model Protocol

/// Base protocol for all view models in the application
/// Provides state management with Swift 6 concurrency support
@MainActor
protocol ViewModelProtocol: ObservableObject, Sendable {
    /// Type of state managed by this view model
    associatedtype State: StateProtocol

    /// Current state of the view model
    var state: State { get }

    /// Initializes the view model
    /// - Throws: ViewModelError if initialization fails
    func initialize() async throws

    /// Cleans up resources when view model is dismissed
    func cleanup() async

    /// Handles errors that occur during view model operations
    /// - Parameter error: The error to handle
    func handleError(_ error: any Error) async

    /// Whether the view model is currently loading
    var isLoading: Bool { get }
}

/// Extended view model protocol with input handling
@MainActor
protocol InputHandlingViewModel: ViewModelProtocol {
    /// Type of input actions this view model handles
    associatedtype Input: ViewModelInput

    /// Processes an input action
    /// - Parameter input: The action to process
    func handle(_ input: Input) async
}

/// Protocol for view model input actions
protocol ViewModelInput: Sendable {
    /// Unique identifier for the input type
    var inputID: String { get }
}

// MARK: - State Protocol

/// Protocol for view model state
/// Ensures state is immutable, testable, and properly isolated
protocol StateProtocol: Sendable, Equatable {
    /// Creates initial state
    static func initial() -> Self

    /// Whether the state represents a loading condition
    var isLoading: Bool { get }

    /// Optional error in current state
    var error: StateError? { get }
}

/// State error wrapper
struct StateError: Sendable, Equatable, LocalizedError {
    let id: UUID
    let message: String
    let underlyingError: String?
    let timestamp: Date

    init(message: String, error: (any Error)? = nil) {
        self.id = UUID()
        self.message = message
        self.underlyingError = error?.localizedDescription
        self.timestamp = Date()
    }

    var errorDescription: String? {
        message
    }

    static func == (lhs: StateError, rhs: StateError) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Feature State Machine

/// Protocol for features that use state machine pattern
/// Provides type-safe state transitions with validation
@MainActor
protocol StateMachineProtocol: Sendable {
    /// Type representing possible states
    associatedtype State: StateProtocol & Hashable

    /// Type representing state transition events
    associatedtype Event: StateMachineEvent

    /// Current state
    var currentState: State { get }

    /// Attempts to transition to a new state
    /// - Parameters:
    ///   - event: The event triggering the transition
    /// - Returns: New state if transition is valid
    /// - Throws: StateMachineError if transition is invalid
    func transition(on event: Event) async throws -> State

    /// Checks if a transition is valid from current state
    /// - Parameter event: Event to validate
    /// - Returns: True if transition is allowed
    func canTransition(on event: Event) -> Bool

    /// All valid states reachable from current state
    var validNextStates: Set<State> { get }
}

/// Protocol for state machine events
protocol StateMachineEvent: Sendable, Hashable {
    /// Unique identifier for event type
    var eventID: String { get }
}

// MARK: - Data Source Protocol

/// Protocol for view model data sources
/// Abstracts data fetching and caching logic
protocol DataSourceProtocol: Sendable {
    /// Type of data provided
    associatedtype DataType: Sendable

    /// Fetches fresh data from source
    /// - Returns: Fresh data
    /// - Throws: DataSourceError if fetch fails
    func fetch() async throws -> DataType

    /// Fetches data with optional caching
    /// - Parameter useCache: Whether to use cached data if available
    /// - Returns: Data from cache or fresh fetch
    /// - Throws: DataSourceError if fetch fails
    func fetch(useCache: Bool) async throws -> DataType

    /// Invalidates any cached data
    func invalidateCache() async

    /// Whether cached data is available
    var hasCachedData: Bool { get async }
}

// MARK: - Action Protocol

/// Protocol for user actions in features
/// Provides type-safe action handling with tracking
protocol FeatureActionProtocol: Sendable {
    /// Unique identifier for the action
    var actionID: String { get }

    /// Human-readable description
    var description: String { get }

    /// Whether action can be undone
    var isUndoable: Bool { get }

    /// Priority level for action execution
    var priority: ActionPriority { get }
}

/// Action priority levels
enum ActionPriority: Int, Sendable, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    static func < (lhs: ActionPriority, rhs: ActionPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Presentation Protocol

/// Protocol for features that can present other features
@MainActor
protocol PresentationCapable: Sendable {
    /// Type of presentation style supported
    associatedtype PresentationStyle: PresentationStyleProtocol

    /// Presents another feature
    /// - Parameters:
    ///   - feature: Feature to present
    ///   - style: Presentation style
    func present<F: FeatureCoordinatorProtocol>(
        _ feature: F,
        style: PresentationStyle
    ) async throws

    /// Dismisses presented feature
    func dismiss() async

    /// Whether a feature is currently presented
    var isPresentingFeature: Bool { get }
}

/// Protocol for presentation styles
protocol PresentationStyleProtocol: Sendable {
    /// Whether presentation is modal
    var isModal: Bool { get }

    /// Whether presentation is animated
    var animated: Bool { get }
}

/// Standard presentation styles
enum StandardPresentationStyle: PresentationStyleProtocol, Sendable {
    case modal
    case sheet
    case fullscreen
    case popover

    var isModal: Bool {
        switch self {
        case .modal, .fullscreen: return true
        case .sheet, .popover: return false
        }
    }

    var animated: Bool { true }
}

// MARK: - Validation Protocol

/// Protocol for validating feature inputs
protocol ValidationProtocol: Sendable {
    /// Type being validated
    associatedtype Value: Sendable

    /// Validates a value
    /// - Parameter value: Value to validate
    /// - Returns: Validation result
    func validate(_ value: Value) async -> ValidationResult
}

/// Result of validation
enum ValidationResult: Sendable {
    case valid
    case invalid(reasons: [String])

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    var errors: [String] {
        if case .invalid(let reasons) = self { return reasons }
        return []
    }
}

// MARK: - Feature Analytics Protocol

/// Protocol for tracking feature analytics
protocol FeatureAnalyticsProtocol: Sendable {
    /// Tracks a feature event
    /// - Parameters:
    ///   - event: Event name
    ///   - properties: Optional event properties
    func track(event: String, properties: [String: AnalyticsValue]?) async

    /// Tracks a screen view
    /// - Parameter screenName: Name of screen viewed
    func trackScreenView(_ screenName: String) async

    /// Tracks an error
    /// - Parameter error: Error to track
    func trackError(_ error: any Error) async
}

/// Type-safe analytics value
enum AnalyticsValue: Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case date(Date)
}

// MARK: - Feature Errors

/// Errors that can occur in features
enum FeatureError: Error, Sendable {
    case notInitialized
    case alreadyActive
    case dependencyMissing(String)
    case invalidConfiguration(String)
    case presentationFailed(String)
}

/// View model errors
enum ViewModelError: Error, Sendable {
    case initializationFailed(String)
    case invalidState(String)
    case actionFailed(String)
}

/// State machine errors
enum StateMachineError: Error, Sendable {
    case invalidTransition(from: String, event: String)
    case invalidState(String)
}

/// Data source errors
enum DataSourceError: Error, Sendable {
    case fetchFailed(String)
    case cacheError(String)
    case noData
}
