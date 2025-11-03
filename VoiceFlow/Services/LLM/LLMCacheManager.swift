import Foundation

// MARK: - LLM Cache Management

/// Thread-safe cache manager for LLM processing results
@MainActor
public class LLMCacheManager {

    // MARK: - Properties

    private var cache: [String: ProcessingResult] = [:]
    private var keyOrder: [String] = [] // Maintains insertion order for FIFO eviction
    private let maxCacheSize: Int

    // MARK: - Initialization

    public init(maxSize: Int = 100) {
        self.maxCacheSize = maxSize
        print("💾 LLM Cache Manager initialized (max size: \(maxSize))")
    }

    // MARK: - Public Methods

    /// Generate cache key from text and model
    public func generateKey(text: String, model: LLMModel) -> String {
        let textHash = text.hash
        return "\(model.rawValue)_\(textHash)"
    }

    /// Retrieve cached result if available
    public func get(key: String) -> ProcessingResult? {
        return cache[key]
    }

    /// Store result in cache with automatic eviction
    public func set(key: String, result: ProcessingResult) {
        // If key already exists, remove it from keyOrder first (we'll add it to end)
        if cache[key] != nil {
            keyOrder.removeAll { $0 == key }
        }

        cache[key] = result
        keyOrder.append(key) // Track insertion order

        // Evict oldest entry if cache exceeds max size
        if cache.count > maxCacheSize {
            evictOldest()
        }
    }

    /// Check if result exists in cache
    public func contains(key: String) -> Bool {
        return cache[key] != nil
    }

    /// Clear all cached results
    public func clear() {
        cache.removeAll()
        keyOrder.removeAll()
        print("🧹 LLM cache cleared")
    }

    /// Get current cache size
    public var count: Int {
        return cache.count
    }

    /// Get cache hit/miss statistics
    public var statistics: CacheStatistics {
        return CacheStatistics(
            size: cache.count,
            maxSize: maxCacheSize,
            utilizationRate: Float(cache.count) / Float(maxCacheSize)
        )
    }

    // MARK: - Private Methods

    /// Evict oldest cache entry (true FIFO strategy using insertion order)
    private func evictOldest() {
        guard let oldestKey = keyOrder.first else { return }
        keyOrder.removeFirst() // Remove from order tracking
        cache.removeValue(forKey: oldestKey) // Remove from cache
        print("🗑️ Evicted oldest cache entry (key: \(oldestKey.prefix(20))...)")
    }
}

// MARK: - Supporting Types

/// Cache statistics for monitoring
public struct CacheStatistics: Sendable {
    public let size: Int
    public let maxSize: Int
    public let utilizationRate: Float
}
