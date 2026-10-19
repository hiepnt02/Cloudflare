//
//  AudioService.swift
//  Quick3D
//
//  Created by Admin on 26/2/26.
//

import AVFoundation

// MARK: - AudioPlayerManager
class AudioService: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioService()
    
    private var audioPlayer: AVAudioPlayer?
    
    private override init() {
        super.init()
    }
    
    func playAlertSound() {
        guard UserSession.shared.isEnableAlertSound else { return }

        // Release previous player if exists
        audioPlayer?.stop()
        audioPlayer = nil

        activateAmbientSession()
        
        var soundURL: URL? = Bundle.main.url(forResource: "alert", withExtension: "m4a")
        
        guard let soundURL = soundURL else {
            print("Could not find alert.m4a file in any expected location")
            // Debug: List all bundle URLs for files with .m4a extension
            if let resourcePath = Bundle.main.resourcePath {
                print("Bundle resource path: \(resourcePath)")
            }
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.delegate = self
            audioPlayer?.play()
        } catch {
            print("Error playing alert sound: \(error)")
        }
    }
    
    // .ambient tôn trọng công tắc im lặng; .mixWithOthers giữ nguyên nhạc/cuộc gọi đang phát
    private func activateAmbientSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Error configuring audio session: \(error)")
        }
    }

    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Clean up resources when playback finishes
        audioPlayer = nil
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        // Clean up resources on error
        audioPlayer = nil
        if let error = error {
            print("Audio player decode error: \(error)")
        }
    }
}
