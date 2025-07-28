/*
 TestingControlView for MacEaves
 Simple UI for running threading tests
 */

import SwiftUI

struct TestingControlView: View {
    @StateObject private var threadingValidator = ThreadingValidator()
    @StateObject private var audioTester = AudioMonitorTester()
    @State private var showTestResults = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("MacEaves Threading Tests")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Threading Validator Controls
            GroupBox("Threading Validator") {
                VStack(spacing: 10) {
                    HStack {
                        Button(threadingValidator.isValidating ? "Stop Validation" : "Start Validation") {
                            if threadingValidator.isValidating {
                                threadingValidator.stopValidation()
                            } else {
                                threadingValidator.startValidation()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Spacer()
                        
                        Text("\(threadingValidator.violations.count) violations")
                            .foregroundColor(threadingValidator.violations.isEmpty ? .green : .red)
                    }
                    
                    if !threadingValidator.violations.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Recent Violations:")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            ForEach(threadingValidator.violations.suffix(3)) { violation in
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(violation.type.rawValue)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Text(violation.description)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                            }
                        }
                        .padding(.top, 5)
                    }
                }
            }
            
            // Audio Monitor Tester Controls
            GroupBox("Audio Monitor Tester") {
                VStack(spacing: 10) {
                    HStack {
                        Button("Run Audio Tests") {
                            audioTester.runTests()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(audioTester.isRunning)
                        
                        Button("Test Audio Patterns") {
                            audioTester.testAudioLevelMonitorPatterns()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        if audioTester.isRunning {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    if !audioTester.testResults.isEmpty {
                        let passedCount = audioTester.testResults.filter { $0.passed }.count
                        let totalCount = audioTester.testResults.count
                        
                        HStack {
                            Text("Tests: \(passedCount)/\(totalCount) passed")
                                .font(.caption)
                                .foregroundColor(passedCount == totalCount ? .green : .orange)
                            
                            Spacer()
                            
                            Button("View Results") {
                                showTestResults = true
                            }
                            .font(.caption)
                        }
                    }
                }
            }
            
            // Quick Actions
            GroupBox("Quick Actions") {
                VStack(spacing: 8) {
                    Button("Clear All Results") {
                        threadingValidator.clearViolations()
                        audioTester.testResults.removeAll()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Test Current State") {
                        let issues = ThreadingValidator.validateAudioMonitorUsage()
                        for issue in issues {
                            print("⚠️ Issue: \(issue)")
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: 400)
        .sheet(isPresented: $showTestResults) {
            TestResultsView(audioTester: audioTester, threadingValidator: threadingValidator)
        }
    }
}

struct TestResultsView: View {
    let audioTester: AudioMonitorTester
    let threadingValidator: ThreadingValidator
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Audio Monitor Tests") {
                    ForEach(audioTester.testResults.reversed()) { result in
                        HStack {
                            Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.passed ? .green : .red)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.testName)
                                    .fontWeight(.medium)
                                Text(result.details)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(result.threadInfo)
                                    .font(.caption2)
                                    .foregroundColor(.tertiary)
                            }
                            
                            Spacer()
                            
                            Text(result.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Threading Violations") {
                    if threadingValidator.violations.isEmpty {
                        Text("No violations detected")
                            .foregroundColor(.green)
                            .italic()
                    } else {
                        ForEach(threadingValidator.violations.reversed()) { violation in
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(violation.type.rawValue)
                                        .fontWeight(.medium)
                                    Text(violation.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(violation.threadInfo)
                                        .font(.caption2)
                                        .foregroundColor(.tertiary)
                                }
                                
                                Spacer()
                                
                                Text(violation.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Test Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    TestingControlView()
}
