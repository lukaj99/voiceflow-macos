import AVFoundation
import Accelerate

/// High-performance audio buffer pool for eliminating frequent allocations
/// Addresses critical performance bottleneck: Task creation per buffer
public final class AudioBufferPool {
    
    // MARK: - Properties
    
    private let poolSize: Int
    private var availableBuffers: [AVAudioPCMBuffer]
    private let bufferFormat: AVAudioFormat
    private let frameCapacity: AVAudioFrameCount
    private let poolQueue = DispatchQueue(label: "com.voiceflow.bufferpool", attributes: .concurrent)
    
    // Performance metrics
    private var borrowCount: Int = 0
    private var returnCount: Int = 0
    private var missCount: Int = 0 // When pool is empty
    
    // MARK: - Initialization
    
    public init(format: AVAudioFormat, frameCapacity: AVAudioFrameCount, poolSize: Int = 10) {
        self.bufferFormat = format
        self.frameCapacity = frameCapacity
        self.poolSize = poolSize
        self.availableBuffers = []
        
        // Pre-allocate all buffers
        self.availableBuffers = (0..<poolSize).compactMap { _ in
            AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity)
        }
    }
    
    // MARK: - Buffer Management
    
    /// Borrow a buffer from the pool
    /// - Returns: A clean, ready-to-use buffer
    public func borrowBuffer() -> AVAudioPCMBuffer {
        return poolQueue.sync {
            borrowCount += 1
            
            if let buffer = availableBuffers.popLast() {
                // Reset buffer for reuse
                buffer.frameLength = 0
                return buffer
            } else {
                // Pool is empty, create new buffer (track miss)
                missCount += 1
                return AVAudioPCMBuffer(pcmFormat: bufferFormat, frameCapacity: frameCapacity) ?? 
                       AVAudioPCMBuffer(pcmFormat: bufferFormat, frameCapacity: frameCapacity)!
            }
        }
    }
    
    /// Return a buffer to the pool
    /// - Parameter buffer: The buffer to return
    public func returnBuffer(_ buffer: AVAudioPCMBuffer) {
        poolQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.returnCount += 1
            
            // Only return if pool isn't full and buffer matches format
            if self.availableBuffers.count < self.poolSize && 
               buffer.format == self.bufferFormat {
                // Clear the buffer
                buffer.frameLength = 0
                self.availableBuffers.append(buffer)
            }
        }
    }
    
    // MARK: - Performance Monitoring
    
    public struct PoolMetrics {
        public let availableBuffers: Int
        public let borrowCount: Int
        public let returnCount: Int
        public let missCount: Int
        public let hitRate: Double
        
        public var description: String {
            return """
            Buffer Pool Metrics:
            - Available: \(availableBuffers)/\(availableBuffers + missCount)
            - Borrows: \(borrowCount)
            - Returns: \(returnCount)
            - Misses: \(missCount)
            - Hit Rate: \(String(format: "%.1f", hitRate * 100))%
            """
        }
    }
    
    public func getMetrics() -> PoolMetrics {
        return poolQueue.sync {
            let hitRate = borrowCount > 0 ? Double(borrowCount - missCount) / Double(borrowCount) : 1.0
            return PoolMetrics(
                availableBuffers: availableBuffers.count,
                borrowCount: borrowCount,
                returnCount: returnCount,
                missCount: missCount,
                hitRate: hitRate
            )
        }
    }
    
    public func resetMetrics() {
        poolQueue.async(flags: .barrier) { [weak self] in
            self?.borrowCount = 0
            self?.returnCount = 0
            self?.missCount = 0
        }
    }
}

/// Optimized audio processor that eliminates Task creation per buffer
public final class OptimizedAudioProcessor {
    
    // MARK: - Properties
    
    private let bufferPool: AudioBufferPool
    private let processingQueue = DispatchQueue(label: "com.voiceflow.audioprocessing", 
                                              qos: .userInteractive,
                                              attributes: .concurrent)
    
    // Circular buffer for RMS calculations (eliminates allocation per calculation)
    private var rmsHistory: [Float]
    private var rmsIndex: Int = 0
    private let rmsHistorySize = 10
    
    // Reusable calculation variables
    private var reusableRMS: Float = 0
    private var reusableAvgPower: Float = 0
    
    // Performance targets
    public static let targetLatency: TimeInterval = 0.050 // 50ms target
    
    // MARK: - Initialization
    
    public init(format: AVAudioFormat, frameCapacity: AVAudioFrameCount) {
        self.bufferPool = AudioBufferPool(format: format, frameCapacity: frameCapacity)
        self.rmsHistory = Array(repeating: 0.0, count: rmsHistorySize)
    }
    
    // MARK: - Audio Processing
    
    /// Optimized audio level calculation using SIMD and avoiding repeated allocations
    public func calculateAudioLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        
        let channelDataPointer = channelData[0]
        let frameLength = Int(buffer.frameLength)
        
        // Use pre-allocated variable instead of creating new ones
        vDSP_rmsqv(channelDataPointer, 1, &reusableRMS, vDSP_Length(frameLength))
        
        // Convert to decibels using pre-allocated variable
        reusableAvgPower = 20 * log10f(reusableRMS)
        
        // Normalize to 0-1 range with constants for performance
        let normalizedPower = (reusableAvgPower + 60.0) / 60.0 // -60dB to 0dB range
        let clampedLevel = max(0, min(1, normalizedPower))
        
        // Update circular buffer for smoothing
        rmsHistory[rmsIndex] = clampedLevel
        rmsIndex = (rmsIndex + 1) % rmsHistorySize
        
        // Return smoothed value using SIMD
        var smoothedLevel: Float = 0
        vDSP_meanv(rmsHistory, 1, &smoothedLevel, vDSP_Length(rmsHistorySize))
        
        return smoothedLevel
    }
    
    /// Process audio buffer without creating Tasks (eliminates critical bottleneck)
    public func processBuffer(_ inputBuffer: AVAudioPCMBuffer, 
                            completion: @escaping (Float, AVAudioPCMBuffer) -> Void) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Calculate audio level efficiently
            let level = self.calculateAudioLevel(from: inputBuffer)
            
            // Get pooled buffer for processing
            let workingBuffer = self.bufferPool.borrowBuffer()
            
            // Copy data efficiently using AVAudioBuffer methods
            guard let inputFloatData = inputBuffer.floatChannelData,
                  let workingFloatData = workingBuffer.floatChannelData else {
                self.bufferPool.returnBuffer(workingBuffer)
                return
            }
            
            let frameCount = Int(inputBuffer.frameLength)
            workingBuffer.frameLength = inputBuffer.frameLength
            
            // Use SIMD for efficient copying
            cblas_scopy(Int32(frameCount), inputFloatData[0], 1, workingFloatData[0], 1)
            
            let processingTime = CFAbsoluteTimeGetCurrent() - startTime
            
            // Ensure we meet performance targets
            if processingTime > Self.targetLatency {
                print("⚠️ Audio processing exceeded target latency: \(processingTime * 1000)ms")
            }
            
            // Return processed buffer and level
            completion(level, workingBuffer)
            
            // Return buffer to pool for reuse
            DispatchQueue.global(qos: .utility).async {
                self.bufferPool.returnBuffer(workingBuffer)
            }
        }
    }
    
    // MARK: - Performance Monitoring
    
    public func getBufferPoolMetrics() -> AudioBufferPool.PoolMetrics {
        return bufferPool.getMetrics()
    }
    
    public func resetPerformanceMetrics() {
        bufferPool.resetMetrics()
    }
}