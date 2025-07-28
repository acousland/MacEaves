/*
 AudioLevelMonitor for MacEaves
 Provides real-time audio level monitoring for VU meter display
 */

import Foundation
@preconcurrency import AVFoundation
import CoreAudio
import SwiftUI

// Define AudioDevice locally to avoid import issues
public struct AudioDevice: Identifiable, Sendable, Hashable {
    public let id: AudioDeviceID
    public let name: String
    
    public init(id: AudioDeviceID, name: String) {
        self.id = id
        self.name = name
    }
}

@MainActor
public class AudioLevelMonitor: ObservableObject {
    // Audio levels for each channel (stereo)
    @Published public var leftChannelLevel: Float = 0.0
    @Published public var rightChannelLevel: Float = 0.0
    @Published public var averageLevel: Float = 0.0
    @Published public var peakLevel: Float = 0.0
    
    // Monitoring state
    @Published public var isMonitoring: Bool = false
    @Published public var selectedDevice: AudioDevice?
    @Published public var isMonitoringOutput: Bool = false
    
    // Error handling
    @Published public var lastError: String?
    
    private var audioEngine: AVAudioEngine?
    private var audioUnit: AudioUnit?
    private var levelUpdateTimer: Timer?
    
    // Audio level smoothing
    private var leftLevelSmoothed: Float = 0.0
    private var rightLevelSmoothed: Float = 0.0
    private let smoothingFactor: Float = 0.8
    
    public init() {}
    
    public func startMonitoring(device: AudioDevice?, isOutput: Bool = false) {
        Task { @MainActor in
            print("🎚️ Starting audio level monitoring...")
            print("📱 Device: \(device?.name ?? "Default")")
            print("🔊 Is Output: \(isOutput)")
            
            stopMonitoring() // Stop any existing monitoring
            
            selectedDevice = device
            isMonitoringOutput = isOutput
            lastError = nil
            
            do {
                if isOutput {
                    try startOutputMonitoring(device: device)
                } else {
                    try startInputMonitoring(device: device)
                }
                
                isMonitoring = true
                startLevelUpdateTimer()
                print("✅ Audio monitoring started successfully")
                
            } catch {
                let errorMessage = "Failed to start audio monitoring: \(error.localizedDescription)"
                print("❌ \(errorMessage)")
                lastError = errorMessage
                isMonitoring = false
            }
        }
    }
    
    public func stopMonitoring() {
        print("🛑 Stopping audio level monitoring...")
        
        levelUpdateTimer?.invalidate()
        levelUpdateTimer = nil
        
        if let audioEngine = audioEngine {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        audioEngine = nil
        audioUnit = nil
        isMonitoring = false
        
        // Reset levels
        leftChannelLevel = 0.0
        rightChannelLevel = 0.0
        averageLevel = 0.0
        peakLevel = 0.0
        
        print("✅ Audio monitoring stopped")
    }
    
    private func startInputMonitoring(device: AudioDevice?) throws {
        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine
        
        // Configure input device if specified
        if let device = device {
            try configureInputDevice(audioEngine: audioEngine, deviceID: device.id)
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        print("🎤 Input format: \(recordingFormat)")
        print("📊 Sample rate: \(recordingFormat.sampleRate), Channels: \(recordingFormat.channelCount)")
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer: buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    private func startOutputMonitoring(device: AudioDevice?) throws {
        // For output monitoring, we need to tap into the system output
        // This is more complex and requires specific configuration
        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine
        
        // Configure output device if specified
        if let device = device {
            try configureOutputDevice(audioEngine: audioEngine, deviceID: device.id)
        }
        
        // For output monitoring, we'll try to tap the input side of the selected output device
        // This works when using BlackHole or similar virtual devices
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        print("🔊 Output monitoring format: \(recordingFormat)")
        print("📊 Sample rate: \(recordingFormat.sampleRate), Channels: \(recordingFormat.channelCount)")
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer: buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    private func configureInputDevice(audioEngine: AVAudioEngine, deviceID: AudioDeviceID) throws {
        var deviceID = deviceID
        let propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // Set the input device
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            propertySize,
            &deviceID
        )
        
        if status != noErr {
            throw NSError(domain: "AudioLevelMonitor", code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "Failed to set input device"
            ])
        }
    }
    
    private func configureOutputDevice(audioEngine: AVAudioEngine, deviceID: AudioDeviceID) throws {
        var deviceID = deviceID
        let propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // Set the output device
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            propertySize,
            &deviceID
        )
        
        if status != noErr {
            throw NSError(domain: "AudioLevelMonitor", code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "Failed to set output device"
            ])
        }
    }
    
    private nonisolated func processAudioBuffer(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        
        guard frameLength > 0 else { return }
        
        var leftLevel: Float = 0.0
        var rightLevel: Float = 0.0
        
        // Calculate RMS levels for each channel
        if channelCount >= 1 {
            let leftChannel = channelData[0]
            var sum: Float = 0.0
            for i in 0..<frameLength {
                let sample = leftChannel[i]
                sum += sample * sample
            }
            leftLevel = sqrt(sum / Float(frameLength))
        }
        
        if channelCount >= 2 {
            let rightChannel = channelData[1]
            var sum: Float = 0.0
            for i in 0..<frameLength {
                let sample = rightChannel[i]
                sum += sample * sample
            }
            rightLevel = sqrt(sum / Float(frameLength))
        } else {
            // Mono signal - use left level for both channels
            rightLevel = leftLevel
        }
        
        // Convert to dB and clamp to reasonable range (-60dB to 0dB)
        let leftDB = max(-60.0, 20.0 * log10(max(leftLevel, 0.000001)))
        let rightDB = max(-60.0, 20.0 * log10(max(rightLevel, 0.000001)))
        
        // Normalize to 0-1 range (0 = -60dB, 1 = 0dB)
        let normalizedLeft = (leftDB + 60.0) / 60.0
        let normalizedRight = (rightDB + 60.0) / 60.0
        
        // Update levels on main thread safely
        Task { @MainActor in
            updateLevels(left: normalizedLeft, right: normalizedRight)
        }
    }
    
    @MainActor
    private func updateLevels(left: Float, right: Float) {
        // Apply smoothing
        leftLevelSmoothed = leftLevelSmoothed * smoothingFactor + left * (1.0 - smoothingFactor)
        rightLevelSmoothed = rightLevelSmoothed * smoothingFactor + right * (1.0 - smoothingFactor)
        
        // Update published values
        leftChannelLevel = max(0.0, min(1.0, leftLevelSmoothed))
        rightChannelLevel = max(0.0, min(1.0, rightLevelSmoothed))
        averageLevel = (leftChannelLevel + rightChannelLevel) / 2.0
        peakLevel = max(leftChannelLevel, rightChannelLevel)
    }
    
    private func startLevelUpdateTimer() {
        // Ensure timer runs on main thread
        DispatchQueue.main.async { [weak self] in
            self?.levelUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                // Timer just ensures regular UI updates
                // The actual level processing happens in the audio callback
            }
        }
    }
}
