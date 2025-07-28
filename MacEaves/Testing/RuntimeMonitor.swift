/*
 RuntimeMonitor for MacEaves
 Automatic background monitoring for threading issues
 */

import Foundation
import os.log

public class RuntimeMonitor {
    private static let logger = Logger(subsystem: "MacEaves", category: "RuntimeMonitor")
    private static var isMonitoring = false
    private static var monitoringTimer: Timer?
    
    public static func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        logger.info("🔍 Starting runtime monitoring for threading issues...")
        
        // Set up periodic checks
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            performRuntimeChecks()
        }
        
        // Hook into crash signals
        setupCrashHandlers()
        
        print("🔍 RuntimeMonitor: Monitoring started - watching for dispatch queue assertions and threading violations")
    }
    
    public static func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        logger.info("🛑 Runtime monitoring stopped")
        print("🛑 RuntimeMonitor: Monitoring stopped")
    }
    
    private static func performRuntimeChecks() {
        // Check current thread state
        let threadInfo = getCurrentThreadInfo()
        
        // Log if we detect potential issues
        if !Thread.isMainThread {
            logger.warning("⚠️ Runtime check performed on non-main thread: \(threadInfo)")
        }
        
        // Check dispatch queue state
        let queueLabel = String(cString: __dispatch_queue_get_label(nil), encoding: .utf8) ?? "Unknown"
        if queueLabel.contains("com.apple.main-thread") || queueLabel.contains("main") {
            // This is expected
        } else {
            logger.info("📊 Runtime check on queue: \(queueLabel)")
        }
    }
    
    private static func getCurrentThreadInfo() -> String {
        let thread = Thread.current
        var info = thread.isMainThread ? "Main" : "Background"
        
        if let name = thread.name, !name.isEmpty {
            info += " (\(name))"
        }
        
        let queueLabel = String(cString: __dispatch_queue_get_label(nil), encoding: .utf8) ?? "Unknown"
        info += ", Queue: \(queueLabel)"
        
        return info
    }
    
    private static func setupCrashHandlers() {
        #if DEBUG
        // Set up signal handlers for common crash signals
        signal(SIGABRT) { signal in
            let message = "🚨 SIGABRT received - possible dispatch queue assertion failure!"
            print(message)
            logger.critical("\(message)")
            
            // Print stack trace info if available
            print("🔍 Stack trace at crash:")
            Thread.callStackSymbols.forEach { symbol in
                print("  \(symbol)")
            }
        }
        
        signal(SIGSEGV) { signal in
            let message = "🚨 SIGSEGV received - segmentation fault!"
            print(message)
            logger.critical("\(message)")
        }
        
        signal(SIGILL) { signal in
            let message = "🚨 SIGILL received - illegal instruction!"
            print(message)
            logger.critical("\(message)")
        }
        #endif
    }
    
    // Manual check that can be called anywhere in the app
    public static func checkCurrentContext(file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let threadInfo = getCurrentThreadInfo()
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        
        let message = "🧵 [\(timestamp)] \(fileName):\(line) \(function) - \(threadInfo)"
        print(message)
        logger.info("\(message)")
        
        // Check for potential issues
        if !Thread.isMainThread {
            let warning = "⚠️ Function \(function) called from non-main thread in \(fileName):\(line)"
            print(warning)
            logger.warning("\(warning)")
        }
    }
    
    // Specific check for AudioLevelMonitor usage
    public static func checkAudioMonitorContext(operation: String) {
        let threadInfo = getCurrentThreadInfo()
        let isMainThread = Thread.isMainThread
        
        let message = "🎚️ AudioMonitor.\(operation) - \(threadInfo)"
        print(message)
        logger.info("\(message)")
        
        if !isMainThread {
            let warning = "⚠️ AudioLevelMonitor.\(operation) called from non-main thread!"
            print(warning)
            logger.warning("\(warning)")
        }
    }
}

// Simple utility for one-off debugging
public class DebugHelper {
    public static func printThreadInfo(_ message: String = "", file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let thread = Thread.current
        let isMain = thread.isMainThread ? "Main" : "Background"
        let queueLabel = String(cString: __dispatch_queue_get_label(nil), encoding: .utf8) ?? "Unknown"
        
        print("🧵 [\(fileName):\(line)] \(function) - \(isMain) thread, Queue: \(queueLabel) - \(message)")
    }
    
    public static func assertMainThread(_ message: String = "", file: String = #file, function: String = #function, line: Int = #line) {
        if !Thread.isMainThread {
            let fileName = (file as NSString).lastPathComponent
            let warning = "❌ ASSERTION FAILED: \(fileName):\(line) \(function) - Expected main thread but got background thread! \(message)"
            print(warning)
            assertionFailure(warning)
        }
    }
}
