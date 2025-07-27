/*
 See LICENSE folder for this sample's licensing information.
 */

import SwiftUI
import TranscriptionKit
import CoreAudio

struct SimpleTranscriptionView: View {
    @State private var speechRecognizer = SpeechRecognizer()
    @StateObject private var openAIService = OpenAIService()
    @State private var isRunning = false
    @State private var errorWrapper: ErrorWrapper?
    @State private var isMonitoringOutput = false
    @State private var lastSummarizedLength = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Audio Device Configuration (only show when not running)
            if !isRunning {
                VStack(spacing: 15) {
                    // Mode Toggle
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Audio Source")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Picker("Audio Source", selection: $isMonitoringOutput) {
                            Text("Microphone Input")
                                .tag(false)
                            Text("System Output")
                                .tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 300)
                        .onChange(of: isMonitoringOutput) { _, newValue in
                            // Reset selections when switching modes
                            if newValue {
                                speechRecognizer.selectInputDevice(nil)
                            } else {
                                speechRecognizer.selectOutputDevice(nil)
                            }
                        }
                    }
                    
                    // Device Selector based on mode
                    if isMonitoringOutput {
                        // Output Device Selector
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Output Device to Monitor")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Button(action: {
                                    speechRecognizer.refreshAudioDevices()
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help("Refresh audio devices")
                            }
                            
                            Picker("Output Device", selection: Binding(
                                get: { speechRecognizer.selectedOutputDevice?.id ?? 0 },
                                set: { newValue in
                                    if newValue == 0 {
                                        speechRecognizer.selectOutputDevice(nil)
                                    } else {
                                        let selectedDevice = speechRecognizer.availableOutputDevices.first { $0.id == newValue }
                                        speechRecognizer.selectOutputDevice(selectedDevice)
                                    }
                                }
                            )) {
                                Text("Default Output")
                                    .tag(AudioDeviceID(0))
                                
                                ForEach(speechRecognizer.availableOutputDevices, id: \.id) { device in
                                    Text(device.name)
                                        .tag(device.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 300)
                            
                            // Show selected device info
                            if let selectedDevice = speechRecognizer.selectedOutputDevice {
                                Text("Monitoring: \(selectedDevice.name)")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            } else {
                                Text("Using system default output")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Info about output monitoring
                            Text("💡 Use BlackHole or similar to route system audio")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.top, 4)
                        }
                    } else {
                        // Input Device Selector
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Input Device")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Button(action: {
                                    speechRecognizer.refreshAudioDevices()
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help("Refresh audio devices")
                            }
                            
                            Picker("Input Device", selection: Binding(
                                get: { speechRecognizer.selectedInputDevice?.id ?? 0 },
                                set: { newValue in
                                    if newValue == 0 {
                                        speechRecognizer.selectInputDevice(nil)
                                    } else {
                                        let selectedDevice = speechRecognizer.availableInputDevices.first { $0.id == newValue }
                                        speechRecognizer.selectInputDevice(selectedDevice)
                                    }
                                }
                            )) {
                                Text("Default Input")
                                    .tag(AudioDeviceID(0))
                                
                                ForEach(speechRecognizer.availableInputDevices, id: \.id) { device in
                                    Text(device.name)
                                        .tag(device.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 300)
                            
                            // Show selected device info
                            if let selectedDevice = speechRecognizer.selectedInputDevice {
                                Text("Selected: \(selectedDevice.name)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Using system default input")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.bottom, 10)
            }
            
            Button(action: {
                if isRunning {
                    stopTranscription()
                } else {
                    startTranscription()
                }
            }) {
                Text(isRunning ? "Stop" : "Run")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 120, height: 60)
                    .background(isRunning ? Color.red : Color.blue)
                    .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Always show transcript area when running
            if isRunning {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .opacity(0.8)
                            .scaleEffect(1.5)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isRunning)
                        
                        Text("Listening...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    // Transcript Box
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Transcript")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        ScrollView {
                            Text(speechRecognizer.transcript.isEmpty ? "Speak now..." : speechRecognizer.transcript)
                                .font(.body)
                                .foregroundColor(speechRecognizer.transcript.isEmpty ? .secondary : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                        .frame(width: 400, height: 120)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Summary Box
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("AI Analysis")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: {
                                Task {
                                    await generateSummary()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    if openAIService.isGeneratingSummary {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "chart.bar.doc.horizontal")
                                    }
                                    Text("Analyse")
                                }
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(speechRecognizer.transcript.isEmpty ? Color.gray : Color.green)
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(openAIService.isGeneratingSummary || speechRecognizer.transcript.isEmpty)
                            
                            if let error = openAIService.lastError {
                                Text("⚠️")
                                    .foregroundColor(.orange)
                                    .help("Error: \(error)")
                            }
                        }
                        
                        ScrollView {
                            Text(openAIService.summary.isEmpty ? "Click 'Analyse' to generate an AI analysis..." : openAIService.summary)
                                .font(.body)
                                .foregroundColor(openAIService.summary.isEmpty ? .secondary : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                        .frame(width: 400, height: 100)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                .onChange(of: speechRecognizer.transcript) { _, newTranscript in
                    // Auto-summarize when transcript grows significantly
                    if newTranscript.count > lastSummarizedLength + 500 {
                        Task {
                            await generateSummary()
                        }
                    }
                }
            }
            
            Spacer()
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
}

#Preview {
    SimpleTranscriptionView()
}
