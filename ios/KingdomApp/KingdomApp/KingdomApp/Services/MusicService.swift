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
    
    @Published var isInWarMode: Bool = false  // Track if currently playing war music
    
    private var backgroundMusicPlayer: AVAudioPlayer?
    private var nextMusicPlayer: AVAudioPlayer?  // For crossfading
    private var soundEffectPlayers: [String: AVAudioPlayer] = [:]
    private var currentFilename: String?
    private var fadeTimer: Timer?
    
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
        
        // Don't restart if already playing this file
        if currentFilename == filename && backgroundMusicPlayer?.isPlaying == true {
            return
        }
        
        // Stop current music if playing
        backgroundMusicPlayer?.stop()
        fadeTimer?.invalidate()
        
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
            currentFilename = filename
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
    
    /// Transition from current music to new music - fade out completely, then fade in new track
    func crossfadeToMusic(filename: String, targetVolume: Float = 0.3, duration: TimeInterval = 2.0) {
        guard isMusicEnabled else { return }
        
        // Don't transition if already playing this file
        if currentFilename == filename && backgroundMusicPlayer?.isPlaying == true {
            return
        }
        
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil) else {
            print("Could not find music file: \(filename)")
            return
        }
        
        // Prepare the next track (but don't play yet)
        do {
            nextMusicPlayer = try AVAudioPlayer(contentsOf: url)
            nextMusicPlayer?.numberOfLoops = -1
            nextMusicPlayer?.volume = 0.0
            nextMusicPlayer?.prepareToPlay()
            
            // PHASE 1: Fade out old track completely
            let oldPlayer = backgroundMusicPlayer
            let startVolume = oldPlayer?.volume ?? 0.0
            
            let fadeOutDuration = duration / 2.0  // Half the time for fade out
            let steps = 60
            let timeInterval = fadeOutDuration / Double(steps)
            
            fadeTimer?.invalidate()
            var currentStep = 0
            
            fadeTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { [weak self] timer in
                currentStep += 1
                let progress = Float(currentStep) / Float(steps)
                
                // Fade out old track with gentle curve
                if let old = oldPlayer {
                    old.volume = startVolume * (1.0 - progress)
                }
                
                if currentStep >= steps {
                    timer.invalidate()
                    oldPlayer?.stop()
                    self?.fadeTimer = nil
                    
                    // PHASE 2: Now fade in the new track
                    self?.fadeInNewTrack(targetVolume: targetVolume, duration: duration / 2.0, filename: filename)
                }
            }
        } catch {
            print("Failed to transition music: \(error)")
        }
    }
    
    /// Fade in the new track after old track has faded out
    private func fadeInNewTrack(targetVolume: Float, duration: TimeInterval, filename: String) {
        guard let newPlayer = nextMusicPlayer else { return }
        
        // Start playing at 0 volume
        newPlayer.volume = 0.0
        newPlayer.play()
        
        let steps = 60
        let timeInterval = duration / Double(steps)
        var currentStep = 0
        
        fadeTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { [weak self] timer in
            currentStep += 1
            let progress = Float(currentStep) / Float(steps)
            
            // Fade in with gentle curve
            newPlayer.volume = targetVolume * progress
            
            if currentStep >= steps {
                timer.invalidate()
                newPlayer.volume = targetVolume
                self?.backgroundMusicPlayer = newPlayer
                self?.nextMusicPlayer = nil
                self?.currentFilename = filename
                self?.fadeTimer = nil
                print("Transitioned to: \(filename)")
            }
        }
    }
    
    /// Transition to war music
    func transitionToWarMusic() {
        guard !isInWarMode else { return }
        isInWarMode = true
        crossfadeToMusic(filename: "war_music.mp3", targetVolume: 0.35, duration: 8.0)
        print("🎵 Transitioning to WAR MUSIC")
    }
    
    /// Transition back to peaceful music
    func transitionToPeacefulMusic() {
        guard isInWarMode else { return }
        isInWarMode = false
        crossfadeToMusic(filename: "ambient_background_full.mp3", targetVolume: 0.25, duration: 10.0)
        print("🎵 Transitioning to PEACEFUL MUSIC")
    }
    
    /// Fade out music over duration (in seconds)
    func fadeOut(duration: TimeInterval = 1.0) {
        guard let player = backgroundMusicPlayer else { return }
        
        fadeTimer?.invalidate()
        let steps = 20
        let volumeDecrement = player.volume / Float(steps)
        let timeInterval = duration / Double(steps)
        
        var currentStep = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { [weak self] timer in
            currentStep += 1
            player.volume -= volumeDecrement
            
            if currentStep >= steps {
                timer.invalidate()
                player.stop()
                self?.fadeTimer = nil
            }
        }
    }
    
    /// Fade in music over duration (in seconds)
    func fadeIn(targetVolume: Float = 0.3, duration: TimeInterval = 1.0) {
        guard let player = backgroundMusicPlayer, isMusicEnabled else { return }
        
        player.volume = 0.0
        player.play()
        
        fadeTimer?.invalidate()
        let steps = 20
        let volumeIncrement = targetVolume / Float(steps)
        let timeInterval = duration / Double(steps)
        
        var currentStep = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { [weak self] timer in
            currentStep += 1
            player.volume += volumeIncrement
            
            if currentStep >= steps {
                timer.invalidate()
                player.volume = targetVolume
                self?.fadeTimer = nil
            }
        }
    }
}

