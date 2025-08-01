/*
 See LICENSE folder for this sample's licensing information.
 */

import SwiftUI
import TranscriptionKit
import CoreAudio

struct SimpleTranscriptionView: View {
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @StateObject private var openAIService = OpenAIService()
    @State private var isRunning = false
    @State private var errorWrapper: ErrorWrapper?
    @State private var isMonitoringOutput = false
    @State private var lastSummarizedLength = 0
    @State private var lastActionItemsLength = 0
    @State private var lastTopicContextLength = 0
    @State private var autoUpdateTimer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Header Section
                    headerSection()
                        .padding(.top, 20)
                        .padding(.horizontal, 30)
                    
                    // Main Content Area
                    if isRunning {
                        runningContentView(geometry: geometry)
                    } else {
                        configurationView(geometry: geometry)
                    }
                    
                    Spacer(minLength: 20)
                }
            }
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.02), Color.purple.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Error", isPresented: .constant(errorWrapper != nil)) {
            Button("OK") {
                errorWrapper = nil
            }
        } message: {
            Text(errorWrapper?.error.localizedDescription ?? "Unknown error occurred")
        }
        .onAppear {
            print("🏁 Debug: SimpleTranscriptionView appeared")
            print("🤖 OpenAI Service initialized: \(openAIService)")
            
            // Request permissions and initialize devices on appear
            Task {
                await MainActor.run {
                    speechRecognizer.refreshAudioDevices()
                    print("🔄 Audio devices refreshed")
                }
            }
        }
        .onDisappear {
            // Clean up timer when view disappears
            stopAutoUpdateTimer()
        }
    }
    
    @ViewBuilder
    private func headerSection() -> some View {
        VStack(spacing: 16) {
            Text("AI Transcription & Analysis")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Real-time speech transcription with AI-powered insights")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }
    
    @ViewBuilder
    private func configurationView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 24) {
            audioDeviceSection()
            openAISection()
            controlButtonsSection()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: min(600, geometry.size.width * 0.8))
    }
    
    @ViewBuilder
    private func audioDeviceSection() -> some View {
        // Audio Device Configuration
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundColor(.blue)
                Text("Audio Device")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            if speechRecognizer.availableInputDevices.isEmpty {
                Text("No audio devices available")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            } else {
                Picker("Select Audio Device", selection: $speechRecognizer.selectedInputDevice) {
                    Text("None").tag(nil as AudioDevice?)
                    ForEach(speechRecognizer.availableInputDevices, id: \.id) { device in
                        Text(device.name).tag(Optional(device))
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }
    
    @ViewBuilder
    private func openAISection() -> some View {
        // OpenAI Configuration Status
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain")
                    .foregroundColor(.purple)
                Text("AI Configuration")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            HStack {
                Image(systemName: openAIService.isConfigured ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(openAIService.isConfigured ? .green : .red)
                
                Text(openAIService.isConfigured ? "OpenAI API configured" : "OpenAI API not configured")
                    .foregroundColor(openAIService.isConfigured ? .primary : .secondary)
                
                Spacer()
            }
            .padding()
            .background(openAIService.isConfigured ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
            .cornerRadius(8)
            
            if !openAIService.isConfigured {
                Text("Please add your OpenAI API key to Config.plist")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func controlButtonsSection() -> some View {
        HStack(spacing: 20) {
            recordingButton
        }
    }
    
    private var recordingButton: some View {
        let buttonAction = isRunning ? stopTranscription : startTranscription
        let iconName = isRunning ? "stop.circle.fill" : "play.circle.fill"
        let buttonText = isRunning ? "Stop Recording" : "Start Recording"
        let buttonColor = isRunning ? Color.red : Color.green
        
        return Button(action: buttonAction) {
            HStack {
                Image(systemName: iconName)
                Text(buttonText)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(buttonColor)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .disabled(speechRecognizer.selectedInputDevice == nil)
    }
    
    @ViewBuilder
    private var summaryButton: some View {
        Button("Generate Summary") {
            Task {
                await generateSummary()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private var actionItemsButton: some View {
        Button("Generate Action Items") {
            Task {
                await generateActionItems()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.orange)
        .foregroundColor(.white)
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private var topicContextButton: some View {
        Button("Current Topic") {
            Task {
                await generateTopicContext()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.purple)
        .foregroundColor(.white)
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private func runningContentView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 24) {
            // Control buttons at the top when running
            HStack(spacing: 20) {
                recordingButton
                
                if !speechRecognizer.transcript.isEmpty {
                    summaryButton
                    actionItemsButton
                    topicContextButton
                }
            }
            .padding(.bottom, 16)
            
            if !speechRecognizer.transcript.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "text.bubble")
                            .foregroundColor(.blue)
                        Text("Live Transcript")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    ScrollView {
                        Text(speechRecognizer.transcript)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                    }
                    .frame(height: 150)
                }
                .frame(maxWidth: min(800, geometry.size.width * 0.9))
            }
            
            if !openAIService.summary.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.green)
                        Text("AI Summary")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    ScrollView {
                        Text(openAIService.summary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .frame(height: 120)
                }
                .frame(maxWidth: min(800, geometry.size.width * 0.9))
            }
            
            if !openAIService.actionItems.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "list.bullet.clipboard")
                            .foregroundColor(.orange)
                        Text("Action Items")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    ScrollView {
                        Text(openAIService.actionItems)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .frame(height: 120)
                }
                .frame(maxWidth: min(800, geometry.size.width * 0.9))
            }
            
            if !openAIService.topicContext.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .foregroundColor(.purple)
                        Text("Current Topic")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    ScrollView {
                        Text(openAIService.topicContext)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .frame(height: 100)
                }
                .frame(maxWidth: min(800, geometry.size.width * 0.9))
            }
        }
        .padding(.horizontal, 32)
    }
    
    private func startTranscription() {
        speechRecognizer.resetTranscript()
        speechRecognizer.startTranscribing()
        isRunning = true
        
        // Reset summary tracking for new session
        lastSummarizedLength = 0
        lastActionItemsLength = 0
        lastTopicContextLength = 0
        
        // Clear previous summaries to start fresh
        openAIService.summary = ""
        openAIService.actionItems = ""
        openAIService.topicContext = ""
        
        // Start auto-update timer (every 10 seconds)
        startAutoUpdateTimer()
    }
    
    private func stopTranscription() {
        speechRecognizer.stopTranscribing()
        isRunning = false
        
        // Stop auto-update timer
        stopAutoUpdateTimer()
    }
    
    @MainActor
    private func generateSummary() async {
        print("🎯 Debug: generateSummary() called")
        print("📝 Current transcript: '\(speechRecognizer.transcript)'")
        print("📏 Transcript length: \(speechRecognizer.transcript.count)")
        print("📏 Last summarized length: \(lastSummarizedLength)")
        
        guard !speechRecognizer.transcript.isEmpty else { 
            print("⚠️ Warning: Transcript is empty, skipping summary generation")
            return 
        }
        
        // Check if there's new content since last summary
        let hasNewContent = speechRecognizer.transcript.count > lastSummarizedLength
        if !hasNewContent && !openAIService.summary.isEmpty {
            print("ℹ️ No new content since last summary, skipping generation")
            return
        }
        
        print("🚀 Starting OpenAI summary generation...")
        
        do {
            try await openAIService.generateSummary(from: speechRecognizer.transcript)
            lastSummarizedLength = speechRecognizer.transcript.count
            print("✅ Summary generation completed successfully")
        } catch {
            let errorMessage = "Error generating summary: \(error)"
            print("❌ \(errorMessage)")
            
            // Also update the error wrapper for user display
            errorWrapper = ErrorWrapper(error: error, guidance: "Please check your internet connection and API key configuration.")
        }
    }
    
    @MainActor
    private func generateActionItems() async {
        print("📋 Debug: generateActionItems() called")
        print("📝 Current transcript: '\(speechRecognizer.transcript)'")
        print("📏 Transcript length: \(speechRecognizer.transcript.count)")
        
        guard !speechRecognizer.transcript.isEmpty else { 
            print("⚠️ Warning: Transcript is empty, skipping action items generation")
            return 
        }
        
        print("🚀 Starting OpenAI action items generation...")
        
        do {
            try await openAIService.generateActionItems(from: speechRecognizer.transcript)
            lastActionItemsLength = speechRecognizer.transcript.count
            print("✅ Action items generation completed successfully")
        } catch {
            let errorMessage = "Error generating action items: \(error)"
            print("❌ \(errorMessage)")
            
            // Also update the error wrapper for user display
            errorWrapper = ErrorWrapper(error: error, guidance: "Please check your internet connection and API key configuration.")
        }
    }
    
    @MainActor
    private func generateTopicContext() async {
        print("🎯 Debug: generateTopicContext() called")
        print("📝 Current transcript: '\(speechRecognizer.transcript)'")
        print("📏 Transcript length: \(speechRecognizer.transcript.count)")
        
        guard !speechRecognizer.transcript.isEmpty else { 
            print("⚠️ Warning: Transcript is empty, skipping topic context generation")
            return 
        }
        
        print("🚀 Starting OpenAI topic context generation...")
        
        do {
            try await openAIService.generateTopicContext(from: speechRecognizer.transcript)
            lastTopicContextLength = speechRecognizer.transcript.count
            print("✅ Topic context generation completed successfully")
        } catch {
            let errorMessage = "Error generating topic context: \(error)"
            print("❌ \(errorMessage)")
            
            // Also update the error wrapper for user display
            errorWrapper = ErrorWrapper(error: error, guidance: "Please check your internet connection and API key configuration.")
        }
    }
    
    // MARK: - Timer Management
    
    private func startAutoUpdateTimer() {
        // Cancel any existing timer
        stopAutoUpdateTimer()
        
        // Start new timer for 10-second intervals
        autoUpdateTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            // Only update if we're still recording
            Task { @MainActor in
                if isRunning {
                    await generateSummary()
                    await generateActionItems()
                    await generateTopicContext()
                }
            }
        }
    }
    
    private func stopAutoUpdateTimer() {
        autoUpdateTimer?.invalidate()
        autoUpdateTimer = nil
    }
}

#Preview {
    SimpleTranscriptionView()
}

