/*
 See LICENSE folder for this sample's licensing information.
 */

import SwiftUI
import TranscriptionKit
import CoreAudio

struct SimpleTranscriptionView: View {
    @State private var speechRecognizer = SpeechRecognizer()
    @State private var isRunning = false
    @State private var errorWrapper: ErrorWrapper?
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Audio Input Device Selector (only show when not running)
            if !isRunning {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Audio Input Device")
                            .font(.headline)
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
                    }
                    
                    ScrollView {
                        Text(speechRecognizer.transcript.isEmpty ? "Speak now..." : speechRecognizer.transcript)
                            .font(.body)
                            .foregroundColor(speechRecognizer.transcript.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .frame(width: 400, height: 150)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
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
            // Request permissions on appear
            speechRecognizer.refreshAudioDevices()
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
}

#Preview {
    SimpleTranscriptionView()
}
