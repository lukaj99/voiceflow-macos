import Foundation

// MARK: - LLM State Coordination Protocol

@MainActor
public protocol LLMProcessingStateManaging: AnyObject {
    var llmPostProcessingEnabled: Bool { get set }
    var hasLLMProvidersConfigured: Bool { get set }
    var isLLMProcessing: Bool { get set }
    func enableLLMPostProcessing()
    func disableLLMPostProcessing()
    func setLLMProcessing(_ processing: Bool, progress: Float)
    func setLLMProcessingError(_ error: String?)
    func setSelectedLLMProvider(_ provider: String, model: String)
    func updateLLMConfigurationStatus(_ hasProviders: Bool)
    func recordLLMProcessingResult(
        success: Bool,
        processingTime: TimeInterval,
        improvementScore: Float
    )
}

/// Processes and enhances transcription text with LLM post-processing
/// Single Responsibility: Text processing, medical terminology detection, model optimization, and LLM enhancement
public actor TranscriptionTextProcessor {
    
    // MARK: - Types
    
    public struct ProcessingResult {
        public let text: String
        public let detectedDomain: TextDomain
        public let confidence: Double
        public let suggestedModel: DeepgramModel?
        
        public init(text: String, detectedDomain: TextDomain, confidence: Double, suggestedModel: DeepgramModel? = nil) {
            self.text = text
            self.detectedDomain = detectedDomain
            self.confidence = confidence
            self.suggestedModel = suggestedModel
        }
    }
    
    public enum TextDomain {
        case general
        case medical
        case technical
        case legal
        case financial
        
        var recommendedModel: DeepgramModel {
            switch self {
            case .general: return .general
            case .medical: return .medical
            case .technical, .legal, .financial: return .enhanced
            }
        }
    }
    
    // MARK: - Properties
    
    private var processingStats = TranscriptionProcessingStatistics()
    private let medicalTermsDetector = MedicalTerminologyDetector()
    private let textCleaner = TranscriptionTextCleaner()
    private let llmService: LLMPostProcessingService
    private nonisolated(unsafe) let appState: any LLMProcessingStateManaging
    
    // MARK: - Initialization
    
    public init(llmService: LLMPostProcessingService, appState: any LLMProcessingStateManaging) {
        self.llmService = llmService
        self.appState = appState
        print("🧠 TranscriptionTextProcessor initialized with LLM support")
    }

    /// Create a new TranscriptionTextProcessor with default dependencies
    public static func createDefault() async -> TranscriptionTextProcessor {
        let llmService = await MainActor.run { LLMPostProcessingService() }
        let appState = await MainActor.run { AppState.shared }
        return TranscriptionTextProcessor(llmService: llmService, appState: appState)
    }
    
    // MARK: - Public Interface
    
    /// Process transcript text with domain detection, optimization, and optional LLM enhancement
    public func processTranscript(_ text: String, isFinal: Bool) async -> String {
        // Clean and sanitize the text
        let cleanedText = await textCleaner.cleanText(text)
        
        // Update processing statistics
        processingStats.totalTextsProcessed += 1
        
        var finalText = cleanedText
        
        if isFinal {
            // Perform domain detection for final text
            let domain = await detectTextDomain(cleanedText)
            processingStats.updateDomainStats(for: domain)
            
            print("🧠 Text domain detected: \(domain)")
            
            // Apply LLM post-processing if enabled and configured
            if await shouldApplyLLMProcessing() {
                finalText = await applyLLMPostProcessing(cleanedText, domain: domain)
            }
        }
        
        return finalText
    }
    
    /// Analyze text and suggest optimal model
    public func analyzeAndSuggestModel(_ text: String) async -> ProcessingResult {
        let cleanedText = await textCleaner.cleanText(text)
        let domain = await detectTextDomain(cleanedText)
        let confidence = await calculateDomainConfidence(text, domain: domain)
        
        let suggestedModel = confidence > 0.7 ? domain.recommendedModel : nil
        
        return ProcessingResult(
            text: cleanedText,
            detectedDomain: domain,
            confidence: confidence,
            suggestedModel: suggestedModel
        )
    }
    
    /// Get current processing statistics
    public func getProcessingStatistics() async -> TranscriptionProcessingStatistics {
        return processingStats
    }
    
    // MARK: - LLM Integration Methods
    
    /// Check if LLM processing should be applied
    private func shouldApplyLLMProcessing() async -> Bool {
        // Get current state from main actor
        return await MainActor.run {
            return appState.llmPostProcessingEnabled && 
                   appState.hasLLMProvidersConfigured && 
                   !appState.isLLMProcessing
        }
    }
    
    /// Apply LLM post-processing to the text
    private func applyLLMPostProcessing(_ text: String, domain: TextDomain) async -> String {
        // Skip processing for very short text
        guard text.count > 10 else { return text }
        
        // Update app state to show processing
        await MainActor.run {
            appState.setLLMProcessing(true, progress: 0.0)
        }
        
        let startTime = Date()
        
        do {
            // Build context information based on detected domain
            let context = buildContextForDomain(domain)
            
            // Process with LLM service
            let result = await llmService.processTranscription(text, context: context)
            
            switch result {
            case .success(let processingResult):
                let processingTime = Date().timeIntervalSince(startTime)
                
                // Update app state with success
                await MainActor.run {
                    appState.setLLMProcessing(false, progress: 1.0)
                    appState.recordLLMProcessingResult(
                        success: true,
                        processingTime: processingTime,
                        improvementScore: processingResult.improvementScore
                    )
                }
                
                // Log improvements
                if !processingResult.changes.isEmpty {
                    print("🤖 LLM enhanced text with \(processingResult.changes.count) improvements")
                    for change in processingResult.changes {
                        print("  - \(change.type): \(change.original) → \(change.replacement)")
                    }
                }
                
                return processingResult.processedText
                
            case .failure(let error):
                let processingTime = Date().timeIntervalSince(startTime)
                
                // Update app state with error
                await MainActor.run {
                    appState.setLLMProcessingError(error.localizedDescription)
                    appState.recordLLMProcessingResult(
                        success: false,
                        processingTime: processingTime,
                        improvementScore: 0.0
                    )
                }
                
                print("❌ LLM processing failed: \(error.localizedDescription)")
                return text // Return original text on error
            }
            
        }
    }
    
    /// Build context information for LLM processing based on detected domain
    private func buildContextForDomain(_ domain: TextDomain) -> String {
        switch domain {
        case .medical:
            return "Medical/healthcare context with medical terminology"
        case .technical:
            return "Technical/programming context with technical terminology"
        case .legal:
            return "Legal context with legal terminology"
        case .financial:
            return "Financial/business context with financial terminology"
        case .general:
            return "General conversation context"
        }
    }
    
    /// Configure LLM service with current settings
    public func configureLLMService(provider: LLMProvider, model: String, apiKey: String) async {
        // Extract values outside MainActor to avoid data races
        let providerRawValue = provider.rawValue
        let providerDisplayName = provider.displayName
        
        await MainActor.run {
            // Convert string to LLMModel enum
            if let llmModel = LLMPostProcessingService.LLMModel(rawValue: model) {
                llmService.selectedModel = llmModel
            }
            
            // Convert to LLMPostProcessingService.LLMProvider
            let serviceProvider = LLMPostProcessingService.LLMProvider(rawValue: providerRawValue) ?? .openAI
            llmService.configureAPIKey(apiKey, for: serviceProvider)
            
            // Update app state
            appState.setSelectedLLMProvider(providerRawValue, model: model)
            appState.updateLLMConfigurationStatus(llmService.isConfigured(for: serviceProvider))
        }
        
        print("🤖 LLM service configured: \(providerDisplayName) - \(model)")
    }
    
    /// Enable LLM post-processing
    public func enableLLMProcessing() async {
        await MainActor.run {
            llmService.isEnabled = true
            appState.enableLLMPostProcessing()
        }
        
        print("🤖 LLM post-processing enabled")
    }
    
    /// Disable LLM post-processing
    public func disableLLMProcessing() async {
        await MainActor.run {
            llmService.isEnabled = false
            appState.disableLLMPostProcessing()
        }
        
        print("🤖 LLM post-processing disabled")
    }
    
    /// Get LLM processing statistics  
    public func getLLMStatistics() async -> LLMProcessingStatistics {
        return await llmService.getStatistics()
    }
    
    // MARK: - Private Methods
    
    /// Detect the domain/context of the text
    private func detectTextDomain(_ text: String) async -> TextDomain {
        let medicalScore = await medicalTermsDetector.calculateMedicalScore(text)
        
        // Simple domain detection - can be enhanced with ML models
        if medicalScore > 0.3 {
            return .medical
        }
        
        // Check for technical terms
        let technicalTerms = ["algorithm", "database", "server", "API", "function", "variable", "class", "method"]
        let technicalScore = calculateTermScore(text, terms: technicalTerms)
        
        if technicalScore > 0.2 {
            return .technical
        }
        
        // Check for legal terms
        let legalTerms = ["contract", "agreement", "clause", "liability", "jurisdiction", "plaintiff", "defendant"]
        let legalScore = calculateTermScore(text, terms: legalTerms)
        
        if legalScore > 0.2 {
            return .legal
        }
        
        // Check for financial terms
        let financialTerms = ["investment", "portfolio", "revenue", "profit", "financial", "accounting", "budget"]
        let financialScore = calculateTermScore(text, terms: financialTerms)
        
        if financialScore > 0.2 {
            return .financial
        }
        
        return .general
    }
    
    /// Calculate confidence score for domain detection
    private func calculateDomainConfidence(_ text: String, domain: TextDomain) async -> Double {
        switch domain {
        case .medical:
            return await medicalTermsDetector.calculateMedicalScore(text)
        case .technical:
            let technicalTerms = ["algorithm", "database", "server", "API", "function", "variable", "class", "method"]
            return calculateTermScore(text, terms: technicalTerms)
        case .legal:
            let legalTerms = ["contract", "agreement", "clause", "liability", "jurisdiction", "plaintiff", "defendant"]
            return calculateTermScore(text, terms: legalTerms)
        case .financial:
            let financialTerms = ["investment", "portfolio", "revenue", "profit", "financial", "accounting", "budget"]
            return calculateTermScore(text, terms: financialTerms)
        case .general:
            return 0.5 // Moderate confidence for general domain
        }
    }
    
    /// Calculate term occurrence score
    private func calculateTermScore(_ text: String, terms: [String]) -> Double {
        let lowercaseText = text.lowercased()
        let words = lowercaseText.components(separatedBy: CharacterSet.alphanumerics.inverted)
        
        let termCount = terms.reduce(0) { count, term in
            count + (lowercaseText.contains(term) ? 1 : 0)
        }
        
        return words.count > 5 ? Double(termCount) / Double(words.count) : 0.0
    }
}

// MARK: - Supporting Actors

/// Medical terminology detection
public actor MedicalTerminologyDetector {
    
    private let medicalTerms: Set<String> = [
        // Anatomy
        "heart", "lung", "liver", "kidney", "brain", "blood", "artery", "vein", "muscle", "bone",
        "stomach", "intestine", "pancreas", "thyroid", "spine", "joint", "tendon", "ligament",
        
        // Medical conditions
        "diagnosis", "symptoms", "syndrome", "disease", "infection", "inflammation", "tumor",
        "cancer", "diabetes", "hypertension", "pneumonia", "bronchitis", "asthma", "allergy",
        "fracture", "injury", "wound", "lesion", "ulcer", "edema", "fever", "pain", "nausea",
        
        // Medical procedures
        "surgery", "operation", "procedure", "examination", "treatment", "therapy", "medication",
        "prescription", "injection", "biopsy", "scan", "x-ray", "MRI", "CT scan", "ultrasound",
        "endoscopy", "anesthesia", "suture", "incision", "transplant",
        
        // Medical professionals
        "doctor", "physician", "surgeon", "nurse", "patient", "radiologist", "cardiologist",
        "oncologist", "neurologist", "psychiatrist", "anesthesiologist", "pathologist",
        
        // Medical measurements
        "blood pressure", "heart rate", "temperature", "glucose", "cholesterol", "hemoglobin",
        "white blood cell", "red blood cell", "platelet", "creatinine", "sodium", "potassium",
        
        // Medical abbreviations
        "mg", "ml", "cc", "IV", "IM", "PO", "PRN", "stat", "ICU", "ER", "OR", "post-op", "pre-op"
    ]
    
    /// Calculate medical terminology score (0.0 to 1.0)
    public func calculateMedicalScore(_ text: String) async -> Double {
        let lowercaseText = text.lowercased()
        let words = lowercaseText.components(separatedBy: CharacterSet.alphanumerics.inverted)
        
        let medicalWordCount = words.reduce(0) { count, word in
            count + (medicalTerms.contains(word) ? 1 : 0)
        }
        
        return words.count > 5 ? Double(medicalWordCount) / Double(words.count) : 0.0
    }
}

/// Text cleaning and normalization
public actor TranscriptionTextCleaner {
    
    /// Clean and normalize transcription text
    public func cleanText(_ text: String) async -> String {
        var cleaned = text
        
        // Remove excessive whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // Remove interim markers if any leaked through
        cleaned = cleaned.replacingOccurrences(of: "[Interim]", with: "")
        
        // Capitalize first letter if needed
        if !cleaned.isEmpty {
            cleaned = cleaned.prefix(1).uppercased() + cleaned.dropFirst()
        }
        
        return cleaned
    }
}

// MARK: - Supporting Types

public struct TranscriptionProcessingStatistics: Sendable {
    public var totalTextsProcessed: Int = 0
    public var medicalTextsDetected: Int = 0
    public var technicalTextsDetected: Int = 0
    public var legalTextsDetected: Int = 0
    public var financialTextsDetected: Int = 0
    public var generalTextsDetected: Int = 0
    
    public mutating func updateDomainStats(for domain: TranscriptionTextProcessor.TextDomain) {
        switch domain {
        case .medical: medicalTextsDetected += 1
        case .technical: technicalTextsDetected += 1
        case .legal: legalTextsDetected += 1
        case .financial: financialTextsDetected += 1
        case .general: generalTextsDetected += 1
        }
    }
    
    public var mostCommonDomain: TranscriptionTextProcessor.TextDomain {
        let counts = [
            (TranscriptionTextProcessor.TextDomain.medical, medicalTextsDetected),
            (.technical, technicalTextsDetected),
            (.legal, legalTextsDetected),
            (.financial, financialTextsDetected),
            (.general, generalTextsDetected)
        ]
        
        return counts.max { $0.1 < $1.1 }?.0 ?? .general
    }
}
