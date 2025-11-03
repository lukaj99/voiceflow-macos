import Foundation
@preconcurrency import AVFoundation

/// High-performance audio buffer pool for efficient memory management
/// Single Responsibility: Audio buffer allocation, pooling, and recycling
public actor AudioBufferPool {

    // MARK: - Types

    public struct PooledBuffer: @unchecked Sendable {
        public let id: UUID
        public let buffer: AVAudioPCMBuffer
        public let timestamp: Date

        fileprivate init(buffer: AVAudioPCMBuffer) {
            self.id = UUID()
            self.buffer = buffer
            self.timestamp = Date()
        }
    }

    public struct PoolStatistics: Sendable {
        public let totalBuffers: Int
        public let availableBuffers: Int
        public let allocatedBuffers: Int
        public let poolHitRate: Double
        public let memoryUsageMB: Double
        public let peakMemoryUsageMB: Double

        public init(
            totalBuffers: Int,
            availableBuffers: Int,
            allocatedBuffers: Int,
            poolHitRate: Double,
            memoryUsageMB: Double,
            peakMemoryUsageMB: Double
        ) {
            self.totalBuffers = totalBuffers
            self.availableBuffers = availableBuffers
            self.allocatedBuffers = allocatedBuffers
            self.poolHitRate = poolHitRate
            self.memoryUsageMB = memoryUsageMB
            self.peakMemoryUsageMB = peakMemoryUsageMB
        }
    }

    // MARK: - Properties

    private var availableBuffers: [PooledBuffer] = []
    private var allocatedBuffers: Set<UUID> = []
    private let maxPoolSize: Int
    private let bufferFrameCapacity: AVAudioFrameCount
    private let audioFormat: AVAudioFormat

    // Statistics
    private var totalAllocations: Int = 0
    private var poolHits: Int = 0
    private var poolMisses: Int = 0
    private var peakMemoryUsage: Double = 0.0

    // Buffer management
    private let maxBufferAge: TimeInterval = 30.0 // 30 seconds
    private var lastCleanupTime = Date()
    private let cleanupInterval: TimeInterval = 10.0 // Cleanup every 10 seconds

    // MARK: - Initialization

    public init(
        maxPoolSize: Int = 20,
        bufferFrameCapacity: AVAudioFrameCount = 4096,
        audioFormat: AVAudioFormat
    ) {
        self.maxPoolSize = maxPoolSize
        self.bufferFrameCapacity = bufferFrameCapacity
        self.audioFormat = audioFormat

        print("🔄 AudioBufferPool initialized - Max size: \(maxPoolSize), Frame capacity: \(bufferFrameCapacity)")

        // Pre-populate pool with initial buffers
        Task {
            await preallocateBuffers(count: min(5, maxPoolSize))
        }
    }

    // MARK: - Public Interface

    /// Acquire a buffer from the pool or create a new one
    public func acquireBuffer() -> PooledBuffer? {
        totalAllocations += 1

        // Perform cleanup if needed
        performCleanupIfNeeded()

        // Try to get from pool first
        if let pooledBuffer = getFromPool() {
            poolHits += 1
            allocatedBuffers.insert(pooledBuffer.id)
            return pooledBuffer
        }

        // Create new buffer if pool is empty
        poolMisses += 1
        guard let newBuffer = createBuffer() else {
            print("❌ Failed to create new audio buffer")
            return nil
        }

        let pooledBuffer = PooledBuffer(buffer: newBuffer)
        allocatedBuffers.insert(pooledBuffer.id)

        return pooledBuffer
    }

    /// Return a buffer to the pool for reuse
    public func returnBuffer(_ pooledBuffer: PooledBuffer) {
        allocatedBuffers.remove(pooledBuffer.id)

        // Reset buffer data
        pooledBuffer.buffer.frameLength = 0

        // Add back to pool if there's space
        if availableBuffers.count < maxPoolSize {
            // Create new pooled buffer with current timestamp
            let refreshedBuffer = PooledBuffer(buffer: pooledBuffer.buffer)
            availableBuffers.append(refreshedBuffer)
        }

        // Update memory statistics
        updateMemoryStatistics()
    }

    /// Get current pool statistics
    public func getStatistics() -> PoolStatistics {
        let currentMemoryUsage = calculateMemoryUsage()
        peakMemoryUsage = max(peakMemoryUsage, currentMemoryUsage)

        let hitRate = totalAllocations > 0 ? Double(poolHits) / Double(totalAllocations) : 0.0

        return PoolStatistics(
            totalBuffers: availableBuffers.count + allocatedBuffers.count,
            availableBuffers: availableBuffers.count,
            allocatedBuffers: allocatedBuffers.count,
            poolHitRate: hitRate,
            memoryUsageMB: currentMemoryUsage,
            peakMemoryUsageMB: peakMemoryUsage
        )
    }

    /// Clear all buffers and reset pool
    public func clearPool() {
        availableBuffers.removeAll()
        allocatedBuffers.removeAll()

        // Reset statistics
        totalAllocations = 0
        poolHits = 0
        poolMisses = 0
        peakMemoryUsage = 0.0

        print("🧹 Audio buffer pool cleared")
    }

    /// Optimize pool size based on usage patterns
    public func optimizePoolSize() {
        let stats = getStatistics()

        // Optimize based on hit rate and memory usage
        let targetPoolSize: Int

        if stats.poolHitRate > 0.9 && stats.memoryUsageMB < 10.0 {
            // High hit rate and low memory usage - can increase pool size
            targetPoolSize = min(maxPoolSize, availableBuffers.count + 5)
        } else if stats.poolHitRate < 0.5 || stats.memoryUsageMB > 20.0 {
            // Low hit rate or high memory usage - decrease pool size
            targetPoolSize = max(5, availableBuffers.count - 3)
        } else {
            // Maintain current size
            targetPoolSize = availableBuffers.count
        }

        // Adjust pool size
        while availableBuffers.count > targetPoolSize {
            availableBuffers.removeLast()
        }

        while availableBuffers.count < targetPoolSize {
            if let newBuffer = createBuffer() {
                let pooledBuffer = PooledBuffer(buffer: newBuffer)
                availableBuffers.append(pooledBuffer)
            } else {
                break
            }
        }

        print("🎯 Pool optimized - Target size: \(targetPoolSize), Actual size: \(availableBuffers.count)")
    }

    // MARK: - Private Methods

    private func preallocateBuffers(count: Int) {
        for _ in 0..<count {
            if let buffer = createBuffer() {
                let pooledBuffer = PooledBuffer(buffer: buffer)
                availableBuffers.append(pooledBuffer)
            }
        }
        print("📦 Pre-allocated \(availableBuffers.count) audio buffers")
    }

    private func getFromPool() -> PooledBuffer? {
        return availableBuffers.popLast()
    }

    private func createBuffer() -> AVAudioPCMBuffer? {
        return AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: bufferFrameCapacity)
    }

    private func performCleanupIfNeeded() {
        let now = Date()

        guard now.timeIntervalSince(lastCleanupTime) > cleanupInterval else {
            return
        }

        lastCleanupTime = now

        // Remove old buffers
        availableBuffers.removeAll { buffer in
            now.timeIntervalSince(buffer.timestamp) > maxBufferAge
        }

        print("🧹 Buffer pool cleanup completed - \(availableBuffers.count) buffers remaining")
    }

    private func calculateMemoryUsage() -> Double {
        let bytesPerFrame = audioFormat.streamDescription.pointee.mBytesPerFrame
        let totalFrames = AVAudioFrameCount(availableBuffers.count + allocatedBuffers.count) * bufferFrameCapacity
        let totalBytes = Double(totalFrames) * Double(bytesPerFrame)
        return totalBytes / (1024 * 1024) // Convert to MB
    }

    private func updateMemoryStatistics() {
        let currentUsage = calculateMemoryUsage()
        peakMemoryUsage = max(peakMemoryUsage, currentUsage)
    }
}

// MARK: - Global Buffer Pool Instance

/// Shared audio buffer pool instance for application-wide use
public actor AudioBufferManager {
    @MainActor private static var _sharedPool: AudioBufferPool?

    public static func getSharedPool(audioFormat: AVAudioFormat) async -> AudioBufferPool {
        if let existingPool = await _sharedPool {
            return existingPool
        }
        let newPool = AudioBufferPool(audioFormat: audioFormat)
        await setSharedPool(newPool)
        return newPool
    }

    public static func resetSharedPool() async {
        await setSharedPool(nil)
    }

    @MainActor private static func setSharedPool(_ pool: AudioBufferPool?) {
        _sharedPool = pool
    }
}
