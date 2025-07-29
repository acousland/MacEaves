/*
 See LICENSE folder for this sample’s licensing information.
 */

// NOTE: All uses of self or class properties in closures, async contexts, or nonisolated settings must be performed on MainActor for data-race safety.

import Foundation
import AVFoundation
import Speech
import Observation
import CoreAudio
import Combine

public typealias AudioDeviceID = UInt32

/// Audio device information for interface picker
public struct AudioDevice: Identifiable, Hashable {
    public let id: AudioDeviceID
    public let name: String
    public let isInput: Bool
    public let isOutput: Bool
    
    public init(id: AudioDeviceID, name: String, isInput: Bool, isOutput: Bool) {
        self.id = id
        self.name = name
        self.isInput = isInput
        self.isOutput = isOutput
    }
}

/**
 * A helper for transcribing speech to text using SFSpeechRecognizer and AVAudioEngine.
 */
@MainActor
public class SpeechRecognizer: ObservableObject {
    public enum RecognizerError: Error {
        case nilRecognizer
        case notAuthorizedToRecognize
        case notPermittedToRecord
        case recognizerIsUnavailable
        case audioDeviceError
        
        public var message: String {
            switch self {
            case .nilRecognizer: return "Can't initialize speech recognizer"
            case .notAuthorizedToRecognize: return "Not authorized to recognize speech"
            case .notPermittedToRecord: return "Not permitted to record audio"
            case .recognizerIsUnavailable: return "Recognizer is unavailable"
            case .audioDeviceError: return "Audio device configuration error"
            }
        }
    }
    
    @Published public var transcript: String = ""
    @Published public var availableInputDevices: [AudioDevice] = []
    @Published public var availableOutputDevices: [AudioDevice] = []
    @Published public var selectedInputDevice: AudioDevice?
    @Published public var selectedOutputDevice: AudioDevice?
    @Published var isTranscribingFromOutput: Bool = false
    
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer: SFSpeechRecognizer?
    
    /**
     Initializes a new speech recognizer. If this is the first time you've used the class, it
     requests access to the speech recognizer and the microphone.
     */
    public init() {
        recognizer = SFSpeechRecognizer()
        guard recognizer != nil else {
            var errorMessage = ""
            let error = RecognizerError.nilRecognizer
            errorMessage += error.message
            transcript = "<< \(errorMessage) >>"
            return
        }
        
        Task {
            do {
                guard await SFSpeechRecognizer.hasAuthorizationToRecognize() else {
                    throw RecognizerError.notAuthorizedToRecognize
                }
                guard await hasPermissionToRecord() else {
                    throw RecognizerError.notPermittedToRecord
                }
                
                // Access to self properties must be on MainActor
                await MainActor.run {
                    discoverAudioDevices()
                }
            } catch {
                var errorMessage = ""
                if let error = error as? RecognizerError {
                    errorMessage += error.message
                } else {
                    errorMessage += error.localizedDescription
                }
                // Update self.transcript on MainActor
                await MainActor.run {
                    transcript = "<< \(errorMessage) >>"
                }
            }
        }
    }
    
    public func startTranscribing() {
        Task {
            // Access self inside MainActor for safety
            await transcribe()
        }
    }

    public func resetTranscript() {
        reset()
    }

    public func stopTranscribing() {
        reset()
    }

    public func selectInputDevice(_ device: AudioDevice?) {
        selectedInputDevice = device
        isTranscribingFromOutput = false
    }

    public func selectOutputDevice(_ device: AudioDevice?) {
        selectedOutputDevice = device
        if device != nil {
            isTranscribingFromOutput = true
        }
    }

    public func refreshAudioDevices() {
        discoverAudioDevices()
    }    
    /**
     Begin transcribing audio.
     
     Creates a `SFSpeechRecognitionTask` that transcribes speech to text until you call `stopTranscribing()`.
     The resulting transcription is continuously written to the published `transcript` property.
     */
    private func transcribe() async {
        guard let recognizer, recognizer.isAvailable else {
            var errorMessage = ""
            let error = RecognizerError.recognizerIsUnavailable
            errorMessage += error.message
            // Must update transcript on main actor
            await MainActor.run {
                transcript = "<< \(errorMessage) >>"
            }
            return
        }
        
        do {
            // Ensure audio engine operations happen on main thread
            let (audioEngine, request) = try await Task {
                return try prepareEngine()
            }.value
            // Update self properties on MainActor
            await MainActor.run {
                self.audioEngine = audioEngine
                self.request = request
                self.task = recognizer.recognitionTask(with: request, resultHandler: { [weak self] result, error in
                    // Because this is a completion handler, protect self access with Task @MainActor
                    self?.recognitionHandler(audioEngine: audioEngine, result: result, error: error)
                })
            }
        } catch {
            // Reset and update transcript on MainActor
            await MainActor.run {
                reset()
                var errorMessage = ""
                if let error = error as? RecognizerError {
                    errorMessage += error.message
                } else {
                    errorMessage += error.localizedDescription
                }
                transcript = "<< \(errorMessage) >>"
            }
        }
    }
    
    /// Reset the speech recognizer.
    private func reset() {
        task?.cancel()
        if let audioEngine = audioEngine {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
        request = nil
        task = nil
    }
    
    private func prepareEngine() throws -> (AVAudioEngine, SFSpeechAudioBufferRecognitionRequest) {
        let audioEngine = AVAudioEngine()
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        
        // Configure audio engine with default settings - no audio session needed on macOS
        let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { @Sendable (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            // Audio buffer callback - this runs on audio thread, just append buffer
            // This is thread-safe and doesn't require main actor isolation
            request.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        return (audioEngine, request)
    }
    
    private func recognitionHandler(audioEngine: AVAudioEngine, result: SFSpeechRecognitionResult?, error: Error?) {
        let receivedFinalResult = result?.isFinal ?? false
        let receivedError = error != nil
        
        if receivedFinalResult || receivedError {
            // CRITICAL FIX: Move audio engine operations to main thread to prevent threading violations
            Task { @MainActor [weak self] in
                audioEngine.stop()
                audioEngine.inputNode.removeTap(onBus: 0)
                // No direct self mutation here; handled below
            }
        }
        
        if let result {
            let transcriptionText = result.bestTranscription.formattedString
            // Update transcript safely on MainActor
            Task { @MainActor [weak self] in
                self?.transcript = transcriptionText
            }
        } else if let error {
            var errorMessage = ""
            if let error = error as? RecognizerError {
                errorMessage += error.message
            } else {
                errorMessage += error.localizedDescription
            }
            // Update transcript safely on MainActor
            Task { @MainActor [weak self] in
                self?.transcript = "<< \(errorMessage) >>"
            }
        }
    }
    
    /// Discover available audio devices
    private func discoverAudioDevices() {
        // Clear existing devices
        availableInputDevices.removeAll()
        availableOutputDevices.removeAll()
        
        // Get all audio devices using Core Audio
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
        
        guard status == noErr else {
            return
        }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        let deviceIDs = UnsafeMutablePointer<AudioDeviceID>.allocate(capacity: deviceCount)
        defer { deviceIDs.deallocate() }
        
        let getDevicesStatus = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, deviceIDs)
        
        guard getDevicesStatus == noErr else {
            return
        }
        
        for i in 0..<deviceCount {
            let deviceID = deviceIDs[i]
            
            // Get device name
            if let deviceName = getDeviceName(deviceID: deviceID) {
                let isInput = hasInputChannels(deviceID: deviceID)
                let isOutput = hasOutputChannels(deviceID: deviceID)
                
                // Only include devices that have input or output channels
                if isInput || isOutput {
                    let device = AudioDevice(id: deviceID, name: deviceName, isInput: isInput, isOutput: isOutput)
                    if isInput {
                        availableInputDevices.append(device)
                    }
                    if isOutput {
                        availableOutputDevices.append(device)
                    }
                }
            }
        }
        
        // Set default devices if none selected
        if selectedInputDevice == nil {
            selectedInputDevice = availableInputDevices.first
        }
        if selectedOutputDevice == nil {
            selectedOutputDevice = availableOutputDevices.first
        }
    }
    
    private func getDeviceName(deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
        guard status == noErr else { return nil }
        
        let cfStringRef = UnsafeMutablePointer<CFString?>.allocate(capacity: 1)
        defer { cfStringRef.deallocate() }
        
        status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, cfStringRef)
        guard status == noErr, let cfString = cfStringRef.pointee else { return nil }
        
        return cfString as String
    }
    
    private func hasInputChannels(deviceID: AudioDeviceID) -> Bool {
        return getChannelCount(deviceID: deviceID, scope: kAudioDevicePropertyScopeInput) > 0
    }
    
    private func hasOutputChannels(deviceID: AudioDeviceID) -> Bool {
        return getChannelCount(deviceID: deviceID, scope: kAudioDevicePropertyScopeOutput) > 0
    }
    
    private func getChannelCount(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> UInt32 {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
        guard status == noErr, dataSize > 0 else { return 0 }
        
        let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferList.deallocate() }
        
        let getDataStatus = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, bufferList)
        guard getDataStatus == noErr else { return 0 }
        
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        return buffers.reduce(0) { $0 + $1.mNumberChannels }
    }
}

extension SFSpeechRecognizer {
    static func hasAuthorizationToRecognize() async -> Bool {
        await withCheckedContinuation { continuation in
            requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

private func hasPermissionToRecord() async -> Bool {
    await withCheckedContinuation { continuation in
        AVCaptureDevice.requestAccess(for: .audio) { authorized in
            continuation.resume(returning: authorized)
        }
    }
}

