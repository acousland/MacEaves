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
    // Audio levels for each channel (stereo) - stored as dB values (-60 to 0)
    @Published public var leftChannelLevel: Float = -60.0
    @Published public var rightChannelLevel: Float = -60.0
    @Published public var averageLevel: Float = -60.0
    @Published public var peakLevel: Float = -60.0
    
    // Monitoring state
    @Published public var isMonitoring: Bool = false
    @Published public var selectedDevice: AudioDevice?
    @Published public var isMonitoringOutput: Bool = false
    
    // Error handling
    @Published public var lastError: String?
    
    private var audioEngine: AVAudioEngine?
    private var audioUnit: AudioUnit?
    private var levelUpdateTimer: Timer?
    private var engineObserver: NSObjectProtocol?
    private var hasTapInstalled: Bool = false
    
    // Audio level smoothing - store as dB values
    private var leftLevelSmoothed: Float = -60.0
    private var rightLevelSmoothed: Float = -60.0
    private var peakLevelHold: Float = -60.0
    private var peakHoldCounter: Int = 0
    private let peakHoldTime: Int = 20 // Hold peak for ~1 second at 50Hz update rate
    private let smoothingFactor: Float = 0.8
    
    public init() {}
    
    public func startMonitoring(device: AudioDevice?, isOutput: Bool = false) {
        Task { @MainActor in
            print("🎚️ Starting audio level monitoring...")
            print("📱 Device: \(device?.name ?? "Default")")
            print("🔊 Is Output: \(isOutput)")
            
            // Stop any existing monitoring synchronously to avoid race conditions
            stopMonitoringInternal()
            
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
        Task { @MainActor in
            stopMonitoringInternal()
        }
    }
    
    @MainActor
    private func stopMonitoringInternal() {
        print("🛑 Stopping audio level monitoring...")
        
        // Stop timer first
        levelUpdateTimer?.invalidate()
        levelUpdateTimer = nil
        
        // Remove notification observer
        if let observer = engineObserver {
            NotificationCenter.default.removeObserver(observer)
            engineObserver = nil
        }
        
        // Stop audio engine and remove tap safely
        if let audioEngine = audioEngine {
            // Only try to remove tap if we actually installed one and engine is running
            if hasTapInstalled {
                do {
                    print("🔧 Removing audio tap...")
                    if audioEngine.isRunning {
                        audioEngine.inputNode.removeTap(onBus: 0)
                    }
                    hasTapInstalled = false
                    print("✅ Audio tap removed")
                } catch {
                    print("⚠️ Failed to remove tap: \(error)")
                    hasTapInstalled = false // Reset flag even if removal failed
                }
            }
            
            // Stop the engine on the main thread to avoid threading violations
            if audioEngine.isRunning {
                audioEngine.stop()
                print("🛑 Audio engine stopped")
            }
        }
        
        // Clear references on main thread
        audioEngine = nil
        audioUnit = nil
        isMonitoring = false
        hasTapInstalled = false
        
        // Reset levels
        leftChannelLevel = 0.0
        rightChannelLevel = 0.0
        averageLevel = 0.0
        peakLevel = 0.0
        
        print("✅ Audio monitoring stopped")
    }
    
    @MainActor
    private func handleEngineConfigurationChange() {
        print("🔄 Handling audio engine configuration change...")
        print("🔍 Engine running: \(audioEngine?.isRunning ?? false)")
        
        // If the engine stopped running, update our monitoring state
        if let engine = audioEngine, !engine.isRunning {
            print("⚠️ Audio engine stopped unexpectedly")
            isMonitoring = false
            lastError = "Audio engine stopped unexpectedly. This can happen when the audio device is disconnected or the system audio configuration changes."
        }
    }
    
    @MainActor
    private func startInputMonitoring(device: AudioDevice?) throws {
        let audioEngine = AVAudioEngine()
        
        // Configure input device if specified
        if let device = device {
            print("🎤 Configuring input device: \(device.name)")
            try configureInputDevice(audioEngine: audioEngine, deviceID: device.id)
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        print("🎤 Input format: \(recordingFormat)")
        print("📊 Sample rate: \(recordingFormat.sampleRate), Channels: \(recordingFormat.channelCount)")
        
        // Install tap with weak self to avoid retain cycles
        // The audio callback runs on a background thread, so we need @Sendable and nonisolated access
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { @Sendable [weak self] buffer, time in
            self?.processAudioBuffer(buffer: buffer)
        }
        hasTapInstalled = true
        
        print("🎧 Preparing audio engine...")
        audioEngine.prepare()
        
        print("🎧 Starting audio engine...")
        try audioEngine.start()
        
        print("🎧 Audio engine started successfully")
        
        // Set up observer for engine configuration changes
        engineObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: audioEngine,
            queue: .main
        ) { [weak self] _ in
            print("⚠️ Audio engine configuration changed")
            Task { @MainActor in
                self?.handleEngineConfigurationChange()
            }
        }
        
        // Set the engine reference only after successful start
        self.audioEngine = audioEngine
    }
    
    @MainActor
    private func startOutputMonitoring(device: AudioDevice?) throws {
        // For output monitoring, we need to tap into the system output
        // This is more complex and requires specific configuration
        let audioEngine = AVAudioEngine()
        
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
        
        // Install tap with weak self to avoid retain cycles
        // The audio callback runs on a background thread, so we need @Sendable and nonisolated access
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { @Sendable [weak self] buffer, time in
            self?.processAudioBuffer(buffer: buffer)
        }
        hasTapInstalled = true
        
        print("🎧 Preparing output audio engine...")
        audioEngine.prepare()
        
        print("🎧 Starting output audio engine...")
        try audioEngine.start()
        
        print("🎧 Output audio engine started successfully")
        
        // Set up observer for engine configuration changes
        engineObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: audioEngine,
            queue: .main
        ) { [weak self] _ in
            print("⚠️ Output audio engine configuration changed")
            Task { @MainActor in
                self?.handleEngineConfigurationChange()
            }
        }
        
        // Set the engine reference only after successful start
        self.audioEngine = audioEngine
    }
    
    @MainActor
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
    
    @MainActor
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
        
        guard frameLength > 0 && channelCount > 0 else { return }
        
        var leftLevel: Float = 0.0
        var rightLevel: Float = 0.0
        
        // Calculate RMS levels for each channel safely
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
        
        // Update levels on main thread safely with error handling
        Task { @MainActor [weak self] in
            self?.updateLevels(left: leftDB, right: rightDB)
        }
    }
    
    @MainActor
    private func updateLevels(left: Float, right: Float) {
        // Apply smoothing to dB values
        leftLevelSmoothed = leftLevelSmoothed * smoothingFactor + left * (1.0 - smoothingFactor)
        rightLevelSmoothed = rightLevelSmoothed * smoothingFactor + right * (1.0 - smoothingFactor)
        
        // Update published values (keep as dB)
        leftChannelLevel = max(-60.0, min(0.0, leftLevelSmoothed))
        rightChannelLevel = max(-60.0, min(0.0, rightLevelSmoothed))
        averageLevel = (leftChannelLevel + rightChannelLevel) / 2.0
        
        // Update peak level with hold
        let currentPeak = max(leftChannelLevel, rightChannelLevel)
        if currentPeak > peakLevelHold {
            peakLevelHold = currentPeak
            peakHoldCounter = peakHoldTime
        } else if peakHoldCounter > 0 {
            peakHoldCounter -= 1
        } else {
            // Slowly decay peak when not held
            peakLevelHold = max(currentPeak, peakLevelHold - 0.5)
        }
        
        peakLevel = peakLevelHold
    }
    
    private func startLevelUpdateTimer() {
        // Ensure we're on the main thread and timer runs on main thread
        Task { @MainActor in
            print("⏰ Starting level update timer...")
            levelUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                // Timer just ensures regular UI updates
                // The actual level processing happens in the audio callback
            }
            print("✅ Level update timer started")
        }
    }
}
