import Foundation
import MapKit
import SwiftUI
import Combine
import CoreLocation

@MainActor
class MapViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var kingdoms: [Kingdom] = []
    @Published var cameraPosition: MapCameraPosition
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var isLoading: Bool = false
    @Published var loadingStatus: String = "Awakening the royal cartographers..."
    @Published var errorMessage: String?
    @Published var player: Player
    @Published var playerResources: PlayerResources  // Equipment, resources, properties
    @Published var currentKingdomInside: Kingdom?  // Kingdom player is currently inside
    @Published var latestTravelEvent: TravelEvent?  // Travel event from last kingdom entry
    @Published var militaryStrengthCache: [String: MilitaryStrength] = [:]  // kingdomId -> strength data
    
    // Kingdom claim celebration
    @Published var showClaimCelebration: Bool = false
    @Published var claimCelebrationKingdom: String?
    
    // Contracts
    @Published var availableContracts: [Contract] = []
    
    // Action Cooldown
    @Published var globalCooldown: GlobalCooldown?
    @Published var slotCooldowns: [String: SlotCooldown]? // Per-slot cooldowns for parallel actions
    @Published var cooldownFetchedAt: Date?
    
    // MARK: - Services
    var apiService = KingdomAPIService.shared
    let contractAPI = ContractAPI()
    let actionsAPI = ActionsAPI()
    
    // MARK: - Configuration
    var loadRadiusMiles: Double = 8  // How many miles around user to load cities (focused on local area)
    
    // MARK: - Private State
    var hasInitializedLocation = false
    var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        // Initialize player - Backend is source of truth!
        self.player = Player()
        self.playerResources = PlayerResources()
        
        // Start with default location - will be replaced when user location arrives
        let center = SampleData.defaultCenter
        self.cameraPosition = .region(
            MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
            )
        )
        
        // CRITICAL: Forward nested ObservableObject changes to MapViewModel
        // This ensures the UI updates when player/resources state changes
        player.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        
        playerResources.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        
        print("📱 MapViewModel initialized")
        
        // IMMEDIATELY sync player ID with backend if authenticated
        // This prevents the "local UUID vs backend UUID" mismatch bug
        Task {
            await syncPlayerIdWithBackend()
        }
    }
    
    // MARK: - Player Sync
    
    /// Sync player ID with backend user ID (called on init)
    /// This fixes the bug where local player had different ID than backend user
    func syncPlayerIdWithBackend() async {
        guard apiService.isAuthenticated else {
            print("⚠️ Not authenticated - using local player ID")
            return
        }
        
        // Fetch current user from backend
        do {
            let request = APIClient.shared.request(endpoint: "/auth/me")
            let userData: UserData = try await APIClient.shared.execute(request)
            
        await MainActor.run {
            player.playerId = userData.id  // Integer from Postgres auto-increment
            player.name = userData.display_name
            player.gold = userData.gold  // FIX: Sync gold from backend
            player.level = userData.level
            player.experience = userData.experience
            player.reputation = userData.reputation
            // Backend is source of truth - no local caching
            
            print("✅ Synced player ID with backend: \(userData.id)")
            print("   - Gold: \(userData.gold)")
            print("   - Level: \(userData.level)")
            
            // Re-sync kingdoms after ID update
            syncPlayerKingdoms()
        }
        } catch {
            print("⚠️ Failed to sync player ID from backend: \(error)")
        }
    }
    
    /// Sync player's fiefsRuled with kingdoms they actually rule
    /// Fixes bug where UI doesn't show kingdom button even though player is ruler
    func syncPlayerKingdomsPublic() {
        syncPlayerKingdoms()
    }
    
    func syncPlayerKingdoms() {
        var updatedFiefs = Set<String>()
        
        for kingdom in kingdoms {
            if kingdom.rulerId == player.playerId {
                updatedFiefs.insert(kingdom.name)
            }
        }
        
        // Update player's fiefsRuled to match reality
        player.fiefsRuled = updatedFiefs
        player.isRuler = !updatedFiefs.isEmpty
        // Backend is source of truth - no local caching
        
        if !updatedFiefs.isEmpty {
            print("🔄 Synced player kingdoms: \(updatedFiefs.joined(separator: ", "))")
        }
    }
    
    // MARK: - Utility
    
    func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLoc = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLoc = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLoc.distance(from: toLoc)  // Returns meters
    }
    
    /// Check if a kingdom is the player's home kingdom
    func isHomeKingdom(_ kingdom: Kingdom) -> Bool {
        // For espionage/foreign status, check hometown kingdom (not just where they visit most)
        // Home kingdom is one where:
        // 1. Player is the ruler, OR
        // 2. It's their hometown kingdom (hometown_kingdom_id from backend)
        let isRuler = kingdom.rulerId == player.playerId
        let isHometown = player.hometownKingdomId == kingdom.id
        
        print("🏠 isHomeKingdom check for \(kingdom.name):")
        print("   - Kingdom ID: \(kingdom.id)")
        print("   - Kingdom Ruler ID: \(kingdom.rulerId ?? 0)")
        print("   - Player ID: \(player.playerId)")
        print("   - Player Hometown ID: \(player.hometownKingdomId ?? "nil")")
        print("   - Is Ruler: \(isRuler)")
        print("   - Is Hometown: \(isHometown)")
        print("   - Result: \(isRuler || isHometown)")
        
        return isRuler || isHometown
    }
}


