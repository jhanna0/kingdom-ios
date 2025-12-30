//
//  MusicService.swift
//  KingdomApp
//
//  Created by Jad Hanna on 12/30/25.
//

import AVFoundation
import SwiftUI
import Combine

/// Service to manage background music and sound effects
class MusicService: ObservableObject {
    static let shared = MusicService()
    
    @Published var isMusicEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isMusicEnabled, forKey: "musicEnabled")
            if isMusicEnabled {
                resumeMusic()
            } else {
                pauseMusic()
            }
        }
    }
    
    @Published var isSoundEffectsEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isSoundEffectsEnabled, forKey: "soundEffectsEnabled")
        }
    }
    
    private var backgroundMusicPlayer: AVAudioPlayer?
    private var soundEffectPlayers: [String: AVAudioPlayer] = [:]
    
    init() {
        // Load user preferences
        isMusicEnabled = UserDefaults.standard.object(forKey: "musicEnabled") as? Bool ?? true
        isSoundEffectsEnabled = UserDefaults.standard.object(forKey: "soundEffectsEnabled") as? Bool ?? true
        
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            // Configure audio session to play in background and mix with other audio
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    /// Start playing background music
    func playBackgroundMusic(filename: String, volume: Float = 0.3) {
        guard isMusicEnabled else { return }
        
        // Stop current music if playing
        backgroundMusicPlayer?.stop()
        
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil) else {
            print("Could not find music file: \(filename)")
            return
        }
        
        do {
            backgroundMusicPlayer = try AVAudioPlayer(contentsOf: url)
            backgroundMusicPlayer?.numberOfLoops = -1 // Loop indefinitely
            backgroundMusicPlayer?.volume = volume
            backgroundMusicPlayer?.prepareToPlay()
            backgroundMusicPlayer?.play()
            print("Started playing background music: \(filename)")
        } catch {
            print("Failed to play background music: \(error)")
        }
    }
    
    /// Pause the background music
    func pauseMusic() {
        backgroundMusicPlayer?.pause()
    }
    
    /// Resume the background music
    func resumeMusic() {
        guard isMusicEnabled else { return }
        backgroundMusicPlayer?.play()
    }
    
    /// Stop the background music
    func stopMusic() {
        backgroundMusicPlayer?.stop()
        backgroundMusicPlayer = nil
    }
    
    /// Set music volume (0.0 to 1.0)
    func setMusicVolume(_ volume: Float) {
        backgroundMusicPlayer?.volume = min(max(volume, 0.0), 1.0)
    }
    
    /// Play a sound effect
    func playSoundEffect(filename: String, volume: Float = 0.5) {
        guard isSoundEffectsEnabled else { return }
        
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil) else {
            print("Could not find sound effect: \(filename)")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = volume
            player.prepareToPlay()
            player.play()
            
            // Store player to prevent it from being deallocated
            soundEffectPlayers[filename] = player
            
            // Remove player after it finishes
            DispatchQueue.main.asyncAfter(deadline: .now() + player.duration + 0.1) { [weak self] in
                self?.soundEffectPlayers.removeValue(forKey: filename)
            }
        } catch {
            print("Failed to play sound effect: \(error)")
        }
    }
    
    /// Fade out music over duration (in seconds)
    func fadeOut(duration: TimeInterval = 1.0) {
        guard let player = backgroundMusicPlayer else { return }
        
        let steps = 20
        let volumeDecrement = player.volume / Float(steps)
        let timeInterval = duration / Double(steps)
        
        var currentStep = 0
        Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { timer in
            currentStep += 1
            player.volume -= volumeDecrement
            
            if currentStep >= steps {
                timer.invalidate()
                player.stop()
            }
        }
    }
    
    /// Fade in music over duration (in seconds)
    func fadeIn(targetVolume: Float = 0.3, duration: TimeInterval = 1.0) {
        guard let player = backgroundMusicPlayer, isMusicEnabled else { return }
        
        player.volume = 0.0
        player.play()
        
        let steps = 20
        let volumeIncrement = targetVolume / Float(steps)
        let timeInterval = duration / Double(steps)
        
        var currentStep = 0
        Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { timer in
            currentStep += 1
            player.volume += volumeIncrement
            
            if currentStep >= steps {
                timer.invalidate()
                player.volume = targetVolume
            }
        }
    }
}

