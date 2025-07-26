/*
 See LICENSE folder for this sample’s licensing information.
 */

import Foundation
import AVFoundation
import Speech
import Observation
import CoreAudio

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

/// A helper for transcribing speech to text using SFSpeechRecognizer and AVAudioEngine.
import AVFoundation
import Foundation
import Speech
import SwiftUI
import CoreAudio

/**
 * A helper for transcribing speech to text using SFSpeechRecognizer and AVAudioEngine.
 */
@MainActor
@Observable public class SpeechRecognizer {
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
    
    @MainActor public var transcript: String = ""
        public var availableInputDevices: [AudioDevice] = []
    public var availableOutputDevices: [AudioDevice] = []
    public var selectedInputDevice: AudioDevice?
    public var selectedOutputDevice: AudioDevice?
    public var isTranscribingFromOutput: Bool = false
    
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
            transcribe(RecognizerError.nilRecognizer)
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
                
                discoverAudioDevices()
            } catch {
                transcribe(error)
            }
        }
    }
    
    public func startTranscribing() {
        transcribe()
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
    }    /**
     Begin transcribing audio.
     
     Creates a `SFSpeechRecognitionTask` that transcribes speech to text until you call `stopTranscribing()`.
     The resulting transcription is continuously written to the published `transcript` property.
     */
    private func transcribe() {
        guard let recognizer, recognizer.isAvailable else {
            self.transcribe(RecognizerError.recognizerIsUnavailable)
            return
        }
        
        do {
            let (audioEngine, request) = try prepareEngine()
            self.audioEngine = audioEngine
            self.request = request
            self.task = recognizer.recognitionTask(with: request, resultHandler: { [weak self] result, error in
                self?.recognitionHandler(audioEngine: audioEngine, result: result, error: error)
            })
        } catch {
            self.reset()
            self.transcribe(error)
        }
    }
    
    /// Reset the speech recognizer.
    private func reset() {
        task?.cancel()
        audioEngine?.stop()
        audioEngine = nil
        request = nil
        task = nil
    }
    
    private func prepareEngine() throws -> (AVAudioEngine, SFSpeechAudioBufferRecognitionRequest) {
        let audioEngine = AVAudioEngine()
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        
        // Configure audio engine based on selected device and transcription mode
        try configureAudioEngine(audioEngine)
        
        let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            request.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        return (audioEngine, request)
    }
    
    private func configureAudioEngine(_ audioEngine: AVAudioEngine) throws {
        // Get current device selections
        let selectedInput = selectedInputDevice
        let selectedOutput = selectedOutputDevice
        let transcribingFromOutput = isTranscribingFromOutput
        
        if transcribingFromOutput, let outputDevice = selectedOutput {
            // Configure for output transcription (listening to system audio)
            try configureForOutputTranscription(audioEngine, outputDevice: outputDevice)
        } else if let inputDevice = selectedInput {
            // Configure for specific input device
            try configureForInputDevice(audioEngine, inputDevice: inputDevice)
        }
        // If no device selected, use default device (system will handle)
    }
    
    private func configureForInputDevice(_ audioEngine: AVAudioEngine, inputDevice: AudioDevice) throws {
        // Set the preferred input device
        // Note: On macOS, you typically need to set this at the system level
        // For now, we'll work with the default device
        // Advanced implementation would use AudioUnit or CoreAudio to select specific devices
    }
    
    private func configureForOutputTranscription(_ audioEngine: AVAudioEngine, outputDevice: AudioDevice) throws {
        // For output transcription, we need to tap into the system's audio output
        // This is complex and may require additional permissions
        // For now, we'll note this limitation
        throw RecognizerError.audioDeviceError
    }
    
    private func recognitionHandler(audioEngine: AVAudioEngine, result: SFSpeechRecognitionResult?, error: Error?) {
        let receivedFinalResult = result?.isFinal ?? false
        let receivedError = error != nil
        
        if receivedFinalResult || receivedError {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        if let result {
            Task { @MainActor in
                transcribe(result.bestTranscription.formattedString)
            }
        } else if let error {
            Task { @MainActor in
                transcribe(error)
            }
        }
    }
    
    
    private func transcribe(_ message: String) {
        transcript = message
    }
    private func transcribe(_ error: Error) {
        var errorMessage = ""
        if let error = error as? RecognizerError {
            errorMessage += error.message
        } else {
            errorMessage += error.localizedDescription
        }
        transcript = "<< \(errorMessage) >>"
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
        AVAudioApplication.requestRecordPermission { authorized in
            continuation.resume(returning: authorized)
        }
    }
}
