//
//  CoordinatorProtocol.swift
//  VoiceFlow
//
//  Created by Claude Code on 2025-11-02.
//  Copyright © 2025 VoiceFlow. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: - App Coordinator Protocol

/// Top-level coordinator protocol for application-wide coordination
/// Manages app lifecycle, navigation, and feature coordination
@MainActor
protocol AppCoordinatorProtocol: Sendable {
    /// Starts the application coordinator
    /// - Throws: CoordinatorError if startup fails
    func start() async throws

    /// Stops the application coordinator
    func stop() async

    /// Handles deep links
    /// - Parameter url: Deep link URL
    /// - Returns: True if deep link was handled
    func handleDeepLink(_ url: URL) async -> Bool

    /// Registers a feature coordinator
    /// - Parameter coordinator: Feature coordinator to register
    func registerFeature<C: FeatureCoordinatorProtocol>(_ coordinator: C) async

    /// Unregisters a feature coordinator
    /// - Parameter featureID: ID of feature to unregister
    func unregisterFeature(_ featureID: String) async

    /// All registered features
    var registeredFeatures: [String] { get }

    /// Whether app is fully initialized
    var isInitialized: Bool { get }
}

// MARK: - Navigation Coordinator Protocol

/// Protocol for coordinating navigation between features
@MainActor
protocol NavigationCoordinatorProtocol: Sendable {
    /// Type of route this coordinator handles
    associatedtype Route: RouteProtocol

    /// Navigates to a specific route
    /// - Parameters:
    ///   - route: Destination route
    ///   - animated: Whether to animate transition
    func navigate(to route: Route, animated: Bool) async throws

    /// Navigates back to previous route
    /// - Parameter animated: Whether to animate transition
    func navigateBack(animated: Bool) async

    /// Navigates to root route
    /// - Parameter animated: Whether to animate transition
    func navigateToRoot(animated: Bool) async

    /// Current navigation stack
    var navigationStack: [Route] { get }

    /// Whether navigation is currently in progress
    var isNavigating: Bool { get }
}

/// Protocol for route definitions
protocol RouteProtocol: Sendable, Hashable, Identifiable {
    /// Unique identifier for route
    var routeID: String { get }

    /// Path component for route
    var path: String { get }

    /// Whether route requires authentication
    var requiresAuthentication: Bool { get }
}

// MARK: - Window Coordinator Protocol

/// Protocol for coordinating window management
/// Handles multiple windows, window state, and window-specific navigation
@MainActor
protocol WindowCoordinatorProtocol: Sendable {
    /// Type of window managed
    associatedtype WindowType: WindowProtocol

    /// Opens a new window
    /// - Parameters:
    ///   - window: Window configuration
    ///   - position: Optional window position
    /// - Returns: Window identifier
    func openWindow(
        _ window: WindowType,
        at position: WindowPosition?
    ) async throws -> String

    /// Closes a window
    /// - Parameter windowID: Identifier of window to close
    func closeWindow(_ windowID: String) async

    /// Brings window to front
    /// - Parameter windowID: Identifier of window to activate
    func activateWindow(_ windowID: String) async

    /// All open windows
    var openWindows: [String: WindowType] { get }

    /// Main application window
    var mainWindow: WindowType? { get }
}

/// Protocol for window configurations
protocol WindowProtocol: Sendable, Identifiable {
    /// Window title
    var title: String { get }

    /// Window size
    var size: WindowSize { get }

    /// Window style
    var style: WindowStyle { get }

    /// Whether window can be resized
    var isResizable: Bool { get }

    /// Minimum window size
    var minimumSize: WindowSize? { get }
}

/// Window size specification
struct WindowSize: Sendable, Equatable {
    let width: CGFloat
    let height: CGFloat

    static let small = WindowSize(width: 400, height: 300)
    static let medium = WindowSize(width: 800, height: 600)
    static let large = WindowSize(width: 1200, height: 800)
}

/// Window position on screen
struct WindowPosition: Sendable {
    let x: CGFloat
    let y: CGFloat

    static let center = WindowPosition(x: 0, y: 0)
}

/// Window style options
enum WindowStyle: Sendable {
    case titled
    case borderless
    case utility
    case hudWindow
}

// MARK: - Tab Coordinator Protocol

/// Protocol for coordinating tab-based navigation
@MainActor
protocol TabCoordinatorProtocol: Sendable {
    /// Type of tab managed
    associatedtype Tab: TabProtocol

    /// Switches to specified tab
    /// - Parameter tab: Tab to switch to
    func switchTo(tab: Tab) async

    /// Currently selected tab
    var selectedTab: Tab { get }

    /// All available tabs
    var availableTabs: [Tab] { get }

    /// Whether tab switching is allowed
    var canSwitchTabs: Bool { get }
}

/// Protocol for tab definitions
protocol TabProtocol: Sendable, Identifiable, Hashable {
    /// Tab title
    var title: String { get }

    /// Tab icon name
    var iconName: String { get }

    /// Tab badge value
    var badgeValue: String? { get }

    /// Whether tab is enabled
    var isEnabled: Bool { get }
}

// MARK: - Flow Coordinator Protocol

/// Protocol for coordinating multi-step flows
/// Manages sequential workflows with validation and completion tracking
@MainActor
protocol FlowCoordinatorProtocol: Sendable {
    /// Type of step in the flow
    associatedtype Step: FlowStepProtocol

    /// Type of result from flow completion
    associatedtype Result: Sendable

    /// Starts the flow
    func startFlow() async throws

    /// Advances to next step
    /// - Returns: Next step if available
    func nextStep() async throws -> Step?

    /// Goes back to previous step
    /// - Returns: Previous step if available
    func previousStep() async -> Step?

    /// Completes the flow
    /// - Returns: Flow result
    func completeFlow() async throws -> Result

    /// Cancels the flow
    func cancelFlow() async

    /// Current step in flow
    var currentStep: Step? { get }

    /// All steps in flow
    var steps: [Step] { get }

    /// Progress through flow (0.0 - 1.0)
    var progress: Double { get }

    /// Whether flow can proceed to next step
    var canProceed: Bool { get }
}

/// Protocol for flow steps
protocol FlowStepProtocol: Sendable, Identifiable {
    /// Step title
    var title: String { get }

    /// Step description
    var description: String { get }

    /// Whether step is optional
    var isOptional: Bool { get }

    /// Validates step completion
    /// - Returns: Validation result
    func validate() async -> ValidationResult
}

// MARK: - Menu Coordinator Protocol

/// Protocol for coordinating menu bar interactions
@MainActor
protocol MenuCoordinatorProtocol: Sendable {
    /// Type of menu item
    associatedtype MenuItem: MenuItemProtocol

    /// Updates menu with new items
    /// - Parameter items: Menu items to display
    func updateMenu(with items: [MenuItem]) async

    /// Handles menu item selection
    /// - Parameter item: Selected menu item
    func handleSelection(_ item: MenuItem) async

    /// Current menu items
    var menuItems: [MenuItem] { get }

    /// Whether menu is currently visible
    var isVisible: Bool { get }
}

/// Protocol for menu items
protocol MenuItemProtocol: Sendable, Identifiable {
    /// Menu item title
    var title: String { get }

    /// Menu item icon
    var icon: String? { get }

    /// Menu item action
    var action: MenuAction { get }

    /// Whether item is enabled
    var isEnabled: Bool { get }

    /// Keyboard shortcut
    var shortcut: KeyboardShortcut? { get }

    /// Submenu items
    var submenu: [any MenuItemProtocol]? { get }
}

/// Menu item action type
enum MenuAction: Sendable {
    case navigation(String)
    case action(String)
    case separator
    case submenu
}

/// Keyboard shortcut specification
struct KeyboardShortcut: Sendable, Equatable {
    let key: String
    let modifiers: [KeyModifier]

    enum KeyModifier: String, Sendable {
        case command
        case option
        case control
        case shift
    }
}

// MARK: - Notification Coordinator Protocol

/// Protocol for coordinating notifications
@MainActor
protocol NotificationCoordinatorProtocol: Sendable {
    /// Type of notification
    associatedtype Notification: NotificationProtocol

    /// Schedules a notification
    /// - Parameter notification: Notification to schedule
    /// - Returns: Notification identifier
    func schedule(_ notification: Notification) async throws -> String

    /// Cancels a scheduled notification
    /// - Parameter notificationID: Identifier of notification to cancel
    func cancel(_ notificationID: String) async

    /// Cancels all scheduled notifications
    func cancelAll() async

    /// Handles notification response
    /// - Parameter response: User's response to notification
    func handleResponse(_ response: NotificationResponse) async

    /// All pending notifications
    var pendingNotifications: [String: Notification] { get }
}

/// Protocol for notifications
protocol NotificationProtocol: Sendable, Identifiable {
    /// Notification title
    var title: String { get }

    /// Notification body
    var body: String { get }

    /// Optional subtitle
    var subtitle: String? { get }

    /// Notification sound
    var sound: NotificationSound { get }

    /// When to deliver notification
    var deliveryDate: Date? { get }

    /// Action buttons
    var actions: [NotificationAction] { get }
}

/// Notification sound options
enum NotificationSound: Sendable {
    case `default`
    case none
    case custom(String)
}

/// Notification action button
struct NotificationAction: Sendable, Identifiable {
    let id: String
    let title: String
    let isDestructive: Bool
}

/// User response to notification
struct NotificationResponse: Sendable {
    let notificationID: String
    let actionID: String?
    let timestamp: Date
}

// MARK: - Coordinator Errors

/// Errors that can occur in coordinators
enum CoordinatorError: Error, Sendable {
    case notInitialized
    case alreadyInitialized
    case featureNotFound(String)
    case navigationFailed(String)
    case invalidRoute(String)
    case windowCreationFailed(String)
    case flowError(String)
}

// MARK: - Coordinator Dependencies

/// Protocol for coordinator dependency injection
protocol CoordinatorDependencies: Sendable {
    /// Service locator for resolving dependencies
    associatedtype ServiceLocator: ServiceLocatorProtocol

    /// Service locator instance
    var serviceLocator: ServiceLocator { get }
}

/// Protocol for service locator
protocol ServiceLocatorProtocol: Sendable {
    /// Resolves a service by type
    /// - Returns: Service instance
    /// - Throws: ServiceLocatorError if service not found
    func resolve<T>() throws -> T

    /// Registers a service
    /// - Parameters:
    ///   - service: Service instance
    ///   - type: Service type
    func register<T>(_ service: T, for type: T.Type)
}

/// Service locator errors
enum ServiceLocatorError: Error, Sendable {
    case serviceNotFound(String)
    case registrationFailed(String)
}
