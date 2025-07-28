import SwiftUI
@preconcurrency import AVFoundation
import TranscriptionKit

struct MultiDeviceVUMeterView: View {
    @State private var speechRecognizer = SpeechRecognizer()
    @State private var inputMonitors: [TranscriptionKit.AudioDevice.ID: AudioLevelMonitor] = [:]
    @State private var outputMonitors: [TranscriptionKit.AudioDevice.ID: AudioLevelMonitor] = [:]
    @State private var isMonitoringInputs = true
    @State private var isMonitoringOutputs = false
    
    // Convert TranscriptionKit.AudioDevice to MacEaves.AudioDevice
    private func convertToMacEavesAudioDevice(_ device: TranscriptionKit.AudioDevice) -> MacEaves.AudioDevice {
        return MacEaves.AudioDevice(id: device.id, name: device.name)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerView
                controlsView
                
                if isMonitoringInputs {
                    inputDevicesSection
                }
                
                if isMonitoringOutputs {
                    outputDevicesSection
                }
            }
            .padding()
        }
        .navigationTitle("Multi-Device Audio Monitor")
        .onAppear {
            speechRecognizer.refreshAudioDevices()
            setupDeviceMonitors()
        }
        .onDisappear {
            stopAllMonitoring()
        }
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        VStack {
            Text("Multi-Device Audio Monitor")
                .font(.title)
                .padding(.bottom, 5)
            
            Text("Monitor all audio interfaces simultaneously")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var controlsView: some View {
        VStack(spacing: 15) {
            HStack(spacing: 20) {
                Button(isMonitoringInputs ? "Stop Input Monitoring" : "Start Input Monitoring") {
                    toggleInputMonitoring()
                }
                .padding()
                .background(isMonitoringInputs ? Color.red : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Button(isMonitoringOutputs ? "Stop Output Monitoring" : "Start Output Monitoring") {
                    toggleOutputMonitoring()
                }
                .padding()
                .background(isMonitoringOutputs ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            Button("Refresh Devices") {
                speechRecognizer.refreshAudioDevices()
                setupDeviceMonitors()
            }
            .font(.caption)
        }
    }
    
    private var inputDevicesSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Input Devices")
                .font(.headline)
                .foregroundColor(.blue)
            
            if speechRecognizer.availableInputDevices.isEmpty {
                Text("No input devices available")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    ForEach(speechRecognizer.availableInputDevices, id: \.id) { device in
                        DeviceVUMeterCard(
                            device: convertToMacEavesAudioDevice(device),
                            monitor: inputMonitors[device.id] ?? AudioLevelMonitor(),
                            isInput: true,
                            isActive: isMonitoringInputs
                        )
                    }
                }
            }
        }
    }
    
    private var outputDevicesSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Output Devices")
                .font(.headline)
                .foregroundColor(.green)
            
            if speechRecognizer.availableOutputDevices.isEmpty {
                Text("No output devices available")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    ForEach(speechRecognizer.availableOutputDevices, id: \.id) { device in
                        DeviceVUMeterCard(
                            device: convertToMacEavesAudioDevice(device),
                            monitor: outputMonitors[device.id] ?? AudioLevelMonitor(),
                            isInput: false,
                            isActive: isMonitoringOutputs
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Functions
    
    private func setupDeviceMonitors() {
        // Clear existing monitors
        stopAllMonitoring()
        inputMonitors.removeAll()
        outputMonitors.removeAll()
        
        // Create monitors for input devices
        for device in speechRecognizer.availableInputDevices {
            let monitor = AudioLevelMonitor()
            inputMonitors[device.id] = monitor
        }
        
        // Create monitors for output devices
        for device in speechRecognizer.availableOutputDevices {
            let monitor = AudioLevelMonitor()
            outputMonitors[device.id] = monitor
        }
    }
    
    private func toggleInputMonitoring() {
        if isMonitoringInputs {
            stopInputMonitoring()
        } else {
            startInputMonitoring()
        }
    }
    
    private func toggleOutputMonitoring() {
        if isMonitoringOutputs {
            stopOutputMonitoring()
        } else {
            startOutputMonitoring()
        }
    }
    
    private func startInputMonitoring() {
        for (deviceId, monitor) in inputMonitors {
            if let device = speechRecognizer.availableInputDevices.first(where: { $0.id == deviceId }) {
                monitor.startMonitoring(device: convertToMacEavesAudioDevice(device), isOutput: false)
            }
        }
        isMonitoringInputs = true
    }
    
    private func stopInputMonitoring() {
        for monitor in inputMonitors.values {
            monitor.stopMonitoring()
        }
        isMonitoringInputs = false
    }
    
    private func startOutputMonitoring() {
        for (deviceId, monitor) in outputMonitors {
            if let device = speechRecognizer.availableOutputDevices.first(where: { $0.id == deviceId }) {
                monitor.startMonitoring(device: convertToMacEavesAudioDevice(device), isOutput: true)
            }
        }
        isMonitoringOutputs = true
    }
    
    private func stopOutputMonitoring() {
        for monitor in outputMonitors.values {
            monitor.stopMonitoring()
        }
        isMonitoringOutputs = false
    }
    
    private func stopAllMonitoring() {
        stopInputMonitoring()
        stopOutputMonitoring()
    }
}

struct DeviceVUMeterCard: View {
    let device: MacEaves.AudioDevice
    let monitor: AudioLevelMonitor?
    let isInput: Bool
    let isActive: Bool
    
    var body: some View {
        VStack(spacing: 10) {
            // Device name header
            VStack {
                Text(device.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 30)
                
                Text(isInput ? "Input" : "Output")
                    .font(.caption2)
                    .foregroundColor(isInput ? .blue : .green)
            }
            
            // VU Meters
            if let monitor = monitor, isActive {
                HStack(spacing: 10) {
                    CompactVUMeterBar(
                        label: "L",
                        level: monitor.leftChannelLevel,
                        peak: monitor.peakLevel
                    )
                    
                    CompactVUMeterBar(
                        label: "R",
                        level: monitor.rightChannelLevel,
                        peak: monitor.peakLevel
                    )
                }
                
                // Level readouts
                VStack(spacing: 2) {
                    Text("Avg: \(String(format: "%.1f", monitor.averageLevel)) dB")
                        .font(.caption2)
                        .monospacedDigit()
                    
                    Text("Peak: \(String(format: "%.1f", monitor.peakLevel)) dB")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundColor(.red)
                }
            } else {
                // Inactive state
                HStack(spacing: 10) {
                    CompactVUMeterBar(label: "L", level: -60, peak: -60)
                    CompactVUMeterBar(label: "R", level: -60, peak: -60)
                }
                
                Text(isActive ? "No Signal" : "Inactive")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Error display
            if let monitor = monitor, let error = monitor.lastError {
                Text("Error: \(error)")
                    .font(.caption2)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isActive ? (isInput ? Color.blue : Color.green) : Color.gray, lineWidth: 1)
                )
        )
        .frame(minWidth: 120, minHeight: 140)
    }
}

struct CompactVUMeterBar: View {
    let label: String
    let level: Float
    let peak: Float
    
    private let meterHeight: CGFloat = 60
    private let meterWidth: CGFloat = 20
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
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
                if peakOffset < meterHeight {
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: meterWidth, height: 1)
                        .offset(y: -peakOffset)
                }
            }
        }
    }
    
    private var levelHeight: CGFloat {
        let clampedLevel = max(-60, min(0, level))
        return meterHeight * CGFloat((clampedLevel + 60) / 60)
    }
    
    private var peakOffset: CGFloat {
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
    MultiDeviceVUMeterView()
}
