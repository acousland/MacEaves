import SwiftUI
@preconcurrency import AVFoundation
import TranscriptionKit

struct VUMeterView: View {
    @StateObject private var monitor = AudioLevelMonitor()
    @State private var speechRecognizer = SpeechRecognizer()
    
    var body: some View {
        VStack(spacing: 20) {
            headerView
            deviceConfigurationView
            vuMetersView
            controlsView
        }
        .padding()
        .navigationTitle("Audio Monitor")
        .onAppear {
            speechRecognizer.refreshAudioDevices()
        }
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        Text("Audio Level Monitor")
            .font(.title)
            .padding(.bottom)
    }
    
    private var deviceConfigurationView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Audio Device Configuration")
                .font(.headline)
            
            HStack {
                Text("Mode:")
                Picker("Mode", selection: $monitor.isMonitoringOutput) {
                    Text("Input").tag(false)
                    Text("Output").tag(true)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            VStack(alignment: .leading) {
                Text("Device:")
                Picker("Device", selection: $monitor.selectedDevice) {
                    Text("Default").tag(nil as AudioDevice?)
                    
                    if !monitor.isMonitoringOutput {
                        ForEach(speechRecognizer.availableInputDevices, id: \.id) { device in
                            Text(device.name).tag(device)
                        }
                    } else {
                        ForEach(speechRecognizer.availableOutputDevices, id: \.id) { device in
                            Text(device.name).tag(device)
                        }
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Button("Refresh Devices") {
                    speechRecognizer.refreshAudioDevices()
                }
                .font(.caption)
            }
        }
    }
    
    private var vuMetersView: some View {
        VStack(spacing: 15) {
            Text("Audio Levels")
                .font(.headline)
            
            HStack(spacing: 30) {
                VUMeterBar(
                    label: "Left",
                    level: monitor.leftChannelLevel,
                    peak: monitor.peakLevel
                )
                
                VUMeterBar(
                    label: "Right", 
                    level: monitor.rightChannelLevel,
                    peak: monitor.peakLevel
                )
            }
            
            Text("Peak: \(String(format: "%.1f", monitor.peakLevel)) dB")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var controlsView: some View {
        HStack(spacing: 20) {
            Button(monitor.isMonitoring ? "Stop Monitoring" : "Start Monitoring") {
                if monitor.isMonitoring {
                    monitor.stopMonitoring()
                } else {
                    monitor.startMonitoring(device: monitor.selectedDevice, isOutput: monitor.isMonitoringOutput)
                }
            }
            .padding()
            .background(monitor.isMonitoring ? Color.red : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            if let error = monitor.lastError {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

struct VUMeterBar: View {
    let label: String
    let level: Float
    let peak: Float
    
    private let meterHeight: CGFloat = 200
    private let meterWidth: CGFloat = 40
    
    var body: some View {
        VStack {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
            
            ZStack(alignment: .bottom) {
                // Background
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: meterWidth, height: meterHeight)
                    .border(Color.gray, width: 1)
                
                // Level indicator
                Rectangle()
                    .fill(levelGradient)
                    .frame(width: meterWidth, height: max(0, levelHeight))
                
                // Peak indicator
                Rectangle()
                    .fill(Color.red)
                    .frame(width: meterWidth, height: 2)
                    .offset(y: -peakOffset)
            }
            
            Text("\(String(format: "%.1f", level)) dB")
                .font(.caption2)
                .monospacedDigit()
        }
    }
    
    private var levelHeight: CGFloat {
        // Level is already in dB (-60 to 0), convert to height
        let clampedLevel = max(-60, min(0, level))
        return meterHeight * CGFloat((clampedLevel + 60) / 60)
    }
    
    private var peakOffset: CGFloat {
        // Peak is already in dB (-60 to 0), convert to offset from top
        let clampedPeak = max(-60, min(0, peak))
        return meterHeight * CGFloat((60 - (clampedPeak + 60)) / 60)
    }
    
    private var levelGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [.green, .yellow, .red]),
            startPoint: .bottom,
            endPoint: .top
        )
    }
}

#Preview {
    VUMeterView()
}