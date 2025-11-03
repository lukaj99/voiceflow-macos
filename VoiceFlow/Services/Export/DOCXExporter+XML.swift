import Foundation

// MARK: - XML Generation Extension

extension DOCXExporter {
    // Note: These methods are internal (not private) to allow extension access

    func generateContentTypes(at directory: URL) throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            <Default Extension="rels" \
        ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            <Default Extension="xml" ContentType="application/xml"/>
            <Override PartName="/word/document.xml" \
        ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
            <Override PartName="/word/header1.xml" \
        ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>
            <Override PartName="/word/footer1.xml" \
        ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>
        </Types>
        """

        let url = directory.appendingPathComponent("[Content_Types].xml")
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }

    func generateRels(at directory: URL) throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" \
        Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" \
        Target="word/document.xml"/>
        </Relationships>
        """

        let url = directory.appendingPathComponent(".rels")
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }

    func generateDocumentRels(at directory: URL, options: FormattingOptions) throws {
        var relationships = ""
        var rId = 1

        if options.headerEnabled {
            let headerRel = "<Relationship Id=\"rId\(rId)\" " +
                "Type=\"http://schemas.openxmlformats.org/officeDocument" +
                "/2006/relationships/header\" Target=\"header1.xml\"/>"
            relationships += "    " + headerRel + "\n"
            rId += 1
        }

        if options.footerEnabled {
            let footerRel = "<Relationship Id=\"rId\(rId)\" " +
                "Type=\"http://schemas.openxmlformats.org/officeDocument" +
                "/2006/relationships/footer\" Target=\"footer1.xml\"/>"
            relationships += "    " + footerRel + "\n"
        }

        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        \(relationships)</Relationships>
        """

        let url = directory.appendingPathComponent("document.xml.rels")
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }

    func generateHeader(at directory: URL, session: TranscriptionSession) throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:p>
                <w:pPr>
                    <w:jc w:val="right"/>
                </w:pPr>
                <w:r>
                    <w:rPr>
                        <w:sz w:val="20"/>
                        <w:color w:val="808080"/>
                    </w:rPr>
                    <w:t>VoiceFlow - \(formatDate(session.startTime))</w:t>
                </w:r>
            </w:p>
        </w:hdr>
        """

        let url = directory.appendingPathComponent("header1.xml")
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }

    func generateFooter(at directory: URL, session: TranscriptionSession) throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:p>
                <w:pPr>
                    <w:jc w:val="center"/>
                </w:pPr>
                <w:r>
                    <w:rPr>
                        <w:sz w:val="20"/>
                        <w:color w:val="808080"/>
                    </w:rPr>
                    <w:t>Session ID: \(session.id.uuidString)</w:t>
                </w:r>
            </w:p>
        </w:ftr>
        """

        let url = directory.appendingPathComponent("footer1.xml")
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }

    func generateDocument(
        at directory: URL,
        session: TranscriptionSession,
        configuration: ExportConfiguration,
        options: FormattingOptions
    ) throws {
        var paragraphs = ""

        // Title
        paragraphs += generateParagraph(
            text: "VoiceFlow Transcription",
            bold: options.boldTitle,
            fontSize: options.fontSize + 4
        )

        // Metadata section
        if configuration.includeMetadata {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short

            paragraphs += generateParagraph(
                text: "Date: \(dateFormatter.string(from: session.startTime))",
                italic: options.italicMetadata,
                fontSize: options.fontSize - 1
            )

            paragraphs += generateParagraph(
                text: "Duration: \(formatDuration(session.duration))",
                italic: options.italicMetadata,
                fontSize: options.fontSize - 1
            )

            paragraphs += generateParagraph(
                text: "Words: \(session.wordCount)",
                italic: options.italicMetadata,
                fontSize: options.fontSize - 1
            )

            paragraphs += generateParagraph(
                text: "Confidence: \(Int(session.averageConfidence * 100))%",
                italic: options.italicMetadata,
                fontSize: options.fontSize - 1
            )

            // Separator
            paragraphs += generateParagraph(text: "")
        }

        // Transcription content
        let lines = session.transcription.components(separatedBy: .newlines)
        for line in lines {
            paragraphs += generateParagraph(
                text: line.isEmpty ? " " : xmlEscape(line),
                fontSize: options.fontSize
            )
        }

        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:body>
        \(paragraphs)
            </w:body>
        </w:document>
        """

        let url = directory.appendingPathComponent("document.xml")
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }

    func generateParagraph(
        text: String,
        bold: Bool = false,
        italic: Bool = false,
        fontSize: Int = 11
    ) -> String {
        var runProperties = ""

        if bold {
            runProperties += "<w:b/>"
        }
        if italic {
            runProperties += "<w:i/>"
        }
        runProperties += "<w:sz w:val=\"\(fontSize * 2)\"/>"

        return """
                <w:p>
                    <w:r>
                        <w:rPr>
        \(runProperties)
                        </w:rPr>
                        <w:t>\(text)</w:t>
                    </w:r>
                </w:p>

        """
    }
}
