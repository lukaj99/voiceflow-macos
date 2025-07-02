import Foundation

/// Provides comprehensive file path validation and secure file operations
public final class FileValidator {
    
    // MARK: - Constants
    
    private static let maxPathLength = 1024
    private static let maxFilenameLength = 255
    private static let forbiddenCharacters = CharacterSet(charactersIn: "\0")
    private static let pathTraversalPatterns = ["../", "..", "~", "./", "//"]
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private let allowedDirectories: Set<URL>
    
    // MARK: - Initialization
    
    public init(allowedDirectories: [URL]? = nil) {
        if let directories = allowedDirectories {
            self.allowedDirectories = Set(directories)
        } else {
            // Default allowed directories
            self.allowedDirectories = Set([
                FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!,
                FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!,
                FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!,
                FileManager.default.temporaryDirectory
            ])
        }
    }
    
    // MARK: - Public Validation Methods
    
    /// Validates a file path for security vulnerabilities
    public func validatePath(_ path: String) throws -> URL {
        // Check path length
        guard path.count <= Self.maxPathLength else {
            throw FileValidationError.pathTooLong(path.count, Self.maxPathLength)
        }
        
        // Check for null bytes
        guard path.rangeOfCharacter(from: Self.forbiddenCharacters) == nil else {
            throw FileValidationError.invalidCharacters("Path contains forbidden characters")
        }
        
        // Check for path traversal attempts
        for pattern in Self.pathTraversalPatterns {
            if path.contains(pattern) {
                throw FileValidationError.pathTraversal("Path contains traversal pattern: \(pattern)")
            }
        }
        
        // Create URL and resolve it
        let url = URL(fileURLWithPath: path)
        let resolvedURL = try resolveAndValidateURL(url)
        
        return resolvedURL
    }
    
    /// Validates a file URL
    public func validateURL(_ url: URL) throws -> URL {
        guard url.isFileURL else {
            throw FileValidationError.notFileURL("URL is not a file URL: \(url)")
        }
        
        return try resolveAndValidateURL(url)
    }
    
    /// Validates a filename
    public func validateFilename(_ filename: String) throws {
        // Check filename length
        guard filename.count <= Self.maxFilenameLength else {
            throw FileValidationError.filenameTooLong(filename.count, Self.maxFilenameLength)
        }
        
        // Check for empty filename
        guard !filename.isEmpty else {
            throw FileValidationError.emptyFilename
        }
        
        // Check for forbidden characters
        guard filename.rangeOfCharacter(from: Self.forbiddenCharacters) == nil else {
            throw FileValidationError.invalidCharacters("Filename contains forbidden characters")
        }
        
        // Check for reserved names (Windows compatibility)
        let reservedNames = ["CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", 
                           "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", 
                           "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"]
        
        let uppercaseFilename = filename.uppercased()
        let nameWithoutExtension = (uppercaseFilename as NSString).deletingPathExtension
        
        if reservedNames.contains(nameWithoutExtension) {
            throw FileValidationError.reservedFilename(filename)
        }
        
        // Check for leading/trailing spaces or dots
        if filename.hasPrefix(" ") || filename.hasSuffix(" ") ||
           filename.hasPrefix(".") || filename.hasSuffix(".") {
            throw FileValidationError.invalidFilenameFormat("Filename cannot start or end with spaces or dots")
        }
    }
    
    /// Creates a secure file path within allowed directories
    public func createSecurePath(filename: String, in directory: URL? = nil) throws -> URL {
        // Validate filename
        try validateFilename(filename)
        
        // Use provided directory or default to documents
        let targetDirectory = directory ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Validate the directory is allowed
        let resolvedDirectory = try resolveAndValidateURL(targetDirectory)
        
        // Ensure directory is in allowed list
        guard isURLAllowed(resolvedDirectory) else {
            throw FileValidationError.directoryNotAllowed("Directory is not in allowed list: \(resolvedDirectory.path)")
        }
        
        // Sanitize filename
        let sanitizedFilename = sanitizeFilename(filename)
        
        // Create the full path
        let fullPath = resolvedDirectory.appendingPathComponent(sanitizedFilename)
        
        // Final validation
        return try resolveAndValidateURL(fullPath)
    }
    
    /// Validates export path with additional security checks
    public func validateExportPath(_ url: URL, allowOverwrite: Bool = false) throws -> URL {
        // First, do standard validation
        let validatedURL = try validateURL(url)
        
        // Check if file already exists
        if !allowOverwrite && fileManager.fileExists(atPath: validatedURL.path) {
            throw FileValidationError.fileAlreadyExists(validatedURL.path)
        }
        
        // Ensure parent directory exists and is writable
        let parentDirectory = validatedURL.deletingLastPathComponent()
        
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: parentDirectory.path, isDirectory: &isDirectory) else {
            throw FileValidationError.parentDirectoryNotFound(parentDirectory.path)
        }
        
        guard isDirectory.boolValue else {
            throw FileValidationError.notADirectory(parentDirectory.path)
        }
        
        guard fileManager.isWritableFile(atPath: parentDirectory.path) else {
            throw FileValidationError.noWritePermission(parentDirectory.path)
        }
        
        return validatedURL
    }
    
    // MARK: - Private Methods
    
    private func resolveAndValidateURL(_ url: URL) throws -> URL {
        // Resolve symlinks and relative paths
        let resolvedURL = url.standardizedFileURL.resolvingSymlinksInPath()
        
        // Ensure the resolved path doesn't escape allowed directories
        guard isURLAllowed(resolvedURL) else {
            throw FileValidationError.pathTraversal("Resolved path escapes allowed directories: \(resolvedURL.path)")
        }
        
        return resolvedURL
    }
    
    private func isURLAllowed(_ url: URL) -> Bool {
        // Check if URL is within any allowed directory
        for allowedDir in allowedDirectories {
            let resolvedAllowedDir = allowedDir.standardizedFileURL.resolvingSymlinksInPath()
            if url.path.hasPrefix(resolvedAllowedDir.path) {
                return true
            }
        }
        return false
    }
    
    private func sanitizeFilename(_ filename: String) -> String {
        var sanitized = filename
        
        // Replace potentially problematic characters
        let replacements = [
            "/": "-",
            "\\": "-",
            ":": "-",
            "*": "-",
            "?": "-",
            "\"": "'",
            "<": "[",
            ">": "]",
            "|": "-"
        ]
        
        for (char, replacement) in replacements {
            sanitized = sanitized.replacingOccurrences(of: char, with: replacement)
        }
        
        // Remove control characters
        let controlCharacters = CharacterSet.controlCharacters
        sanitized = sanitized.components(separatedBy: controlCharacters).joined()
        
        // Trim whitespace
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Ensure non-empty
        if sanitized.isEmpty {
            sanitized = "unnamed"
        }
        
        return sanitized
    }
}

// MARK: - File Validation Errors

public enum FileValidationError: LocalizedError {
    case pathTooLong(Int, Int)
    case filenameTooLong(Int, Int)
    case invalidCharacters(String)
    case pathTraversal(String)
    case notFileURL(String)
    case emptyFilename
    case reservedFilename(String)
    case invalidFilenameFormat(String)
    case directoryNotAllowed(String)
    case fileAlreadyExists(String)
    case parentDirectoryNotFound(String)
    case notADirectory(String)
    case noWritePermission(String)
    
    public var errorDescription: String? {
        switch self {
        case .pathTooLong(let actual, let max):
            return "Path too long: \(actual) characters (maximum: \(max))"
        case .filenameTooLong(let actual, let max):
            return "Filename too long: \(actual) characters (maximum: \(max))"
        case .invalidCharacters(let message):
            return "Invalid characters: \(message)"
        case .pathTraversal(let message):
            return "Path traversal detected: \(message)"
        case .notFileURL(let message):
            return "Not a file URL: \(message)"
        case .emptyFilename:
            return "Filename cannot be empty"
        case .reservedFilename(let name):
            return "Reserved filename: \(name)"
        case .invalidFilenameFormat(let message):
            return "Invalid filename format: \(message)"
        case .directoryNotAllowed(let message):
            return "Directory not allowed: \(message)"
        case .fileAlreadyExists(let path):
            return "File already exists: \(path)"
        case .parentDirectoryNotFound(let path):
            return "Parent directory not found: \(path)"
        case .notADirectory(let path):
            return "Not a directory: \(path)"
        case .noWritePermission(let path):
            return "No write permission: \(path)"
        }
    }
}

// MARK: - Secure File Operations

extension FileValidator {
    
    /// Securely writes data to a file
    public func secureWrite(data: Data, to url: URL, options: Data.WritingOptions = []) throws {
        let validatedURL = try validateExportPath(url, allowOverwrite: true)
        
        // Add secure writing options
        var secureOptions = options
        secureOptions.insert(.atomic) // Write to temp file first
        secureOptions.insert(.completeFileProtection) // Encrypt on disk
        
        try data.write(to: validatedURL, options: secureOptions)
        
        // Set appropriate file permissions (owner read/write only)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: validatedURL.path)
    }
    
    /// Securely creates a directory
    public func secureCreateDirectory(at url: URL) throws {
        let validatedURL = try validateURL(url)
        
        guard isURLAllowed(validatedURL) else {
            throw FileValidationError.directoryNotAllowed("Cannot create directory outside allowed paths")
        }
        
        try fileManager.createDirectory(at: validatedURL, 
                                      withIntermediateDirectories: true,
                                      attributes: [.posixPermissions: 0o700]) // Owner only
    }
}