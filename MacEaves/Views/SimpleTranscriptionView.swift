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
    @State private var isMonitoringOutput = false
    
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
            // Request permissions and initialize devices on appear
            Task {
                await MainActor.run {
                    speechRecognizer.refreshAudioDevices()
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
}

#Preview {
    SimpleTranscriptionView()
}
