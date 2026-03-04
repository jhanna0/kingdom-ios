//
//  MapSettingsService.swift
//  KingdomApp
//
//  Centralized map display settings controller
//

import SwiftUI
import Combine

/// Service to manage map display settings throughout the app
class MapSettingsService: ObservableObject {
    static let shared = MapSettingsService()
    
    @Published var showLocationMarker: Bool = true {
        didSet {
            UserDefaults.standard.set(showLocationMarker, forKey: "showLocationMarker")
        }
    }
    
    init() {
        showLocationMarker = UserDefaults.standard.object(forKey: "showLocationMarker") as? Bool ?? true
    }
}
