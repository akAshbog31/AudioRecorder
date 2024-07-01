//
//  AudioRecorder.swift
//  SwiftBoilerPlate
//
//  Created by AKASH BOGHANI on 01/07/24.
//

import Foundation
import AVFoundation

// Protocol to notify about audio recorder events
protocol AudioRecorderDelegate: AnyObject {
    func audioRecorderDidFinishRecording(_ recorder: AudioRecorder, successfully flag: Bool)
    func audioRecorderDidUpdateProgress(_ recorder: AudioRecorder, currentTime: TimeInterval)
    func audioRecorderDidEncounterError(_ recorder: AudioRecorder, error: Error)
}

class AudioRecorder: NSObject {
    // MARK: - Properties
    private var audioRecorder: AVAudioRecorder? // AVAudioRecorder instance
    private var timer: Timer? // Timer to track recording progress
    private let queue = DispatchQueue(label: "com.example.AudioRecorder") // Serial queue for thread safety
    
    var hasBeenPaused = false // Flag to track pause state
    weak var delegate: AudioRecorderDelegate? // Delegate to notify about recorder events

    // Computed property to check if recording is in progress
    var isRecording: Bool {
        return audioRecorder?.isRecording ?? false
    }
    
    // Computed property to check if audio is loaded for recording
    var isAudioLoaded: Bool {
        return audioRecorder != nil
    }
    
    // MARK: - Functions
    // Function to load audio for recording with specified settings
    public func loadAudio(url: URL, settings: [String: Any]) {
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.prepareToRecord()

            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)

        } catch {
            delegate?.audioRecorderDidEncounterError(self, error: error)
            print("Error loading audio: \(error.localizedDescription)")
        }
    }

    // Function to start recording audio
    public func startRecording() {
        guard let audioRecorder = audioRecorder else { return }
        
        queue.sync {
            audioRecorder.record()
            startTimer()
        }
    }

    // Function to pause recording audio
    public func pauseRecording() {
        guard let audioRecorder = audioRecorder else { return }

        queue.sync {
            if audioRecorder.isRecording {
                audioRecorder.pause()
                hasBeenPaused = true
            } else {
                hasBeenPaused = false
            }
            stopTimer()
        }
    }

    // Function to stop recording audio
    public func stopRecording() {
        guard let audioRecorder = audioRecorder else { return }

        queue.sync {
            audioRecorder.stop()
            stopTimer()
        }
    }

    // Function to get the current recording time
    public func getCurrentTime() -> TimeInterval? {
        return queue.sync {
            return audioRecorder?.currentTime
        }
    }

    // Function to start the progress timer
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateProgress), userInfo: nil, repeats: true)
    }

    // Function to stop the progress timer
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // Function called by the timer to update the recording progress
    @objc private func updateProgress() {
        guard let audioRecorder = audioRecorder else { return }
        let currentTime = audioRecorder.currentTime

        delegate?.audioRecorderDidUpdateProgress(self, currentTime: currentTime)
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioRecorder: AVAudioRecorderDelegate {
    // Delegate method called when recording finishes
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        delegate?.audioRecorderDidFinishRecording(self, successfully: flag)
        stopTimer()
    }

    // Delegate method called when an encoding error occurs
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            delegate?.audioRecorderDidEncounterError(self, error: error)
            print("Encoding Error: \(error.localizedDescription)")
        }
    }
}
