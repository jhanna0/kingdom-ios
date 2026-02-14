//
//  HapticService.swift
//  KingdomApp
//
//  Centralized haptic feedback controller
//

import SwiftUI
#if canImport(UIKit)
import UIKit
import Combine
#endif

/// Service to manage haptic feedback throughout the app
class HapticService: ObservableObject {
    static let shared = HapticService()
    
    @Published var isHapticsEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isHapticsEnabled, forKey: "hapticsEnabled")
        }
    }
    
    init() {
        // Load user preference
        isHapticsEnabled = UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
    }
    
    // MARK: - Notification Feedback
    
    /// Trigger notification-style haptic feedback (success, warning, error)
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isHapticsEnabled else { return }
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(type)
        #endif
    }
    
    /// Convenience for success notification
    func success() {
        notification(.success)
    }
    
    /// Convenience for warning notification
    func warning() {
        notification(.warning)
    }
    
    /// Convenience for error notification
    func error() {
        notification(.error)
    }
    
    // MARK: - Impact Feedback
    
    /// Trigger impact-style haptic feedback
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isHapticsEnabled else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        #endif
    }
    
    /// Convenience for light impact
    func lightImpact() {
        impact(.light)
    }
    
    /// Convenience for medium impact
    func mediumImpact() {
        impact(.medium)
    }
    
    /// Convenience for heavy impact
    func heavyImpact() {
        impact(.heavy)
    }
    
    /// Convenience for soft impact
    func softImpact() {
        impact(.soft)
    }
    
    /// Convenience for rigid impact
    func rigidImpact() {
        impact(.rigid)
    }
    
    // MARK: - Selection Feedback
    
    /// Trigger selection-style haptic feedback (light tap for UI selections)
    func selection() {
        guard isHapticsEnabled else { return }
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}
