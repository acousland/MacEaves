/*
 SimpleThreadingLogger for MacEaves
 Basic threading issue detection and logging
 */

import Foundation
import os.log

public class SimpleThreadingLogger {
    private static let logger = Logger(subsystem: "MacEaves", category: "Threading")
    
    public static func logContext(_ message: String = "", file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let thread = Thread.current
        let isMain = thread.isMainThread ? "Main" : "Background"
        
        // Get queue name safely
        let queueName = String(cString: __dispatch_queue_get_label(nil), encoding: .utf8) ?? "Unknown"
        
        let logMessage = "🧵 [\(fileName):\(line)] \(function) - \(isMain) thread, Queue: \(queueName) \(message)"
        print(logMessage)
        logger.info("\(logMessage)")
        
        // Warn if we're not on main thread when we should be
        if !thread.isMainThread && (function.contains("UI") || function.contains("startMonitoring") || function.contains("Timer")) {
            let warning = "⚠️ WARNING: \(function) may need to be on main thread!"
            print(warning)
            logger.warning("\(warning)")
        }
    }
    
    public static func assertMainThread(_ message: String = "", file: String = #file, function: String = #function, line: Int = #line) {
        if !Thread.isMainThread {
            let fileName = (file as NSString).lastPathComponent
            let error = "❌ ASSERTION FAILED: \(fileName):\(line) \(function) - Expected main thread! \(message)"
            print(error)
            logger.error("\(error)")
            assertionFailure(error)
        }
    }
    
    public static func logTimerCreation(_ message: String = "", file: String = #file, function: String = #function, line: Int = #line) {
        logContext("Timer creation: \(message)", file: file, function: function, line: line)
        
        if !Thread.isMainThread {
            print("⚠️ WARNING: Timer creation on background thread may cause dispatch queue assertion!")
            logger.warning("Timer creation on background thread detected")
        }
    }
}
