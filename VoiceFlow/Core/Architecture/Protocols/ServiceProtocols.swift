//
//  ServiceProtocols.swift
//  VoiceFlow
//
//  Created by Claude Code on 2025-11-02.
//  Copyright © 2025 VoiceFlow. All rights reserved.
//

import Foundation
import AVFoundation

// MARK: - Service Lifecycle Protocol

/// Protocol defining the lifecycle of a service
/// Ensures consistent initialization, startup, and shutdown patterns across all services
@MainActor
protocol ServiceLifecycleProtocol: Sendable {
    /// Initializes the service with required dependencies
    /// - Throws: ServiceError if initialization fails
    func initialize() async throws

    /// Starts the service and begins processing
    /// - Throws: ServiceError if service cannot start
    func start() async throws

    /// Stops the service gracefully
    /// - Throws: ServiceError if service cannot stop cleanly
    func stop() async throws

    /// Current state of the service
    var isRunning: Bool { get async }
}

// MARK: - Transcription Service Protocol

/// Protocol for speech-to-text transcription services
/// Provides async transcription with streaming support and configuration options
protocol TranscriptionServiceProtocol: ServiceLifecycleProtocol {
    /// Configuration for transcription behavior
    associatedtype Configuration: TranscriptionConfiguration

    /// Starts transcription with the provided configuration
    /// - Parameter configuration: Settings for transcription behavior
    /// - Returns: AsyncStream of transcription results
    /// - Throws: TranscriptionError if transcription cannot start
    func startTranscription(
        configuration: Configuration
    ) async throws -> AsyncStream<TranscriptionResult>

    /// Stops active transcription
    /// - Throws: TranscriptionError if transcription cannot stop cleanly
    func stopTranscription() async throws

    /// Checks if transcription is currently active
    var isTranscribing: Bool { get async }

    /// Available languages for transcription
    var supportedLanguages: [String] { get async }

    /// Pauses active transcription without stopping
    /// - Throws: TranscriptionError if pause fails
    func pauseTranscription() async throws

    /// Resumes paused transcription
    /// - Throws: TranscriptionError if resume fails
    func resumeTranscription() async throws
}

/// Configuration requirements for transcription services
protocol TranscriptionConfiguration: Sendable {
    /// Language code (e.g., "en-US")
    var language: String { get }

    /// Whether to add punctuation automatically
    var shouldAddPunctuation: Bool { get }

    /// Whether to detect and separate speakers
    var enableSpeakerDetection: Bool { get }

    /// Minimum confidence threshold (0.0-1.0)
    var confidenceThreshold: Double { get }
}

/// Result from transcription operation
struct TranscriptionResult: Sendable {
    /// Transcribed text
    let text: String

    /// Whether this is a final result or interim
    let isFinal: Bool

    /// Confidence score (0.0-1.0)
    let confidence: Double

    /// Timestamp of the transcription
    let timestamp: Date

    /// Optional speaker identifier
    let speakerID: String?

    /// Duration of the audio segment
    let duration: TimeInterval?
}

// MARK: - Audio Service Protocol

/// Protocol for audio capture and processing services
/// Handles audio input, monitoring, and format conversion
protocol AudioServiceProtocol: ServiceLifecycleProtocol {
    /// Configuration for audio capture
    associatedtype Configuration: AudioConfiguration

    /// Starts audio capture with configuration
    /// - Parameter configuration: Audio capture settings
    /// - Returns: AsyncStream of audio buffers
    /// - Throws: AudioError if capture cannot start
    func startCapture(
        configuration: Configuration
    ) async throws -> AsyncStream<AudioBuffer>

    /// Stops audio capture
    /// - Throws: AudioError if capture cannot stop cleanly
    func stopCapture() async throws

    /// Whether audio is currently being captured
    var isCapturing: Bool { get async }

    /// Current audio input level (0.0-1.0)
    var inputLevel: Float { get async }

    /// Available audio input devices
    var availableInputDevices: [AudioDevice] { get async }

    /// Currently selected input device
    var currentInputDevice: AudioDevice? { get async }

    /// Sets the active input device
    /// - Parameter device: The device to use for input
    /// - Throws: AudioError if device cannot be set
    func setInputDevice(_ device: AudioDevice) async throws
}

/// Configuration for audio services
protocol AudioConfiguration: Sendable {
    /// Sample rate in Hz
    var sampleRate: Double { get }

    /// Number of audio channels
    var channelCount: Int { get }

    /// Audio format (PCM, etc.)
    var format: AudioFormat { get }

    /// Buffer size for audio processing
    var bufferSize: Int { get }
}

/// Audio device representation
struct AudioDevice: Sendable, Identifiable {
    let id: String
    let name: String
    let manufacturer: String
    let inputChannels: Int
    let outputChannels: Int
}

/// Audio format specification
enum AudioFormat: Sendable {
    case pcm16
    case pcm24
    case pcm32
    case float32
}

/// Audio buffer for processing
struct AudioBuffer: Sendable {
    let data: Data
    let format: AudioFormat
    let sampleRate: Double
    let channelCount: Int
    let frameCount: Int
    let timestamp: Date
}

// MARK: - Storage Service Protocol

/// Protocol for persistent data storage services
/// Provides CRUD operations with async support and querying
protocol StorageServiceProtocol: ServiceLifecycleProtocol {
    /// Type of entity stored by this service
    associatedtype Entity: StorableEntity

    /// Saves an entity to storage
    /// - Parameter entity: The entity to save
    /// - Throws: StorageError if save fails
    func save(_ entity: Entity) async throws

    /// Saves multiple entities in a batch
    /// - Parameter entities: Array of entities to save
    /// - Throws: StorageError if batch save fails
    func saveBatch(_ entities: [Entity]) async throws

    /// Fetches an entity by identifier
    /// - Parameter id: Unique identifier
    /// - Returns: The entity if found, nil otherwise
    /// - Throws: StorageError if fetch fails
    func fetch(id: Entity.ID) async throws -> Entity?

    /// Fetches all entities matching a predicate
    /// - Parameter predicate: Optional filter predicate
    /// - Returns: Array of matching entities
    /// - Throws: StorageError if fetch fails
    func fetchAll(where predicate: StoragePredicate<Entity>?) async throws -> [Entity]

    /// Deletes an entity by identifier
    /// - Parameter id: Unique identifier
    /// - Throws: StorageError if delete fails
    func delete(id: Entity.ID) async throws

    /// Deletes all entities matching a predicate
    /// - Parameter predicate: Filter predicate
    /// - Throws: StorageError if delete fails
    func deleteAll(where predicate: StoragePredicate<Entity>) async throws

    /// Updates an entity
    /// - Parameter entity: The entity with updated values
    /// - Throws: StorageError if update fails
    func update(_ entity: Entity) async throws

    /// Returns total count of entities
    var count: Int { get async throws }
}

/// Protocol for entities that can be stored
protocol StorableEntity: Sendable, Identifiable, Codable {
    /// Timestamp when entity was created
    var createdAt: Date { get }

    /// Timestamp when entity was last updated
    var updatedAt: Date { get }
}

/// Type-safe predicate for storage queries
struct StoragePredicate<Entity: StorableEntity>: Sendable {
    let evaluate: @Sendable (Entity) -> Bool

    init(_ evaluate: @escaping @Sendable (Entity) -> Bool) {
        self.evaluate = evaluate
    }
}

// MARK: - Network Service Protocol

/// Protocol for network communication services
/// Handles HTTP requests with async/await and streaming support
protocol NetworkServiceProtocol: ServiceLifecycleProtocol {
    /// Performs a network request
    /// - Parameter request: The request to perform
    /// - Returns: Response data and metadata
    /// - Throws: NetworkError if request fails
    func perform<T: Decodable>(
        _ request: NetworkRequest
    ) async throws -> NetworkResponse<T>

    /// Uploads data to a remote endpoint
    /// - Parameters:
    ///   - data: Data to upload
    ///   - request: Upload request configuration
    /// - Returns: Upload response
    /// - Throws: NetworkError if upload fails
    func upload(
        _ data: Data,
        request: NetworkRequest
    ) async throws -> NetworkResponse<UploadResult>

    /// Downloads data from a remote endpoint
    /// - Parameter request: Download request configuration
    /// - Returns: AsyncStream of download progress and final data
    /// - Throws: NetworkError if download fails
    func download(
        _ request: NetworkRequest
    ) async throws -> AsyncStream<DownloadProgress>

    /// Cancels an active request
    /// - Parameter requestID: Identifier of request to cancel
    func cancelRequest(_ requestID: String) async

    /// Current network reachability status
    var isReachable: Bool { get async }
}

/// Network request configuration
struct NetworkRequest: Sendable {
    let id: String
    let url: URL
    let method: HTTPMethod
    let headers: [String: String]
    let body: Data?
    let timeout: TimeInterval

    enum HTTPMethod: String, Sendable {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
        case patch = "PATCH"
    }
}

/// Network response wrapper
struct NetworkResponse<T: Decodable>: Sendable where T: Sendable {
    let data: T
    let statusCode: Int
    let headers: [String: String]
    let requestID: String
}

/// Upload operation result
struct UploadResult: Sendable, Codable {
    let uploadedBytes: Int
    let remoteURL: URL?
    let checksum: String?
}

/// Download progress information
enum DownloadProgress: Sendable {
    case progress(bytesDownloaded: Int, totalBytes: Int)
    case completed(data: Data)
}

// MARK: - Service Errors

/// Base error type for service operations
enum ServiceError: Error, Sendable {
    case notInitialized
    case alreadyRunning
    case notRunning
    case initializationFailed(String)
    case startupFailed(String)
    case shutdownFailed(String)
    case invalidConfiguration(String)
}

/// Transcription-specific errors
enum TranscriptionError: Error, Sendable {
    case notAuthorized
    case notAvailable
    case engineFailure(String)
    case unsupportedLanguage(String)
    case alreadyTranscribing
    case notTranscribing
}

/// Audio service specific errors
enum AudioServiceError: Error, Sendable {
    case deviceNotFound
    case deviceNotAvailable
    case captureFailure(String)
    case invalidFormat
    case bufferOverflow
    case hardwareError(String)
}

/// Storage-specific errors
enum StorageError: Error, Sendable {
    case notFound
    case saveFailed(String)
    case fetchFailed(String)
    case deleteFailed(String)
    case updateFailed(String)
    case corruptedData
    case storageFull
}

/// Network-specific errors
enum NetworkError: Error, Sendable {
    case invalidURL
    case requestFailed(statusCode: Int)
    case noConnection
    case timeout
    case decodingFailed(String)
    case encodingFailed(String)
    case cancelled
}
