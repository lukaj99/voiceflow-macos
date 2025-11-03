import Foundation
import SwiftUI

/// Extensions and helpers for integrating error handling throughout the app
extension Result {
    /// Convert Result to VoiceFlowError
    func mapToVoiceFlowError(context: String) -> Result<Success, VoiceFlowError> {
        return self.mapError { error in
            mapErrorToVoiceFlowError(error, context: context)
        }
    }

    /// Map any error to VoiceFlowError with appropriate categorization
    private func mapErrorToVoiceFlowError(_ error: Error, context: String) -> VoiceFlowError {
        guard let nsError = error as NSError? else {
            return VoiceFlowError.unexpectedError("\(context): \(error.localizedDescription)")
        }

        switch nsError.domain {
        case NSURLErrorDomain:
            return mapURLError(nsError)
        case NSCocoaErrorDomain:
            return mapCocoaError(nsError)
        default:
            return VoiceFlowError.unexpectedError("\(context): \(error.localizedDescription)")
        }
    }

    /// Map URL domain errors to VoiceFlowError
    private func mapURLError(_ error: NSError) -> VoiceFlowError {
        switch error.code {
        case NSURLErrorNotConnectedToInternet:
            return .networkUnavailable
        case NSURLErrorTimedOut:
            return .networkTimeout
        case NSURLErrorBadServerResponse:
            return .invalidServerResponse
        default:
            return .networkUnavailable
        }
    }

    /// Map Cocoa domain errors to VoiceFlowError
    private func mapCocoaError(_ error: NSError) -> VoiceFlowError {
        switch error.code {
        case NSFileReadNoSuchFileError:
            return .fileNotFound(error.localizedDescription)
        case NSFileReadNoPermissionError:
            return .fileAccessDenied(error.localizedDescription)
        default:
            return .unexpectedError(error.localizedDescription)
        }
    }
}

/// Async throwing extensions for error handling
extension Task {
    /// Execute async task with automatic error reporting
    static func withErrorReporting<T>(
        component: String,
        function: String = #function,
        operation: @escaping () async throws -> T
    ) async -> Result<T, VoiceFlowError> {
        do {
            let result = try await operation()
            return .success(result)
        } catch {
            return await handleAndReportError(
                error,
                component: component,
                function: function
            )
        }
    }

    /// Handle and report errors from async operations
    private static func handleAndReportError<T>(
        _ error: Error,
        component: String,
        function: String
    ) async -> Result<T, VoiceFlowError> {
        let context = ErrorReporter.ErrorContext(component: component, function: function)
        let voiceFlowError = convertToVoiceFlowError(error)

        await ErrorReporter.shared.reportError(voiceFlowError, context: context)
        return .failure(voiceFlowError)
    }

    /// Convert any error to VoiceFlowError
    private static func convertToVoiceFlowError(_ error: Error) -> VoiceFlowError {
        if let vfError = error as? VoiceFlowError {
            return vfError
        }
        return VoiceFlowError.unexpectedError(error.localizedDescription)
    }
}

/// SwiftUI error handling integration
@MainActor
public class ErrorAlertManager: ObservableObject {
    @Published public var currentAlert: ErrorAlert?

    public struct ErrorAlert: Identifiable {
        public let id = UUID()
        public let error: VoiceFlowError
        public let primaryAction: (() -> Void)?
        public let secondaryAction: (() -> Void)?

        public init(
            error: VoiceFlowError,
            primaryAction: (() -> Void)? = nil,
            secondaryAction: (() -> Void)? = nil
        ) {
            self.error = error
            self.primaryAction = primaryAction
            self.secondaryAction = secondaryAction
        }
    }

    public func showError(
        _ error: VoiceFlowError,
        primaryAction: (() -> Void)? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        currentAlert = ErrorAlert(
            error: error,
            primaryAction: primaryAction,
            secondaryAction: secondaryAction
        )
    }

    public func dismissAlert() {
        currentAlert = nil
    }
}

/// SwiftUI View modifier for error handling
public struct ErrorHandlingViewModifier: ViewModifier {
    @StateObject private var alertManager = ErrorAlertManager()
    @StateObject private var recoveryManager = ErrorRecoveryManager()

    public func body(content: Content) -> some View {
        content
            .environmentObject(alertManager)
            .environmentObject(recoveryManager)
            .alert(item: $alertManager.currentAlert, content: buildAlert)
            .sheet(isPresented: $recoveryManager.showErrorDialog) {
                ErrorRecoveryView(recoveryManager: recoveryManager)
            }
    }

    /// Build alert for error presentation
    private func buildAlert(for errorAlert: ErrorAlertManager.ErrorAlert) -> Alert {
        Alert(
            title: Text("Error"),
            message: Text(errorAlert.error.errorDescription ?? "An unexpected error occurred"),
            primaryButton: primaryAlertButton(for: errorAlert),
            secondaryButton: secondaryAlertButton(for: errorAlert)
        )
    }

    /// Create primary alert button
    private func primaryAlertButton(for errorAlert: ErrorAlertManager.ErrorAlert) -> Alert.Button {
        .default(Text("OK")) {
            handlePrimaryAction(for: errorAlert)
        }
    }

    /// Handle primary alert action
    private func handlePrimaryAction(for errorAlert: ErrorAlertManager.ErrorAlert) {
        errorAlert.primaryAction?()
        alertManager.dismissAlert()
    }

    /// Create secondary alert button
    private func secondaryAlertButton(for errorAlert: ErrorAlertManager.ErrorAlert) -> Alert.Button {
        if errorAlert.error.canRetry {
            return retryButton(for: errorAlert)
        } else {
            return cancelButton()
        }
    }

    /// Create retry button
    private func retryButton(for errorAlert: ErrorAlertManager.ErrorAlert) -> Alert.Button {
        .default(Text("Retry")) {
            handleRetryAction(for: errorAlert)
        }
    }

    /// Handle retry action
    private func handleRetryAction(for errorAlert: ErrorAlertManager.ErrorAlert) {
        errorAlert.secondaryAction?()
        alertManager.dismissAlert()
    }

    /// Create cancel button
    private func cancelButton() -> Alert.Button {
        .cancel {
            alertManager.dismissAlert()
        }
    }
}

extension View {
    /// Add comprehensive error handling to any view
    public func withErrorHandling() -> some View {
        modifier(ErrorHandlingViewModifier())
    }
}

/// Specialized error recovery view
public struct ErrorRecoveryView: View {
    @ObservedObject var recoveryManager: ErrorRecoveryManager
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationView {
            mainContentView
                .navigationTitle("Error Recovery")
                .toolbar { doneToolbarItem }
        }
    }

    /// Main content container
    @ViewBuilder
    private var mainContentView: some View {
        if let error = recoveryManager.currentError {
            errorContentView(for: error)
        }
    }

    /// Done button toolbar item
    private var doneToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            doneButton
        }
    }

    /// Main error content view
    private func errorContentView(for error: VoiceFlowError) -> some View {
        VStack(spacing: 20) {
            errorHeaderView(for: error)
            recoveryProgressView()
            recoverySuggestionView(for: error)
            stepByStepInstructionsView(for: error)
            Spacer()
            actionButtonsView()
        }
    }

    /// Error icon and title header
    private func errorHeaderView(for error: VoiceFlowError) -> some View {
        VStack(spacing: 12) {
            Image(systemName: error.category.icon)
                .font(.system(size: 48))
                .foregroundColor(Color(error.severity.color))

            Text(error.category.rawValue + " Error")
                .font(.title2)
                .fontWeight(.semibold)

            Text(error.errorDescription ?? "An unexpected error occurred")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top)
    }

    /// Recovery progress indicator
    @ViewBuilder
    private func recoveryProgressView() -> some View {
        if recoveryManager.isRecovering {
            recoveryProgressContent
        }
    }

    /// Content shown during recovery
    private var recoveryProgressContent: some View {
        VStack(spacing: 8) {
            ProgressView(value: recoveryManager.recoveryProgress)
                .progressViewStyle(LinearProgressViewStyle())
                .padding(.horizontal)

            recoveryMessageText
        }
        .padding()
    }

    /// Recovery message text (if available)
    @ViewBuilder
    private var recoveryMessageText: some View {
        if let message = recoveryManager.recoveryMessage {
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    /// Recovery suggestion section
    @ViewBuilder
    private func recoverySuggestionView(for error: VoiceFlowError) -> some View {
        if let recoverySuggestion = error.recoverySuggestion, !recoveryManager.isRecovering {
            recoverySuggestionContent(text: recoverySuggestion)
        }
    }

    /// Recovery suggestion content view
    private func recoverySuggestionContent(text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How to fix this:")
                .font(.headline)

            Text(text)
                .font(.body)
                .padding(.leading)
        }
        .padding()
    }

    /// Step-by-step instructions section
    @ViewBuilder
    private func stepByStepInstructionsView(for error: VoiceFlowError) -> some View {
        let suggestions = recoveryManager.getRecoverySuggestions(for: error)
        if !suggestions.isEmpty && !recoveryManager.isRecovering {
            stepListView(suggestions: suggestions)
        }
    }

    /// List of recovery steps
    private func stepListView(suggestions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Steps to resolve:")
                .font(.headline)

            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                stepRowView(number: index + 1, text: suggestion)
            }
        }
        .padding()
    }

    /// Individual step row
    private func stepRowView(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())

            Text(text)
                .font(.body)
                .multilineTextAlignment(.leading)

            Spacer()
        }
    }

    /// Action buttons section
    private func actionButtonsView() -> some View {
        VStack(spacing: 12) {
            ForEach(recoveryManager.availableActions) { action in
                actionButton(for: action)
            }
        }
        .padding()
    }

    /// Individual action button
    private func actionButton(for action: ErrorRecoveryManager.RecoveryAction) -> some View {
        Button(action: { performAction(action) }) {
            actionButtonContent(for: action)
        }
        .disabled(recoveryManager.isRecovering)
    }

    /// Perform recovery action
    private func performAction(_ action: ErrorRecoveryManager.RecoveryAction) {
        Task {
            await action.action()
        }
    }

    /// Action button content layout
    private func actionButtonContent(for action: ErrorRecoveryManager.RecoveryAction) -> some View {
        HStack {
            Image(systemName: action.icon)
            Text(action.title)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(action.isPrimary ? Color.blue : Color.secondary.opacity(0.2))
        .foregroundColor(action.isPrimary ? .white : .primary)
        .cornerRadius(10)
    }

    /// Done toolbar button
    private var doneButton: some View {
        Button("Done") {
            dismiss()
            recoveryManager.clearError()
        }
    }
}

/// Protocol for ViewModels with error handling
@MainActor
public protocol ErrorHandlingViewModel: AnyObject {
    var errorAlertManager: ErrorAlertManager { get }
    var recoveryManager: ErrorRecoveryManager { get }

    func handleError(_ error: VoiceFlowError, component: String, function: String)
}

extension ErrorHandlingViewModel {
    public func handleError(_ error: VoiceFlowError, component: String, function: String = #function) {
        let context = ErrorReporter.ErrorContext(component: component, function: function)

        Task {
            await recoveryManager.handleError(error, context: context)
        }

        showAlertIfNeeded(for: error)
    }

    /// Show error alert if the error requires user action
    private func showAlertIfNeeded(for error: VoiceFlowError) {
        guard shouldShowAlert(for: error) else { return }
        errorAlertManager.showError(error) {
            self.attemptErrorRecovery(for: error)
        }
    }

    /// Attempt error recovery in a task
    private func attemptErrorRecovery(for error: VoiceFlowError) {
        Task {
            _ = await self.recoveryManager.attemptRecovery(for: error)
        }
    }

    /// Determine if an alert should be shown for this error
    private func shouldShowAlert(for error: VoiceFlowError) -> Bool {
        error.requiresUserAction ||
        error.severity == .high ||
        error.severity == .critical
    }
}

/// Convenience functions for common error scenarios
public struct ErrorHelper {

    /// Handle audio permission errors
    public static func handleAudioPermissionError() -> VoiceFlowError {
        return .microphonePermissionDenied
    }

    /// Handle network connectivity errors
    public static func handleNetworkError(_ error: some Error) -> VoiceFlowError {
        guard let urlError = error as? URLError else {
            return .networkUnavailable
        }
        return mapURLErrorCode(urlError.code)
    }

    /// Map URLError code to VoiceFlowError
    private static func mapURLErrorCode(_ code: URLError.Code) -> VoiceFlowError {
        switch code {
        case .notConnectedToInternet:
            return .networkUnavailable
        case .timedOut:
            return .networkTimeout
        case .badServerResponse:
            return .invalidServerResponse
        default:
            return .networkUnavailable
        }
    }

    /// Handle file system errors
    public static func handleFileSystemError(_ error: some Error, filename: String) -> VoiceFlowError {
        guard let nsError = error as NSError? else {
            return .fileCorrupted(filename)
        }
        return mapFileSystemErrorCode(nsError.code, filename: filename)
    }

    /// Map file system error code to VoiceFlowError
    private static func mapFileSystemErrorCode(_ code: Int, filename: String) -> VoiceFlowError {
        switch code {
        case NSFileReadNoSuchFileError:
            return .fileNotFound(filename)
        case NSFileReadNoPermissionError:
            return .fileAccessDenied(filename)
        default:
            return .fileCorrupted(filename)
        }
    }

    /// Handle API errors with status codes
    public static func handleAPIError(statusCode: Int, message: String) -> VoiceFlowError {
        switch statusCode {
        case 401:
            return .transcriptionApiKeyInvalid
        case 429:
            return .apiRateLimitExceeded
        case 500...599:
            return .serverError(statusCode, message)
        default:
            return .transcriptionConnectionFailed(message)
        }
    }
}
