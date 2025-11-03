import Foundation

// MARK: - LLM State Management Extension

@MainActor
extension AppState {
    /// Enable LLM post-processing for transcription enhancement.
    ///
    /// Activates LLM-powered post-processing which applies grammar correction,
    /// punctuation, and word substitution to transcription results.
    /// Automatically clears any previous processing errors.
    ///
    /// ## Usage Example
    /// ```swift
    /// appState.enableLLMPostProcessing()
    /// // Future transcriptions will be enhanced by LLM
    /// ```
    ///
    /// ## Performance Characteristics
    /// - Time complexity: O(1)
    /// - Memory usage: O(1)
    /// - Thread-safe: Yes (MainActor isolated)
    ///
    /// - Note: Requires LLM API keys to be configured in settings
    /// - SeeAlso: `disableLLMPostProcessing()`, `llmPostProcessingEnabled`
    public func enableLLMPostProcessing() {
        llmPostProcessingEnabled = true
        llmProcessingError = nil
        print("🤖 LLM post-processing enabled")
    }

    /// Disable LLM post-processing and reset processing state.
    ///
    /// Deactivates LLM post-processing and resets all related state including
    /// processing progress, flags, and error messages.
    ///
    /// ## Usage Example
    /// ```swift
    /// appState.disableLLMPostProcessing()
    /// // LLM processing is now disabled, transcriptions appear raw
    /// ```
    ///
    /// ## Performance Characteristics
    /// - Time complexity: O(1)
    /// - Memory usage: O(1)
    /// - Thread-safe: Yes (MainActor isolated)
    ///
    /// - SeeAlso: `enableLLMPostProcessing()`, `llmPostProcessingEnabled`
    public func disableLLMPostProcessing() {
        llmPostProcessingEnabled = false
        isLLMProcessing = false
        llmProcessingProgress = 0.0
        llmProcessingError = nil
        print("🤖 LLM post-processing disabled")
    }

    /// Update LLM processing status
    public func setLLMProcessing(_ processing: Bool, progress: Float = 0.0) {
        isLLMProcessing = processing
        llmProcessingProgress = progress

        if processing {
            llmProcessingError = nil
        }
    }

    /// Set LLM processing error
    public func setLLMProcessingError(_ error: String?) {
        llmProcessingError = error
        if let errorMessage = error {
            isLLMProcessing = false
            llmProcessingProgress = 0.0
            print("🤖 LLM processing error: \(errorMessage)")
        }
    }

    /// Update LLM configuration status
    public func updateLLMConfigurationStatus(_ hasProviders: Bool) {
        hasLLMProvidersConfigured = hasProviders
    }

    /// Set selected LLM provider and model
    public func setSelectedLLMProvider(_ provider: String, model: String) {
        selectedLLMProvider = provider
        selectedLLMModel = model
        print("🤖 LLM provider set to \(provider) with model \(model)")
    }

    /// Record LLM processing result
    public func recordLLMProcessingResult(
        success: Bool,
        processingTime: TimeInterval,
        improvementScore: Float = 0.0
    ) {
        llmProcessingStats.recordProcessing(
            success: success,
            processingTime: processingTime,
            improvementScore: improvementScore
        )
    }
}
