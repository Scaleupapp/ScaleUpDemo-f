import Foundation
import UIKit
import os

// MARK: - Performance Monitor

/// Measures and logs screen load times, memory usage, and network statistics
/// using Apple's `os` signpost APIs for Instruments integration.
///
/// Inject via the SwiftUI environment or `DependencyContainer` and call
/// `startMeasuring(screen:)` / `stopMeasuring(screen:)` around screen
/// lifecycle events to capture render latencies.
@Observable
@MainActor
final class PerformanceMonitor {

    // MARK: - Screen Load Timing

    /// Active screen timers keyed by screen name.
    private var screenTimers: [String: CFAbsoluteTime] = [:]

    /// Historical screen load durations for summary reporting.
    private(set) var screenLoadTimes: [String: TimeInterval] = [:]

    // MARK: - Memory Monitoring

    /// Whether a system memory warning has been received since last reset.
    var memoryWarningReceived = false

    /// Current process memory usage in bytes, obtained from `task_info`.
    var currentMemoryUsage: UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { ptr in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), ptr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return info.phys_footprint
    }

    /// Formatted memory usage string (e.g. "45.2 MB").
    var formattedMemoryUsage: String {
        CacheManager.formatBytes(Int64(currentMemoryUsage))
    }

    // MARK: - Network Statistics

    /// Total number of network requests recorded.
    var totalRequests: Int = 0

    /// Total number of failed network requests recorded.
    var failedRequests: Int = 0

    /// Running average response time across all recorded requests.
    var averageResponseTime: TimeInterval = 0

    /// Sum of all response durations (used to compute the rolling average).
    private var totalResponseTime: TimeInterval = 0

    // MARK: - Signpost Integration

    /// Signposter for Instruments timeline integration.
    private let signposter = OSSignposter(
        subsystem: "com.scaleup.app",
        category: "Performance"
    )

    /// Logger dedicated to performance events.
    private let logger = Logger(subsystem: "com.scaleup.app", category: "Performance")

    // MARK: - Init

    init() {
        observeMemoryWarnings()
    }

    // MARK: - Screen Timing

    /// Begin timing a screen load. Call from `onAppear` or `task`.
    func startMeasuring(screen: String) {
        screenTimers[screen] = CFAbsoluteTimeGetCurrent()
        logger.debug("Screen timer started: \(screen)")
    }

    /// End timing a screen load and return the elapsed duration.
    /// Returns `nil` if no matching `startMeasuring` call was made.
    @discardableResult
    func stopMeasuring(screen: String) -> TimeInterval? {
        guard let start = screenTimers.removeValue(forKey: screen) else {
            logger.warning("No active timer for screen: \(screen)")
            return nil
        }
        let duration = CFAbsoluteTimeGetCurrent() - start
        screenLoadTimes[screen] = duration
        logger.info("Screen '\(screen)' loaded in \(String(format: "%.2f", duration))s")
        return duration
    }

    // MARK: - Network Recording

    /// Record a completed network request for aggregate statistics.
    func recordRequest(duration: TimeInterval, success: Bool) {
        totalRequests += 1
        if !success { failedRequests += 1 }
        totalResponseTime += duration
        averageResponseTime = totalResponseTime / Double(totalRequests)
    }

    // MARK: - Signpost Helpers

    /// Begin an Instruments signpost interval and return its state.
    func beginInterval(_ name: StaticString) -> OSSignpostIntervalState {
        signposter.beginInterval(name)
    }

    /// End an Instruments signpost interval previously started with `beginInterval`.
    func endInterval(_ name: StaticString, _ state: OSSignpostIntervalState) {
        signposter.endInterval(name, state)
    }

    // MARK: - Summary

    /// Log a human-readable summary of all collected performance metrics.
    func logPerformanceSummary() {
        logger.info("""
        === Performance Summary ===
        Memory: \(self.formattedMemoryUsage)
        Memory Warning: \(self.memoryWarningReceived)
        Total Requests: \(self.totalRequests)
        Failed Requests: \(self.failedRequests)
        Avg Response Time: \(String(format: "%.2f", self.averageResponseTime))s
        Screen Load Times:
        \(self.screenLoadTimes.map { "  \($0.key): \(String(format: "%.2f", $0.value))s" }.joined(separator: "\n"))
        ===============================
        """)
    }

    // MARK: - Reset

    /// Clear all collected metrics.
    func reset() {
        screenTimers.removeAll()
        screenLoadTimes.removeAll()
        totalRequests = 0
        failedRequests = 0
        averageResponseTime = 0
        totalResponseTime = 0
        memoryWarningReceived = false
    }

    // MARK: - Private

    /// Subscribe to `UIApplication.didReceiveMemoryWarningNotification`.
    private func observeMemoryWarnings() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.memoryWarningReceived = true
                self?.logger.warning("Memory warning received")
            }
        }
    }
}
