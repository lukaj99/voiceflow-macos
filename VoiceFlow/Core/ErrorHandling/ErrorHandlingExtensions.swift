import Foundation
import SwiftUI

/// Extensions and helpers for integrating error handling throughout the app
extension Result {
    /// Convert Result to VoiceFlowError
    func mapToVoiceFlowError(context: String) -> Result<Success, VoiceFlowError> {
        return self.mapError { error in
            // Map common system errors to VoiceFlowError
            if let nsError = error as NSError? {
                switch nsError.domain {
                case NSURLErrorDomain:
                    switch nsError.code {
                    case NSURLErrorNotConnectedToInternet:
                        return VoiceFlowError.networkUnavailable
                    case NSURLErrorTimedOut:
                        return VoiceFlowError.networkTimeout
                    case NSURLErrorBadServerResponse:
                        return VoiceFlowError.invalidServerResponse
                    default:
                        return VoiceFlowError.networkUnavailable
                    }
                case NSCocoaErrorDomain:
                    switch nsError.code {
                    case NSFileReadNoSuchFileError:
                        return VoiceFlowError.fileNotFound(nsError.localizedDescription)
                    case NSFileReadNoPermissionError:
                        return VoiceFlowError.fileAccessDenied(nsError.localizedDescription)
                    default:
                        return VoiceFlowError.unexpectedError(nsError.localizedDescription)
                    }
                default:
                    return VoiceFlowError.unexpectedError("\(context): \(error.localizedDescription)")
                }
            }
            
            return VoiceFlowError.unexpectedError("\(context): \(error.localizedDescription)")
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
            let context = ErrorReporter.ErrorContext(component: component, function: function)
            
            // Convert to VoiceFlowError if needed
            let voiceFlowError: VoiceFlowError
            if let vfError = error as? VoiceFlowError {
                voiceFlowError = vfError
            } else {
                voiceFlowError = VoiceFlowError.unexpectedError(error.localizedDescription)
            }
            
            // Report the error
            await ErrorReporter.shared.reportError(voiceFlowError, context: context)
            
            return .failure(voiceFlowError)
        }
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
            .alert(item: $alertManager.currentAlert) { errorAlert in
                Alert(
                    title: Text("Error"),
                    message: Text(errorAlert.error.errorDescription ?? "An unexpected error occurred"),
                    primaryButton: .default(Text("OK")) {
                        errorAlert.primaryAction?()
                        alertManager.dismissAlert()
                    },
                    secondaryButton: errorAlert.error.canRetry ? 
                        .default(Text("Retry")) {
                            errorAlert.secondaryAction?()
                            alertManager.dismissAlert()
                        } : .cancel {
                            alertManager.dismissAlert()
                        }
                )
            }
            .sheet(isPresented: $recoveryManager.showErrorDialog) {
                ErrorRecoveryView(recoveryManager: recoveryManager)
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
            VStack(spacing: 20) {
                // Error icon and title
                if let error = recoveryManager.currentError {
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
                    
                    // Recovery progress
                    if recoveryManager.isRecovering {
                        VStack(spacing: 8) {
                            ProgressView(value: recoveryManager.recoveryProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                                .padding(.horizontal)
                            
                            if let message = recoveryManager.recoveryMessage {
                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                    }
                    
                    // Recovery suggestions
                    if let recoverySuggestion = error.recoverySuggestion, !recoveryManager.isRecovering {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How to fix this:")
                                .font(.headline)
                            
                            Text(recoverySuggestion)
                                .font(.body)
                                .padding(.leading)
                        }
                        .padding()
                    }
                    
                    // Step-by-step instructions
                    let suggestions = recoveryManager.getRecoverySuggestions(for: error)
                    if !suggestions.isEmpty && !recoveryManager.isRecovering {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Steps to resolve:")
                                .font(.headline)
                            
                            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Color.blue)
                                        .clipShape(Circle())
                                    
                                    Text(suggestion)
                                        .font(.body)
                                        .multilineTextAlignment(.leading)
                                    
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        ForEach(recoveryManager.availableActions) { action in
                            Button(action: {
                                Task {
                                    await action.action()
                                }
                            }) {
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
                            .disabled(recoveryManager.isRecovering)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Error Recovery")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                        recoveryManager.clearError()
                    }
                }
            }
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
        
        // Show alert for user-facing errors
        if error.requiresUserAction || error.severity == .high || error.severity == .critical {
            errorAlertManager.showError(error) {
                // Primary action - attempt recovery
                Task {
                    let _ = await self.recoveryManager.attemptRecovery(for: error)
                }
            }
        }
    }
}

/// Convenience functions for common error scenarios
public struct ErrorHelper {
    
    /// Handle audio permission errors
    public static func handleAudioPermissionError() -> VoiceFlowError {
        return .microphonePermissionDenied
    }
    
    /// Handle network connectivity errors
    public static func handleNetworkError(_ error: any Error) -> VoiceFlowError {
        if let urlError = error as? URLError {
            switch urlError.code {
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
        return .networkUnavailable
    }
    
    /// Handle file system errors
    public static func handleFileSystemError(_ error: any Error, filename: String) -> VoiceFlowError {
        if let nsError = error as NSError? {
            switch nsError.code {
            case NSFileReadNoSuchFileError:
                return .fileNotFound(filename)
            case NSFileReadNoPermissionError:
                return .fileAccessDenied(filename)
            default:
                return .fileCorrupted(filename)
            }
        }
        return .fileCorrupted(filename)
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