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
    @Published var loadingStatus: String = "Awakening the royal cartographers..."
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
        loadingStatus = "Scouts dispatched to survey the realm..."
        errorMessage = nil
        
        Task {
            loadingStatus = "Digging through the maps..."
            
            let foundKingdoms = await SampleData.loadRealTowns(around: location, radiusMiles: loadRadiusMiles)
            
            if foundKingdoms.isEmpty {
                loadingStatus = "The realm lies shrouded in fog..."
                errorMessage = "The royal mapmakers could not chart these lands. Ensure thy connection to the realm is strong and try again."
                print("❌ No real towns found!")
                isLoading = false
            } else {
                // Set kingdoms immediately
                kingdoms = foundKingdoms
                print("✅ Loaded \(foundKingdoms.count) towns")
                
                // Re-check location now that kingdoms are loaded
                if let currentLocation = userLocation {
                    checkKingdomLocation(currentLocation)
                }
                
                // Done loading
                isLoading = false
            }
        }
    }
    
    /// Refresh kingdoms - try again with real data
    func refreshKingdoms() {
        if let location = userLocation {
            loadRealTowns(around: location)
        } else {
            errorMessage = "The royal astronomers cannot find you! Grant them permission to track the stars."
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
    
    // MARK: - Ruler Actions
    
    /// Upgrade a building (uses kingdom treasury, not player gold)
    func upgradeBuilding(kingdom: Kingdom, buildingType: BuildingType, cost: Int) {
        guard let index = kingdoms.firstIndex(where: { $0.id == kingdom.id }) else {
            print("❌ Kingdom not found")
            return
        }
        
        // Check if ruler owns this kingdom
        guard kingdoms[index].rulerId == player.playerId else {
            print("❌ You don't rule this kingdom")
            return
        }
        
        // Check if kingdom has enough treasury gold
        guard kingdoms[index].treasuryGold >= cost else {
            print("❌ Kingdom treasury insufficient: need \(cost), have \(kingdoms[index].treasuryGold)")
            return
        }
        
        // Deduct from kingdom treasury
        kingdoms[index].treasuryGold -= cost
        
        // Upgrade the building
        switch buildingType {
        case .walls:
            if kingdoms[index].wallLevel < 5 {
                kingdoms[index].wallLevel += 1
                print("🏰 Upgraded walls to level \(kingdoms[index].wallLevel)")
            }
        case .vault:
            if kingdoms[index].vaultLevel < 5 {
                kingdoms[index].vaultLevel += 1
                print("🔒 Upgraded vault to level \(kingdoms[index].vaultLevel)")
            }
        case .mine:
            if kingdoms[index].mineLevel < 5 {
                kingdoms[index].mineLevel += 1
                print("⛏️ Upgraded mine to level \(kingdoms[index].mineLevel) (+income)")
            }
        case .market:
            if kingdoms[index].marketLevel < 5 {
                kingdoms[index].marketLevel += 1
                print("🏪 Upgraded market to level \(kingdoms[index].marketLevel) (+income)")
            }
        }
        
        // Update currentKingdomInside if it's the same kingdom
        if currentKingdomInside?.id == kingdom.id {
            currentKingdomInside = kingdoms[index]
        }
    }
    
    /// Collect passive income for all kingdoms (goes to city treasury)
    /// This should be called periodically (e.g., when app opens, when viewing kingdom)
    func collectKingdomIncome(for kingdom: Kingdom) {
        guard let index = kingdoms.firstIndex(where: { $0.id == kingdom.id }) else {
            return
        }
        
        // Collect income into the kingdom's treasury
        let incomeEarned = kingdoms[index].pendingIncome
        if incomeEarned > 0 {
            kingdoms[index].collectIncome()
            print("💰 \(kingdom.name) collected \(incomeEarned) gold (now: \(kingdoms[index].treasuryGold)g)")
            
            // Update currentKingdomInside if it's the same kingdom
            if currentKingdomInside?.id == kingdom.id {
                currentKingdomInside = kingdoms[index]
            }
        }
    }
    
    /// Collect income for all kingdoms the player rules
    func collectAllRuledKingdomsIncome() {
        let ruledKingdoms = kingdoms.filter { kingdom in
            player.fiefsRuled.contains(kingdom.name)
        }
        
        var totalCollected = 0
        for kingdom in ruledKingdoms {
            let pendingIncome = kingdom.pendingIncome
            collectKingdomIncome(for: kingdom)
            totalCollected += pendingIncome
        }
        
        if totalCollected > 0 {
            print("👑 Collected \(totalCollected) gold across \(ruledKingdoms.count) kingdoms")
        }
    }
    
    /// Auto-collect income when viewing a kingdom (convenience)
    func autoCollectIncomeForKingdom(_ kingdom: Kingdom) {
        if kingdom.hasIncomeToCollect {
            collectKingdomIncome(for: kingdom)
        }
    }
}
