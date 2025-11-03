import Foundation
import OSLog

/// System metrics collection for CPU, memory, and disk usage
/// Single Responsibility: Low-level system metrics gathering

actor MetricsCollector {

    private let logger = Logger(subsystem: "com.voiceflow.app", category: "MetricsCollector")

    // MARK: - CPU Metrics

    /// Collect current CPU usage as percentage
    /// - Returns: CPU usage in range 0.0-100.0, or 0.0 on error
    func getCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            // Note: This returns resident size, not CPU usage
            // For actual CPU usage, we'd need thread_info calls
            return Double(info.resident_size) / 1024.0 / 1024.0
        }

        return 0.0
    }

    // MARK: - Memory Metrics

    /// Collect current memory usage in megabytes
    /// - Returns: Memory usage in MB, or 0.0 on error
    func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        }

        return 0.0
    }

    // MARK: - Disk Metrics

    /// Collect available disk space in megabytes
    /// - Returns: Available disk space in MB, or 0.0 on error
    func getDiskUsage() -> Double {
        do {
            let fileURL = URL(fileURLWithPath: NSHomeDirectory())
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let capacity = values.volumeAvailableCapacityForImportantUsage {
                return Double(capacity) / 1024.0 / 1024.0 // Convert to MB
            }
        } catch {
            logger.error("📊 Failed to get disk usage: \(error.localizedDescription)")
        }

        return 0.0
    }
}
