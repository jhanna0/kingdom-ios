import Foundation
import MapKit
import SwiftUI
import Combine
import CoreLocation

@MainActor
class MapViewModel: ObservableObject {
    @Published var kingdoms: [Kingdom] = []
    @Published var cameraPosition: MapCameraPosition
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var isLoading: Bool = false
    @Published var loadingStatus: String = "Waiting for location..."
    @Published var errorMessage: String?
    @Published var player: Player
    @Published var currentKingdomInside: Kingdom?  // Kingdom player is currently inside
    
    // Configuration
    var loadRadiusMiles: Double = 10  // How many miles around user to load cities
    
    private var hasInitializedLocation = false
    
    init() {
        // Initialize player
        self.player = Player()
        
        // Start with default location - will be replaced when user location arrives
        let center = SampleData.defaultCenter
        self.cameraPosition = .region(
            MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
            )
        )
        
        // NO FAKE DATA - wait for real location and real data
        print("📱 MapViewModel initialized")
    }
    
    func updateUserLocation(_ location: CLLocationCoordinate2D) {
        userLocation = location
        
        // Check which kingdom user is inside
        checkKingdomLocation(location)
        
        // Only initialize once
        if !hasInitializedLocation {
            hasInitializedLocation = true
            print("🎯 First location received - loading REAL town data")
            
            // Center map on user's location with appropriate zoom for town view
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: location,
                    span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
                )
            )
            
            // Load REAL towns
            loadRealTowns(around: location)
        }
    }
    
    /// Check which kingdom the user is currently inside
    private func checkKingdomLocation(_ location: CLLocationCoordinate2D) {
        let previousKingdom = currentKingdomInside
        
        // Find which kingdom contains the user's location
        currentKingdomInside = kingdoms.first { kingdom in
            kingdom.contains(location)
        }
        
        // Log when entering/leaving kingdoms
        if let current = currentKingdomInside, previousKingdom?.id != current.id {
            print("🏰 Entered \(current.name)")
        } else if previousKingdom != nil && currentKingdomInside == nil {
            print("🚪 Left \(previousKingdom!.name)")
        }
    }
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLoc = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLoc = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLoc.distance(from: toLoc)  // Returns meters
    }
    
    /// Load real town data - NO FALLBACKS
    func loadRealTowns(around location: CLLocationCoordinate2D) {
        guard !isLoading else { return }
        
        isLoading = true
        loadingStatus = "Finding towns near you..."
        errorMessage = nil
        
        Task {
            loadingStatus = "Querying OpenStreetMap..."
            
            let foundKingdoms = await SampleData.loadRealTowns(around: location, radiusMiles: loadRadiusMiles)
            
            if foundKingdoms.isEmpty {
                loadingStatus = "No towns found"
                errorMessage = "Could not load town boundaries. Please check your internet connection and try again."
                print("❌ No real towns found!")
            } else {
                loadingStatus = "Loaded \(foundKingdoms.count) towns"
                errorMessage = nil
                kingdoms = foundKingdoms
                print("✅ Loaded \(foundKingdoms.count) towns")
                
                // Adjust map to show all kingdoms
                adjustMapToShowKingdoms()
                
                // Re-check location now that kingdoms are loaded
                if let currentLocation = userLocation {
                    checkKingdomLocation(currentLocation)
                }
            }
            
            isLoading = false
        }
    }
    
    /// Refresh kingdoms - try again with real data
    func refreshKingdoms() {
        if let location = userLocation {
            loadRealTowns(around: location)
        } else {
            errorMessage = "Location not available. Please enable location services."
        }
    }
    
    /// Adjust the map camera to show all loaded kingdoms
    private func adjustMapToShowKingdoms() {
        guard !kingdoms.isEmpty else { return }
        
        // Calculate bounding box of all kingdoms
        var minLat = Double.greatestFiniteMagnitude
        var maxLat = -Double.greatestFiniteMagnitude
        var minLon = Double.greatestFiniteMagnitude
        var maxLon = -Double.greatestFiniteMagnitude
        
        for kingdom in kingdoms {
            for coord in kingdom.territory.boundary {
                minLat = min(minLat, coord.latitude)
                maxLat = max(maxLat, coord.latitude)
                minLon = min(minLon, coord.longitude)
                maxLon = max(maxLon, coord.longitude)
            }
        }
        
        // Add padding
        let padding = 0.02
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) + padding,
            longitudeDelta: (maxLon - minLon) + padding
        )
        
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }
    
    // MARK: - Check-in & Claiming
    
    /// Check in to the current kingdom
    func checkIn() -> Bool {
        guard let kingdom = currentKingdomInside,
              let location = userLocation else {
            print("❌ Cannot check in - not inside a kingdom")
            return false
        }
        
        player.checkIn(to: kingdom.name, at: location)
        
        // Update kingdom's checked-in count
        if let index = kingdoms.firstIndex(where: { $0.id == kingdom.id }) {
            kingdoms[index].checkedInPlayers += 1
        }
        
        return true
    }
    
    /// Claim the current kingdom (if unclaimed)
    func claimKingdom() -> Bool {
        guard let kingdom = currentKingdomInside else {
            print("❌ Cannot claim - not inside a kingdom")
            return false
        }
        
        guard kingdom.isUnclaimed else {
            print("❌ Cannot claim - kingdom already has a ruler")
            return false
        }
        
        guard player.isCheckedIn() else {
            print("❌ Cannot claim - must check in first")
            return false
        }
        
        // Claim it!
        if let index = kingdoms.firstIndex(where: { $0.id == kingdom.id }) {
            kingdoms[index].setRuler(playerId: player.playerId, playerName: player.name)
            player.claimKingdom(kingdom.name)
            
            // Update currentKingdomInside to reflect the change
            currentKingdomInside = kingdoms[index]
            
            print("👑 Claimed \(kingdom.name)")
            return true
        }
        
        return false
    }
}
