import Foundation

/// Handles SRT (subtitle) export with timestamps
public class SRTExporter: Exporter {
    
    // MARK: - Properties
    
    private var isCancelled = false
    private let exportQueue = DispatchQueue(label: "com.voiceflow.srtexporter", qos: .userInitiated)
    
    // MARK: - Exporter Protocol
    
    public typealias Configuration = SRTExportConfiguration
    
    public func export(session: TranscriptionSession,
                      configuration: SRTExportConfiguration,
                      progressDelegate: ExportProgressDelegate?) async throws -> ExportResult {
        
        isCancelled = false
        
        // Validate that we have timing information
        guard !session.segments.isEmpty else {
            throw ExportError.configurationError("No segments with timing information found")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            exportQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ExportError.cancelled)
                    return
                }
                
                do {
                    let content = try self.generateSRTContent(session: session,
                                                            configuration: configuration,
                                                            progressDelegate: progressDelegate)
                    
                    guard !self.isCancelled else {
                        continuation.resume(throwing: ExportError.cancelled)
                        return
                    }
                    
                    guard let data = content.data(using: .utf8) else {
                        continuation.resume(throwing: ExportError.encodingError(NSError(domain: "SRTExporter",
                                                                                       code: 1,
                                                                                       userInfo: [NSLocalizedDescriptionKey: "Failed to encode SRT as UTF-8"])))
                        return
                    }
                    
                    continuation.resume(returning: .data(data))
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func exportToFile(session: TranscriptionSession,
                            configuration: SRTExportConfiguration,
                            fileURL: URL,
                            progressDelegate: ExportProgressDelegate?) async throws {
        
        let result = try await export(session: session,
                                    configuration: configuration,
                                    progressDelegate: progressDelegate)
        
        switch result {
        case .data(let data):
            do {
                try data.write(to: fileURL)
            } catch {
                throw ExportError.fileWriteError(fileURL, error)
            }
        case .fileURL:
            throw ExportError.invalidSession
        case .error(let error):
            throw error
        }
    }
    
    public func cancelExport() {
        isCancelled = true
    }
    
    // MARK: - Private Methods
    
    private func generateSRTContent(session: TranscriptionSession,
                                  configuration: SRTExportConfiguration,
                                  progressDelegate: ExportProgressDelegate?) throws -> String {
        
        var srtContent = ""
        var subtitleIndex = 1
        
        let totalSegments = Double(session.segments.count)
        
        for (index, segment) in session.segments.enumerated() {
            guard !isCancelled else { throw ExportError.cancelled }
            
            let progress = Double(index) / totalSegments
            progressDelegate?.exportDidUpdateProgress(progress, currentStep: "Processing segment \(index + 1) of \(session.segments.count)")
            
            // Process each segment into subtitles
            let subtitles = try createSubtitles(from: segment, configuration: configuration)
            
            for subtitle in subtitles {
                srtContent += "\(subtitleIndex)\n"
                srtContent += "\(subtitle.startTime.srtTimeFormat) --> \(subtitle.endTime.srtTimeFormat)\n"
                srtContent += "\(subtitle.text)\n\n"
                subtitleIndex += 1
            }
        }
        
        progressDelegate?.exportDidUpdateProgress(1.0, currentStep: "Export complete")
        
        return srtContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func createSubtitles(from segment: TranscriptionSegment,
                               configuration: SRTExportConfiguration) throws -> [Subtitle] {
        
        var subtitles: [Subtitle] = []
        
        // If we have word-level timing, use it for better subtitle creation
        if !segment.words.isEmpty {
            subtitles = createSubtitlesFromWords(segment.words, configuration: configuration)
        } else {
            // Fall back to segment-level timing
            subtitles = createSubtitlesFromSegment(segment, configuration: configuration)
        }
        
        // Ensure minimum duration
        subtitles = ensureMinimumDuration(subtitles, minimumDuration: configuration.minimumDuration)
        
        return subtitles
    }
    
    private func createSubtitlesFromWords(_ words: [WordTiming],
                                        configuration: SRTExportConfiguration) -> [Subtitle] {
        
        var subtitles: [Subtitle] = []
        var currentSubtitle = Subtitle(text: "", startTime: 0, endTime: 0)
        var currentLineLength = 0
        var currentLines = 0
        
        for (index, word) in words.enumerated() {
            let wordLength = word.word.count + 1 // +1 for space
            
            // Check if we need to start a new subtitle
            let needNewSubtitle = currentLineLength + wordLength > configuration.maxCharactersPerLine &&
                                currentLines >= configuration.maxLinesPerSubtitle - 1
            
            if needNewSubtitle && !currentSubtitle.text.isEmpty {
                // Finalize current subtitle
                currentSubtitle.text = currentSubtitle.text.trimmingCharacters(in: .whitespaces)
                subtitles.append(currentSubtitle)
                
                // Start new subtitle
                currentSubtitle = Subtitle(text: word.word,
                                         startTime: word.startTime,
                                         endTime: word.endTime)
                currentLineLength = wordLength
                currentLines = 0
            } else {
                // Add word to current subtitle
                if currentSubtitle.text.isEmpty {
                    currentSubtitle.startTime = word.startTime
                    currentSubtitle.text = word.word
                    currentLineLength = wordLength
                } else {
                    // Check if we need a line break
                    if currentLineLength + wordLength > configuration.maxCharactersPerLine {
                        currentSubtitle.text += "\n" + word.word
                        currentLineLength = wordLength
                        currentLines += 1
                    } else {
                        currentSubtitle.text += " " + word.word
                        currentLineLength += wordLength
                    }
                }
                currentSubtitle.endTime = word.endTime
            }
        }
        
        // Add the last subtitle
        if !currentSubtitle.text.isEmpty {
            currentSubtitle.text = currentSubtitle.text.trimmingCharacters(in: .whitespaces)
            subtitles.append(currentSubtitle)
        }
        
        return subtitles
    }
    
    private func createSubtitlesFromSegment(_ segment: TranscriptionSegment,
                                          configuration: SRTExportConfiguration) -> [Subtitle] {
        
        var subtitles: [Subtitle] = []
        let words = segment.text.split(separator: " ")
        
        if words.isEmpty {
            return subtitles
        }
        
        // Estimate timing for each word
        let totalDuration = segment.endTime - segment.startTime
        let durationPerWord = totalDuration / Double(words.count)
        
        var currentText = ""
        var currentStartTime = segment.startTime
        var currentWordCount = 0
        var currentLineLength = 0
        var currentLines = 0
        
        for (index, word) in words.enumerated() {
            let wordString = String(word)
            let wordLength = wordString.count + 1
            
            // Check if we need to start a new subtitle
            let needNewSubtitle = currentLineLength + wordLength > configuration.maxCharactersPerLine &&
                                currentLines >= configuration.maxLinesPerSubtitle - 1
            
            if needNewSubtitle && !currentText.isEmpty {
                // Create subtitle
                let endTime = segment.startTime + (durationPerWord * Double(currentWordCount))
                let subtitle = Subtitle(text: currentText.trimmingCharacters(in: .whitespaces),
                                      startTime: currentStartTime,
                                      endTime: endTime)
                subtitles.append(subtitle)
                
                // Reset for new subtitle
                currentText = wordString
                currentStartTime = endTime
                currentWordCount = 1
                currentLineLength = wordLength
                currentLines = 0
            } else {
                // Add word to current subtitle
                if currentText.isEmpty {
                    currentText = wordString
                    currentLineLength = wordLength
                } else {
                    // Check if we need a line break
                    if currentLineLength + wordLength > configuration.maxCharactersPerLine {
                        currentText += "\n" + wordString
                        currentLineLength = wordLength
                        currentLines += 1
                    } else {
                        currentText += " " + wordString
                        currentLineLength += wordLength
                    }
                }
                currentWordCount += 1
            }
        }
        
        // Add the last subtitle
        if !currentText.isEmpty {
            let subtitle = Subtitle(text: currentText.trimmingCharacters(in: .whitespaces),
                                  startTime: currentStartTime,
                                  endTime: segment.endTime)
            subtitles.append(subtitle)
        }
        
        return subtitles
    }
    
    private func ensureMinimumDuration(_ subtitles: [Subtitle],
                                     minimumDuration: TimeInterval) -> [Subtitle] {
        
        var adjustedSubtitles: [Subtitle] = []
        
        for (index, subtitle) in subtitles.enumerated() {
            var adjustedSubtitle = subtitle
            let duration = subtitle.endTime - subtitle.startTime
            
            if duration < minimumDuration {
                // Extend the end time to meet minimum duration
                adjustedSubtitle.endTime = subtitle.startTime + minimumDuration
                
                // Check if this overlaps with the next subtitle
                if index < subtitles.count - 1 {
                    let nextSubtitle = subtitles[index + 1]
                    if adjustedSubtitle.endTime > nextSubtitle.startTime {
                        // Adjust to just before the next subtitle
                        adjustedSubtitle.endTime = nextSubtitle.startTime - 0.001
                    }
                }
            }
            
            adjustedSubtitles.append(adjustedSubtitle)
        }
        
        return adjustedSubtitles
    }
    
    // MARK: - Helper Types
    
    private struct Subtitle {
        var text: String
        var startTime: TimeInterval
        var endTime: TimeInterval
    }
}

// MARK: - SRT Export Extensions

extension SRTExporter {
    /// Export with custom subtitle styling (for platforms that support it)
    public func exportWithStyling(session: TranscriptionSession,
                                configuration: SRTExportConfiguration,
                                styling: SubtitleStyling,
                                progressDelegate: ExportProgressDelegate?) async throws -> ExportResult {
        
        // Generate base SRT content
        let baseSRT = try await export(session: session,
                                     configuration: configuration,
                                     progressDelegate: progressDelegate)
        
        guard case .data(let srtData) = baseSRT,
              var srtString = String(data: srtData, encoding: .utf8) else {
            throw ExportError.encodingError(NSError(domain: "SRTExporter",
                                                   code: 2,
                                                   userInfo: [NSLocalizedDescriptionKey: "Failed to create styled SRT"]))
        }
        
        // Apply styling tags if supported
        if styling.supportsSRTStyling {
            srtString = applyStylingToSRT(srtString, styling: styling)
        }
        
        guard let styledData = srtString.data(using: .utf8) else {
            throw ExportError.encodingError(NSError(domain: "SRTExporter",
                                                   code: 3,
                                                   userInfo: [NSLocalizedDescriptionKey: "Failed to encode styled SRT"]))
        }
        
        return .data(styledData)
    }
    
    private func applyStylingToSRT(_ srt: String, styling: SubtitleStyling) -> String {
        // This is a simplified implementation
        // Real implementation would parse SRT and apply appropriate styling tags
        var styledSRT = srt
        
        if styling.bold {
            styledSRT = styledSRT.replacingOccurrences(of: "\n\n", with: "</b>\n\n<b>")
            styledSRT = "<b>" + styledSRT + "</b>"
        }
        
        if styling.italic {
            styledSRT = styledSRT.replacingOccurrences(of: "\n\n", with: "</i>\n\n<i>")
            styledSRT = "<i>" + styledSRT + "</i>"
        }
        
        return styledSRT
    }
}

// MARK: - Supporting Types

public struct SubtitleStyling {
    public let bold: Bool
    public let italic: Bool
    public let underline: Bool
    public let color: String?
    public let supportsSRTStyling: Bool
    
    public init(bold: Bool = false,
                italic: Bool = false,
                underline: Bool = false,
                color: String? = nil,
                supportsSRTStyling: Bool = false) {
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.color = color
        self.supportsSRTStyling = supportsSRTStyling
    }
}