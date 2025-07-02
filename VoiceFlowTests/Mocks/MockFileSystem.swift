//
//  MockFileSystem.swift
//  VoiceFlowTests
//
//  Mock implementation of file system operations for testing
//

import Foundation

/// Thread-safe mock file system for testing file operations
public final actor MockFileSystem: Sendable {
    // MARK: - Properties
    
    /// Virtual file system storage
    private var files: [String: FileNode] = [:]
    
    /// Current working directory
    private var currentDirectory: String = "/"
    
    /// Error to throw on next operation
    private var nextError: Error?
    
    /// Operation delay for simulating I/O
    private var ioDelay: TimeInterval = 0.001
    
    /// File system statistics
    private var statistics = Statistics()
    
    /// Access control
    private var permissions: [String: FilePermissions] = [:]
    
    // MARK: - Types
    
    public struct FileNode: Sendable {
        public let path: String
        public let isDirectory: Bool
        public var contents: Data
        public var attributes: FileAttributes
        public var children: Set<String>
        
        public init(
            path: String,
            isDirectory: Bool,
            contents: Data = Data(),
            attributes: FileAttributes = FileAttributes()
        ) {
            self.path = path
            self.isDirectory = isDirectory
            self.contents = contents
            self.attributes = attributes
            self.children = []
        }
    }
    
    public struct FileAttributes: Sendable {
        public var creationDate: Date
        public var modificationDate: Date
        public var size: Int
        public var isHidden: Bool
        public var isReadOnly: Bool
        
        public init(
            creationDate: Date = Date(),
            modificationDate: Date = Date(),
            size: Int = 0,
            isHidden: Bool = false,
            isReadOnly: Bool = false
        ) {
            self.creationDate = creationDate
            self.modificationDate = modificationDate
            self.size = size
            self.isHidden = isHidden
            self.isReadOnly = isReadOnly
        }
    }
    
    public struct FilePermissions: Sendable {
        public var canRead: Bool
        public var canWrite: Bool
        public var canExecute: Bool
        
        public init(canRead: Bool = true, canWrite: Bool = true, canExecute: Bool = false) {
            self.canRead = canRead
            self.canWrite = canWrite
            self.canExecute = canExecute
        }
    }
    
    public struct Statistics: Sendable {
        public var totalFiles: Int = 0
        public var totalDirectories: Int = 0
        public var totalSize: Int = 0
        public var readOperations: Int = 0
        public var writeOperations: Int = 0
        public var deleteOperations: Int = 0
    }
    
    public enum MockError: LocalizedError, Sendable {
        case fileNotFound(String)
        case fileAlreadyExists(String)
        case notADirectory(String)
        case notAFile(String)
        case permissionDenied(String)
        case diskFull
        case invalidPath(String)
        case ioError(String)
        
        public var errorDescription: String? {
            switch self {
            case .fileNotFound(let path):
                return "File not found: \(path)"
            case .fileAlreadyExists(let path):
                return "File already exists: \(path)"
            case .notADirectory(let path):
                return "Not a directory: \(path)"
            case .notAFile(let path):
                return "Not a file: \(path)"
            case .permissionDenied(let path):
                return "Permission denied: \(path)"
            case .diskFull:
                return "Disk is full"
            case .invalidPath(let path):
                return "Invalid path: \(path)"
            case .ioError(let message):
                return "I/O error: \(message)"
            }
        }
    }
    
    // MARK: - Initialization
    
    public init() {
        // Create root directory
        files["/"] = FileNode(path: "/", isDirectory: true)
    }
    
    // MARK: - Configuration
    
    public func setNextError(_ error: Error?) {
        self.nextError = error
    }
    
    public func setIODelay(_ delay: TimeInterval) {
        self.ioDelay = max(0, delay)
    }
    
    public func setPermissions(_ permissions: FilePermissions, for path: String) {
        self.permissions[path] = permissions
    }
    
    // MARK: - File Operations
    
    public func createFile(at path: String, contents: Data = Data()) async throws {
        try await simulateIO()
        
        if let error = nextError {
            nextError = nil
            throw error
        }
        
        let normalizedPath = normalizePath(path)
        
        guard !files.keys.contains(normalizedPath) else {
            throw MockError.fileAlreadyExists(normalizedPath)
        }
        
        guard let parentPath = parentDirectory(of: normalizedPath) else {
            throw MockError.invalidPath(normalizedPath)
        }
        
        guard let parent = files[parentPath], parent.isDirectory else {
            throw MockError.notADirectory(parentPath)
        }
        
        // Check permissions
        if let perms = permissions[parentPath], !perms.canWrite {
            throw MockError.permissionDenied(parentPath)
        }
        
        // Create file
        var fileNode = FileNode(
            path: normalizedPath,
            isDirectory: false,
            contents: contents,
            attributes: FileAttributes(size: contents.count)
        )
        
        files[normalizedPath] = fileNode
        
        // Update parent
        var updatedParent = parent
        updatedParent.children.insert(normalizedPath)
        files[parentPath] = updatedParent
        
        // Update statistics
        statistics.totalFiles += 1
        statistics.totalSize += contents.count
        statistics.writeOperations += 1
    }
    
    public func createDirectory(at path: String) async throws {
        try await simulateIO()
        
        if let error = nextError {
            nextError = nil
            throw error
        }
        
        let normalizedPath = normalizePath(path)
        
        guard !files.keys.contains(normalizedPath) else {
            throw MockError.fileAlreadyExists(normalizedPath)
        }
        
        guard let parentPath = parentDirectory(of: normalizedPath) else {
            throw MockError.invalidPath(normalizedPath)
        }
        
        guard let parent = files[parentPath], parent.isDirectory else {
            throw MockError.notADirectory(parentPath)
        }
        
        // Check permissions
        if let perms = permissions[parentPath], !perms.canWrite {
            throw MockError.permissionDenied(parentPath)
        }
        
        // Create directory
        let dirNode = FileNode(path: normalizedPath, isDirectory: true)
        files[normalizedPath] = dirNode
        
        // Update parent
        var updatedParent = parent
        updatedParent.children.insert(normalizedPath)
        files[parentPath] = updatedParent
        
        // Update statistics
        statistics.totalDirectories += 1
        statistics.writeOperations += 1
    }
    
    public func readFile(at path: String) async throws -> Data {
        try await simulateIO()
        
        if let error = nextError {
            nextError = nil
            throw error
        }
        
        let normalizedPath = normalizePath(path)
        
        guard let file = files[normalizedPath] else {
            throw MockError.fileNotFound(normalizedPath)
        }
        
        guard !file.isDirectory else {
            throw MockError.notAFile(normalizedPath)
        }
        
        // Check permissions
        if let perms = permissions[normalizedPath], !perms.canRead {
            throw MockError.permissionDenied(normalizedPath)
        }
        
        statistics.readOperations += 1
        
        return file.contents
    }
    
    public func writeFile(at path: String, contents: Data) async throws {
        try await simulateIO()
        
        if let error = nextError {
            nextError = nil
            throw error
        }
        
        let normalizedPath = normalizePath(path)
        
        guard var file = files[normalizedPath] else {
            // Create file if it doesn't exist
            try await createFile(at: path, contents: contents)
            return
        }
        
        guard !file.isDirectory else {
            throw MockError.notAFile(normalizedPath)
        }
        
        // Check permissions
        if let perms = permissions[normalizedPath], !perms.canWrite {
            throw MockError.permissionDenied(normalizedPath)
        }
        
        if file.attributes.isReadOnly {
            throw MockError.permissionDenied(normalizedPath)
        }
        
        // Update file
        let oldSize = file.contents.count
        file.contents = contents
        file.attributes.modificationDate = Date()
        file.attributes.size = contents.count
        
        files[normalizedPath] = file
        
        // Update statistics
        statistics.totalSize += (contents.count - oldSize)
        statistics.writeOperations += 1
    }
    
    public func deleteFile(at path: String) async throws {
        try await simulateIO()
        
        if let error = nextError {
            nextError = nil
            throw error
        }
        
        let normalizedPath = normalizePath(path)
        
        guard let file = files[normalizedPath] else {
            throw MockError.fileNotFound(normalizedPath)
        }
        
        // Check permissions
        if let perms = permissions[normalizedPath], !perms.canWrite {
            throw MockError.permissionDenied(normalizedPath)
        }
        
        // Remove from parent
        if let parentPath = parentDirectory(of: normalizedPath),
           var parent = files[parentPath] {
            parent.children.remove(normalizedPath)
            files[parentPath] = parent
        }
        
        // Remove file
        files.removeValue(forKey: normalizedPath)
        
        // Update statistics
        if file.isDirectory {
            statistics.totalDirectories -= 1
        } else {
            statistics.totalFiles -= 1
            statistics.totalSize -= file.contents.count
        }
        statistics.deleteOperations += 1
    }
    
    public func listDirectory(at path: String) async throws -> [String] {
        try await simulateIO()
        
        if let error = nextError {
            nextError = nil
            throw error
        }
        
        let normalizedPath = normalizePath(path)
        
        guard let dir = files[normalizedPath] else {
            throw MockError.fileNotFound(normalizedPath)
        }
        
        guard dir.isDirectory else {
            throw MockError.notADirectory(normalizedPath)
        }
        
        // Check permissions
        if let perms = permissions[normalizedPath], !perms.canRead {
            throw MockError.permissionDenied(normalizedPath)
        }
        
        statistics.readOperations += 1
        
        return Array(dir.children).sorted()
    }
    
    public func fileExists(at path: String) async -> Bool {
        let normalizedPath = normalizePath(path)
        return files[normalizedPath] != nil
    }
    
    public func isDirectory(at path: String) async -> Bool {
        let normalizedPath = normalizePath(path)
        return files[normalizedPath]?.isDirectory ?? false
    }
    
    // MARK: - Helper Methods
    
    private func normalizePath(_ path: String) -> String {
        // Simple path normalization
        var normalized = path
        
        // Handle relative paths
        if !normalized.hasPrefix("/") {
            normalized = currentDirectory + "/" + normalized
        }
        
        // Remove trailing slashes except for root
        if normalized.count > 1 && normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        
        // Simplify path components
        let components = normalized.split(separator: "/").filter { !$0.isEmpty }
        var resolvedComponents: [String] = []
        
        for component in components {
            if component == ".." {
                if !resolvedComponents.isEmpty {
                    resolvedComponents.removeLast()
                }
            } else if component != "." {
                resolvedComponents.append(String(component))
            }
        }
        
        return "/" + resolvedComponents.joined(separator: "/")
    }
    
    private func parentDirectory(of path: String) -> String? {
        guard path != "/" else { return nil }
        
        let components = path.split(separator: "/").dropLast()
        if components.isEmpty {
            return "/"
        }
        
        return "/" + components.joined(separator: "/")
    }
    
    private func simulateIO() async throws {
        if ioDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(ioDelay * 1_000_000_000))
        }
    }
    
    // MARK: - Test Helpers
    
    public func getStatistics() -> Statistics {
        return statistics
    }
    
    public func resetStatistics() {
        statistics = Statistics()
    }
    
    public func reset() {
        files.removeAll()
        files["/"] = FileNode(path: "/", isDirectory: true)
        permissions.removeAll()
        statistics = Statistics()
        currentDirectory = "/"
    }
    
    public func createTestHierarchy() async throws {
        // Create a typical project structure
        let directories = [
            "/Documents",
            "/Documents/Projects",
            "/Documents/Projects/VoiceFlow",
            "/Documents/Projects/VoiceFlow/Transcripts",
            "/Downloads",
            "/Desktop"
        ]
        
        for dir in directories {
            try await createDirectory(at: dir)
        }
        
        // Add some test files
        let testContent = "Test content".data(using: .utf8)!
        try await createFile(at: "/Documents/test.txt", contents: testContent)
        try await createFile(at: "/Documents/Projects/README.md", contents: testContent)
    }
}

// MARK: - Test Data Factory

public struct MockFileSystemFactory {
    public static func createEmptyFileSystem() -> MockFileSystem {
        return MockFileSystem()
    }
    
    public static func createWithTestData() async throws -> MockFileSystem {
        let fs = MockFileSystem()
        try await fs.createTestHierarchy()
        return fs
    }
    
    public static func createRestrictedFileSystem() async -> MockFileSystem {
        let fs = MockFileSystem()
        
        // Set restrictive permissions
        await fs.setPermissions(
            FilePermissions(canRead: true, canWrite: false),
            for: "/System"
        )
        
        return fs
    }
    
    public static func createFailingFileSystem() async -> MockFileSystem {
        let fs = MockFileSystem()
        await fs.setNextError(MockFileSystem.MockError.diskFull)
        return fs
    }
}