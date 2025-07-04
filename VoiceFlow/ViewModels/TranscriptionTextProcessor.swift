import Foundation

/// Processes and enhances transcription text
/// Single Responsibility: Text processing, medical terminology detection, and model optimization
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
    
    private var processingStats = ProcessingStatistics()
    private let medicalTermsDetector = MedicalTerminologyDetector()
    private let textCleaner = TranscriptionTextCleaner()
    
    // MARK: - Initialization
    
    public init() {
        print("🧠 TranscriptionTextProcessor initialized")
    }
    
    // MARK: - Public Interface
    
    /// Process transcript text with domain detection and optimization
    public func processTranscript(_ text: String, isFinal: Bool) async -> String {
        // Clean and sanitize the text
        let cleanedText = await textCleaner.cleanText(text)
        
        // Update processing statistics
        processingStats.totalTextsProcessed += 1
        
        if isFinal {
            // Perform domain detection for final text
            let domain = await detectTextDomain(cleanedText)
            processingStats.updateDomainStats(for: domain)
            
            print("🧠 Text domain detected: \(domain)")
        }
        
        return cleanedText
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
    public func getProcessingStatistics() async -> ProcessingStatistics {
        return processingStats
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

public struct ProcessingStatistics: Sendable {
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