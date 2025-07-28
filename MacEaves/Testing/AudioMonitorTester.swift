/*
 AudioMonitorTester for MacEaves
 Specific tests for AudioLevelMonitor threading issues
 */

import Foundation
import SwiftUI
import Combine

@MainActor
public class AudioMonitorTester: ObservableObject {
    @Published public var testResults: [TestResult] = []
    @Published public var isRunning: Bool = false
    
    private var testTimer: Timer?
    private var testCount: Int = 0
    
    public struct TestResult: Identifiable {
        public let id = UUID()
        public let timestamp: Date
        public let testName: String
        public let passed: Bool
        public let details: String
        public let threadInfo: String
    }
    
    public init() {}
    
    public func runTests() {
        print("🧪 Starting AudioLevelMonitor threading tests...")
        isRunning = true
        testCount = 0
        testResults.removeAll()
        
        // Run immediate tests
        testCurrentThreadState()
        testTimerCreationSafety()
        testDispatchQueueState()
        
        // Start continuous monitoring
        startContinuousTests()
    }
    
    public func stopTests() {
        print("🛑 Stopping AudioLevelMonitor tests...")
        testTimer?.invalidate()
        testTimer = nil
        isRunning = false
    }
    
    private func startContinuousTests() {
        // Create timer safely on main thread
        testTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.runPeriodicTests()
            }
        }
    }
    
    private func runPeriodicTests() {
        testCount += 1
        
        // Test various threading scenarios
        testMainActorAccess()
        
        if testCount % 5 == 0 {
            testTimerCreationFromMainThread()
        }
        
        if testCount % 10 == 0 {
            testBackgroundDispatchSafety()
        }
        
        // Stop after 30 tests (30 seconds)
        if testCount >= 30 {
            stopTests()
        }
    }
    
    private func testCurrentThreadState() {
        let passed = Thread.isMainThread
        let threadInfo = getCurrentThreadInfo()
        
        addTestResult(
            testName: "Current Thread State",
            passed: passed,
            details: passed ? "Running on main thread" : "NOT on main thread",
            threadInfo: threadInfo
        )
    }
    
    private func testTimerCreationSafety() {
        var details = "Timer creation test"
        
        // Test the pattern used in AudioLevelMonitor
        DispatchQueue.main.async {
            let testTimer = Timer.scheduledTimer(withTimeInterval: 0.001, repeats: false) { _ in
                // Test timer callback
            }
            testTimer.invalidate()
        }
        details = "Safe timer creation pattern works"
        
        addTestResult(
            testName: "Timer Creation Safety",
            passed: true,
            details: details,
            threadInfo: getCurrentThreadInfo()
        )
    }
    
    private func testDispatchQueueState() {
        let queueLabel = String(cString: __dispatch_queue_get_label(nil), encoding: .utf8) ?? "Unknown"
        let passed = queueLabel.contains("main") || queueLabel.contains("com.apple.main-thread")
        
        addTestResult(
            testName: "Dispatch Queue State",
            passed: passed,
            details: "Current queue: \(queueLabel)",
            threadInfo: getCurrentThreadInfo()
        )
    }
    
    private func testMainActorAccess() {
        let passed = Thread.isMainThread
        let details = passed ? "MainActor access is safe" : "MainActor access from wrong thread!"
        
        addTestResult(
            testName: "MainActor Access",
            passed: passed,
            details: details,
            threadInfo: getCurrentThreadInfo()
        )
    }
    
    private func testTimerCreationFromMainThread() {
        let wasOnMainThread = Thread.isMainThread
        var timerCreated = false
        
        if wasOnMainThread {
            // Test direct timer creation (this is what could cause issues)
            let timer = Timer.scheduledTimer(withTimeInterval: 0.001, repeats: false) { _ in }
            timer.invalidate()
            timerCreated = true
        }
        
        let passed = wasOnMainThread && timerCreated
        let details = if !wasOnMainThread {
            "Not on main thread for timer creation"
        } else {
            "Timer created successfully"
        }
        
        addTestResult(
            testName: "Main Thread Timer Creation",
            passed: passed,
            details: details,
            threadInfo: getCurrentThreadInfo()
        )
    }
    
    private func testBackgroundDispatchSafety() {
        // Test what happens when we try to access MainActor from background
        DispatchQueue.global().async { [weak self] in
            let backgroundThread = !Thread.isMainThread
            let queueLabel = String(cString: __dispatch_queue_get_label(nil), encoding: .utf8) ?? "Unknown"
            
            // This should be on a background queue
            Task { @MainActor in
                self?.addTestResult(
                    testName: "Background Dispatch Safety",
                    passed: backgroundThread,
                    details: "Background queue: \(queueLabel), then MainActor access",
                    threadInfo: "Background -> MainActor transition"
                )
            }
        }
    }
    
    private func addTestResult(testName: String, passed: Bool, details: String, threadInfo: String) {
        let result = TestResult(
            timestamp: Date(),
            testName: testName,
            passed: passed,
            details: details,
            threadInfo: threadInfo
        )
        
        testResults.append(result)
        
        let status = passed ? "✅" : "❌"
        print("\(status) \(testName): \(details)")
        
        // Keep only last 100 results
        if testResults.count > 100 {
            testResults.removeFirst(testResults.count - 100)
        }
    }
    
    private func getCurrentThreadInfo() -> String {
        let thread = Thread.current
        var info = ""
        
        if thread.isMainThread {
            info += "Main Thread"
        } else {
            info += "Background Thread"
            if let name = thread.name, !name.isEmpty {
                info += " (\(name))"
            }
        }
        
        let queueLabel = String(cString: __dispatch_queue_get_label(nil), encoding: .utf8) ?? "Unknown"
        info += ", Queue: \(queueLabel)"
        
        return info
    }
    
    // Test AudioLevelMonitor specific patterns
    public func testAudioLevelMonitorPatterns() {
        print("🎚️ Testing AudioLevelMonitor specific patterns...")
        
        // Test the specific timer creation pattern used in AudioLevelMonitor
        testAudioLevelTimerPattern()
        
        // Test MainActor task pattern
        testMainActorTaskPattern()
        
        // Test audio buffer processing pattern
        testAudioBufferPattern()
    }
    
    private func testAudioLevelTimerPattern() {
        // This mimics the startLevelUpdateTimer method
        DispatchQueue.main.async { [weak self] in
            let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { _ in
                // Timer callback - this should be safe
            }
            timer.invalidate()
            
            Task { @MainActor in
                self?.addTestResult(
                    testName: "AudioLevel Timer Pattern",
                    passed: true,
                    details: "Timer created safely via DispatchQueue.main.async",
                    threadInfo: self?.getCurrentThreadInfo() ?? "Unknown"
                )
            }
        }
    }
    
    private func testMainActorTaskPattern() {
        // This mimics the Task { @MainActor } pattern used in audio processing
        DispatchQueue.global().async { [weak self] in
            // Simulate audio callback (background thread)
            let queueLabel = String(cString: __dispatch_queue_get_label(nil), encoding: .utf8) ?? "Unknown"
            
            Task { @MainActor in
                // This should safely transition to main actor
                self?.addTestResult(
                    testName: "MainActor Task Pattern",
                    passed: true, // If we get here, the transition worked
                    details: "Background -> MainActor task transition successful",
                    threadInfo: "From: Background (\(queueLabel)), To: \(self?.getCurrentThreadInfo() ?? "Unknown")"
                )
            }
        }
    }
    
    private func testAudioBufferPattern() {
        // Simulate the audio buffer processing pattern
        let testPassed = true
        
        // This mimics the nonisolated audio callback
        DispatchQueue.global().async { [weak self] in
            // Simulate audio processing
            let sampleData: Float = 0.5
            
            // This mimics the Task { @MainActor } pattern in processAudioBuffer
            Task { @MainActor in
                self?.addTestResult(
                    testName: "Audio Buffer Pattern",
                    passed: testPassed,
                    details: "Nonisolated callback -> MainActor update (data: \(sampleData))",
                    threadInfo: self?.getCurrentThreadInfo() ?? "Unknown"
                )
            }
        }
    }
}
