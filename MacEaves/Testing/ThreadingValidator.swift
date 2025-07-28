/*
 ThreadingValidator for MacEaves
 Lightweight runtime validation for threading and dispatch queue issues
 */

import Foundation
import Combine
import SwiftUI

@MainActor
public class ThreadingValidator: ObservableObject {
    @Published public var violations: [ThreadingViolation] = []
    @Published public var isValidating: Bool = false
    
    private var validationTimer: Timer?
    private var validationCount: Int = 0
    
    public struct ThreadingViolation: Identifiable, Hashable {
        public let id = UUID()
        public let timestamp: Date
        public let type: ViolationType
        public let description: String
        public let threadInfo: String
        
        public enum ViolationType: String, CaseIterable {
            case mainActorViolation = "MainActor Violation"
            case timerThreadIssue = "Timer Thread Issue"
            case dispatchQueueAssertion = "Dispatch Queue Assertion"
            case concurrencyWarning = "Concurrency Warning"
        }
    }
    
    public init() {
        // Hook into runtime assertions (this is experimental)
        setupAssertionHandler()
    }
    
    public func startValidation() {
        print("🔍 Starting threading validation...")
        isValidating = true
        validationCount = 0
        
        // Start periodic validation checks
        validationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performValidationCheck()
            }
        }
    }
    
    public func stopValidation() {
        print("🛑 Stopping threading validation...")
        validationTimer?.invalidate()
        validationTimer = nil
        isValidating = false
    }
    
    public func clearViolations() {
        violations.removeAll()
    }
    
    private func performValidationCheck() {
        validationCount += 1
        
        // Check if we're actually on main thread
        if !Thread.isMainThread {
            recordViolation(
                type: .mainActorViolation,
                description: "ThreadingValidator.performValidationCheck() called off main thread",
                threadInfo: getCurrentThreadInfo()
            )
        }
        
        // Test Timer creation safety
        if validationCount % 50 == 0 { // Every 5 seconds
            testTimerCreation()
        }
        
        // Test dispatch queue assertions
        if validationCount % 30 == 0 { // Every 3 seconds
            testDispatchQueueAssertion()
        }
    }
    
    private func testTimerCreation() {
        // Test creating timer from current context
        let currentThread = Thread.current
        
        if !currentThread.isMainThread {
            recordViolation(
                type: .timerThreadIssue,
                description: "Timer test attempted from non-main thread",
                threadInfo: getCurrentThreadInfo()
            )
            return
        }
        
        // Test safe timer creation pattern
        DispatchQueue.main.async {
            let testTimer = Timer.scheduledTimer(withTimeInterval: 0.001, repeats: false) { _ in
                // Quick test timer
            }
            testTimer.invalidate()
        }
    }
    
    private func testDispatchQueueAssertion() {
        // Test dispatch queue state
        if Thread.isMainThread {
            // We're on main thread, test queue assertion
            DispatchQueue.main.async { [weak self] in
                // This should be safe
                if let self = self {
                    // Verify we can access main actor properties safely
                    let _ = self.isValidating
                }
            }
        }
    }
    
    private func recordViolation(type: ThreadingViolation.ViolationType, description: String, threadInfo: String) {
        let violation = ThreadingViolation(
            timestamp: Date(),
            type: type,
            description: description,
            threadInfo: threadInfo
        )
        
        violations.append(violation)
        print("⚠️ Threading Violation: \(type.rawValue) - \(description)")
        print("📊 Thread Info: \(threadInfo)")
        
        // Keep only last 50 violations
        if violations.count > 50 {
            violations.removeFirst(violations.count - 50)
        }
    }
    
    private func getCurrentThreadInfo() -> String {
        let thread = Thread.current
        var info = "Thread: "
        
        if thread.isMainThread {
            info += "Main"
        } else {
            info += "Background"
            if let name = thread.name, !name.isEmpty {
                info += " (\(name))"
            }
        }
        
        info += ", Queue: "
        if let queueLabel = String(cString: __dispatch_queue_get_label(nil), encoding: .utf8) {
            info += queueLabel
        } else {
            info += "Unknown"
        }
        
        return info
    }
    
    private func setupAssertionHandler() {
        // This is experimental - try to catch dispatch assertions
        // Note: This may not work in all cases due to system-level assertions
        
        #if DEBUG
        // Set up signal handler for SIGABRT (which dispatch assertions can trigger)
        signal(SIGABRT) { signal in
            print("🚨 SIGABRT received - possible dispatch queue assertion!")
            // Note: We can't safely do much here due to signal handler constraints
        }
        #endif
    }
    
    // Static method to test specific threading scenarios
    public static func validateAudioMonitorUsage() -> [String] {
        var issues: [String] = []
        
        // Check if current context is on main thread
        if !Thread.isMainThread {
            issues.append("Audio monitor validation called from non-main thread")
        }
        
        // Test dispatch queue state
        let queueLabel = String(cString: __dispatch_queue_get_label(nil), encoding: .utf8) ?? "Unknown"
        if queueLabel != "com.apple.main-thread" {
            issues.append("Audio monitor validation not on main dispatch queue: \(queueLabel)")
        }
        
        return issues
    }
}

// Console logging helper for debugging
public class ThreadingLogger {
    public static func log(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let threadInfo = Thread.isMainThread ? "Main" : "Background"
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        
        print("🧵 [\(timestamp)] [\(threadInfo)] \(fileName):\(line) \(function) - \(message)")
    }
    
    public static func logDispatchQueue(_ message: String) {
        let queueLabel = String(cString: __dispatch_queue_get_label(nil), encoding: .utf8) ?? "Unknown"
        print("📡 [Queue: \(queueLabel)] \(message)")
    }
}
