import Foundation
import os.log

/// Manages context-aware processing and vocabulary following Single Responsibility Principle
@MainActor
public final class ContextProcessor: @unchecked Sendable {
    
    // MARK: - Properties
    
    private var currentContext: AppContext = .general
    private var customVocabulary: Set<String> = []
    private let logger = Logger(subsystem: "com.voiceflow.mac", category: "ContextProcessor")
    
    // MARK: - Public Methods
    
    public func setContext(_ context: AppContext) {
        currentContext = context
        updateVocabularyForContext()
        logger.info("Context updated to: \(String(describing: context))")
    }
    
    public func addCustomVocabulary(_ words: [String]) {
        customVocabulary.formUnion(words)
        logger.debug("Added \(words.count) words to custom vocabulary")
    }
    
    public func getContextualStrings() -> [String] {
        return Array(customVocabulary)
    }
    
    public func applyContextCorrections(to text: String) -> String {
        var correctedText = text
        
        // Apply custom vocabulary corrections
        correctedText = applyCustomVocabularyCorrections(correctedText)
        
        // Apply context-specific corrections
        correctedText = applyContextSpecificCorrections(correctedText)
        
        return correctedText
    }
    
    // MARK: - Private Methods
    
    private func updateVocabularyForContext() {
        // Clear context-specific vocabulary (keep custom words)
        let customWords = customVocabulary
        customVocabulary.removeAll()
        customVocabulary.formUnion(customWords)
        
        // Add context-specific vocabulary
        switch currentContext {
        case .coding(let language):
            loadProgrammingVocabulary(for: language)
        case .email:
            loadEmailVocabulary()
        case .meeting:
            loadMeetingVocabulary()
        case .document(let type):
            loadDocumentVocabulary(for: type)
        default:
            break
        }
    }
    
    private func applyCustomVocabularyCorrections(_ text: String) -> String {
        var correctedText = text
        
        for word in customVocabulary {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word.lowercased()))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                correctedText = regex.stringByReplacingMatches(
                    in: correctedText,
                    options: [],
                    range: NSRange(location: 0, length: correctedText.utf16.count),
                    withTemplate: word
                )
            }
        }
        
        return correctedText
    }
    
    private func applyContextSpecificCorrections(_ text: String) -> String {
        switch currentContext {
        case .coding:
            return applyProgrammingCorrections(text)
        case .email:
            return applyEmailCorrections(text)
        default:
            return text
        }
    }
    
    private func applyProgrammingCorrections(_ text: String) -> String {
        let corrections = [
            ("print line", "println"),
            ("function", "func"),
            ("variable", "var"),
            ("constant", "let"),
            ("swift you eye", "SwiftUI"),
            ("you eye kit", "UIKit"),
            ("app kit", "AppKit"),
            ("combine", "Combine"),
            ("async await", "async/await"),
            ("observable object", "ObservableObject"),
            ("published", "@Published"),
            ("state", "@State"),
            ("binding", "@Binding"),
            ("state object", "@StateObject"),
            ("environment object", "@EnvironmentObject")
        ]
        
        var result = text
        for (pattern, replacement) in corrections {
            result = result.replacingOccurrences(of: pattern, with: replacement, options: .caseInsensitive)
        }
        return result
    }
    
    private func applyEmailCorrections(_ text: String) -> String {
        let corrections = [
            ("best regards", "Best regards"),
            ("kind regards", "Kind regards"),
            ("sincerely", "Sincerely"),
            ("dear", "Dear"),
            ("thank you", "Thank you"),
            ("looking forward", "Looking forward"),
            ("please find attached", "Please find attached"),
            ("f y i", "FYI"),
            ("a s a p", "ASAP")
        ]
        
        var result = text
        for (pattern, replacement) in corrections {
            result = result.replacingOccurrences(of: pattern, with: replacement, options: .caseInsensitive)
        }
        return result
    }
    
    // MARK: - Vocabulary Loading
    
    private func loadProgrammingVocabulary(for language: AppContext.CodingLanguage?) {
        guard let language = language else { return }
        
        switch language {
        case .swift:
            customVocabulary.formUnion([
                "SwiftUI", "UIKit", "AppKit", "Combine", "async", "await",
                "ObservableObject", "@Published", "@State", "@Binding",
                "@StateObject", "@EnvironmentObject", "struct", "class", "protocol",
                "extension", "import", "public", "private", "internal", "fileprivate",
                "override", "final", "static", "lazy", "weak", "unowned",
                "guard", "defer", "throws", "rethrows", "inout"
            ])
        case .javascript:
            customVocabulary.formUnion([
                "const", "let", "var", "async", "await", "Promise",
                "React", "useState", "useEffect", "npm", "node", "webpack",
                "function", "arrow function", "destructuring", "spread operator",
                "template literal", "JSON", "API", "fetch", "axios"
            ])
        case .python:
            customVocabulary.formUnion([
                "def", "class", "import", "from", "as", "lambda",
                "list comprehension", "dictionary", "tuple", "set",
                "numpy", "pandas", "matplotlib", "flask", "django"
            ])
        case .typescript:
            customVocabulary.formUnion([
                "interface", "type", "generic", "union type", "intersection type",
                "optional chaining", "nullish coalescing", "decorators",
                "namespace", "module", "declare", "readonly"
            ])
        default:
            break
        }
    }
    
    private func loadEmailVocabulary() {
        customVocabulary.formUnion([
            "Best regards", "Kind regards", "Sincerely", "Thank you",
            "Looking forward", "Please find attached", "FYI", "ASAP",
            "CC", "BCC", "Reply all", "Forward", "Subject line",
            "Meeting invite", "Calendar", "Reschedule", "Urgent"
        ])
    }
    
    private func loadMeetingVocabulary() {
        customVocabulary.formUnion([
            "agenda", "action items", "follow-up", "stakeholders",
            "deliverables", "timeline", "milestone", "KPI", "ROI",
            "meeting minutes", "next steps", "quarterly review",
            "budget", "roadmap", "sprint", "retrospective"
        ])
    }
    
    private func loadDocumentVocabulary(for type: AppContext.DocumentType) {
        switch type {
        case .technical:
            customVocabulary.formUnion([
                "implementation", "architecture", "framework", "API",
                "documentation", "specification", "requirement",
                "scalability", "performance", "security", "testing",
                "deployment", "configuration", "integration"
            ])
        case .academic:
            customVocabulary.formUnion([
                "hypothesis", "methodology", "literature", "citation",
                "abstract", "conclusion", "bibliography", "peer review",
                "research", "analysis", "findings", "discussion",
                "introduction", "references", "appendix"
            ])
        case .legal:
            customVocabulary.formUnion([
                "contract", "agreement", "clause", "provision",
                "liability", "indemnification", "confidentiality",
                "intellectual property", "terms and conditions"
            ])
        case .creative:
            customVocabulary.formUnion([
                "narrative", "character", "plot", "dialogue",
                "theme", "setting", "metaphor", "structure",
                "revision", "draft", "manuscript", "publish"
            ])
        }
    }
}