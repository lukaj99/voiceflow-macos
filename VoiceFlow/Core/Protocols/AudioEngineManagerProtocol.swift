import Foundation
import Combine
import AVFoundation

/// Protocol defining the interface for audio engine management
@MainActor
public protocol AudioEngineManagerProtocol: AnyObject, Sendable {
    
    // MARK: - Properties
    
    var isRecording: Bool { get }
    var isPaused: Bool { get }
    var audioLevel: Double { get }
    var audioLevelPublisher: AnyPublisher<Double, Never> { get }
    
    // MARK: - Audio Control
    
    func startRecording() async throws
    func stopRecording() async
    func pauseRecording() async
    func resumeRecording() async
    
    // MARK: - Configuration
    
    func configureAudioSession() async throws
    func setInputDevice(_ device: AVAudioSessionPortDescription?) async throws
    func getAvailableInputDevices() -> [AVAudioSessionPortDescription]
    
    // MARK: - Audio Processing
    
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) async
    func setNoiseSuppressionEnabled(_ enabled: Bool) async
    func setEchoCancellationEnabled(_ enabled: Bool) async
}