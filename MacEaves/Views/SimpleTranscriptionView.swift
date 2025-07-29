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
    @State private var openAIKey = ""
    
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
                            Text(device.name).tag(device as AudioDevice?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
            
            // OpenAI Configuration
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "brain")
                        .foregroundColor(.purple)
                    Text("AI Configuration")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                SecureField("OpenAI API Key", text: $openAIKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
            }
            
            // Control Buttons
            HStack(spacing: 20) {
                Button(action: isRunning ? stopTranscription : startTranscription) {
                    HStack {
                        Image(systemName: isRunning ? "stop.circle.fill" : "play.circle.fill")
                        Text(isRunning ? "Stop Recording" : "Start Recording")
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(isRunning ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(speechRecognizer.selectedInputDevice == nil)
                
                if !speechRecognizer.transcript.isEmpty {
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
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: min(600, geometry.size.width * 0.8))
    }
    
    @ViewBuilder
    private func runningContentView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 24) {
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
        }
        .padding(.horizontal, 32)
    }
    
    private func startTranscription() {
        speechRecognizer.resetTranscript()
        speechRecognizer.startTranscribing()
        isRunning = true
    }
    
    private func stopTranscription() {
        speechRecognizer.stopTranscribing()
        isRunning = false
    }
    
    @MainActor
    private func generateSummary() async {
        print("🎯 Debug: generateSummary() called")
        print("📝 Current transcript: '\(speechRecognizer.transcript)'")
        print("📏 Transcript length: \(speechRecognizer.transcript.count)")
        
        guard !speechRecognizer.transcript.isEmpty else { 
            print("⚠️ Warning: Transcript is empty, skipping summary generation")
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
}

#Preview {
    SimpleTranscriptionView()
}

