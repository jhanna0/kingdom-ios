import Foundation
import MapKit
import SwiftUI
import Combine
import CoreLocation

// MARK: - Notification Names
extension Notification.Name {
    static let playerStateDidChange = Notification.Name("playerStateDidChange")
}

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
    
    // Active coup in home kingdom (for map badge)
    @Published var activeCoupInHomeKingdom: ActiveCoupData?
    
    // Active battle in current kingdom (computed from currentKingdomInside)
    // This shows invasions/coups in the kingdom you're standing in
    var activeBattleInCurrentKingdom: ActiveCoupData? {
        return currentKingdomInside?.activeCoup
    }
    
    // War state tracking (for music)
    @Published var isInWarState: Bool = false
    
    // MARK: - Services
    var apiService = KingdomAPIService.shared
    var musicService = MusicService.shared
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
        
        // Player ID sync happens in /player/state via updateFromAPIState()
        // No separate /auth/me call needed
        
        // Monitor war state changes for music
        setupWarStateMonitoring()
        
        // Listen for player state refresh requests (e.g., after trades)
        NotificationCenter.default.addObserver(forName: .playerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshPlayerFromBackend()
            }
        }
    }
    
    /// Setup continuous monitoring of war state for music transitions
    private func setupWarStateMonitoring() {
        // Monitor active coup changes
        $activeCoupInHomeKingdom
            .sink { [weak self] coup in
                self?.updateWarState()
            }
            .store(in: &cancellables)
        
        // Monitor kingdoms array changes (for coup updates)
        $kingdoms
            .sink { [weak self] _ in
                self?.updateWarState()
            }
            .store(in: &cancellables)
        
        // Monitor player hometown changes - fixes race condition where kingdoms load before player state
        // When /player/state sets hometownKingdomId, re-check for active coups
        player.$hometownKingdomId
            .dropFirst() // Skip initial nil value
            .sink { [weak self] newHometownId in
                guard newHometownId != nil else { return }
                print("🏠 Hometown kingdom ID updated to: \(newHometownId ?? "nil") - rechecking for coups")
                self?.updateActiveCoupFromKingdoms()
            }
            .store(in: &cancellables)
    }
    
    /// Update active coup in home kingdom from current kingdom data
    /// Called when kingdoms are loaded or updated
    func updateActiveCoupFromKingdoms() {
        print("🔍 updateActiveCoupFromKingdoms called:")
        print("   - player.hometownKingdomId: \(player.hometownKingdomId ?? "nil")")
        print("   - kingdoms count: \(kingdoms.count)")
        for k in kingdoms {
            print("   - Kingdom: \(k.name) (id=\(k.id)), isAtWar: \(k.isAtWar), activeCoup: \(k.activeCoup != nil)")
        }
        
        // Find home kingdom and check for active coup
        if let homeKingdomId = player.hometownKingdomId,
           let homeKingdom = kingdoms.first(where: { $0.id == homeKingdomId }),
           let coup = homeKingdom.activeCoup {
            activeCoupInHomeKingdom = coup
            print("⚔️ Active coup in home kingdom: \(coup.kingdom_name)")
            
            // Schedule notification for when pledge phase ends
            if coup.status == "pledge", let pledgeEnd = coup.pledgeEndDate {
                Task {
                    await NotificationManager.shared.scheduleCoupPhaseNotification(
                        coupId: coup.id,
                        phase: "pledge",
                        endDate: pledgeEnd,
                        kingdomName: coup.kingdom_name
                    )
                }
            }
        } else {
            print("❌ No active coup found in home kingdom")
            if let homeKingdomId = player.hometownKingdomId {
                if let homeKingdom = kingdoms.first(where: { $0.id == homeKingdomId }) {
                    print("   - Found home kingdom \(homeKingdom.name), but activeCoup is nil")
                } else {
                    print("   - Home kingdom ID \(homeKingdomId) not in kingdoms list")
                }
            } else {
                print("   - No hometownKingdomId set")
            }
            activeCoupInHomeKingdom = nil
        }
        
        // Update war state and music
        updateWarState()
    }
    
    /// Check if player is in a war state (active battle in any relevant kingdom)
    /// Updates music accordingly - Backend is source of truth via kingdom.isAtWar!
    func updateWarState() {
        let wasInWar = isInWarState
        
        // Check if HOME kingdom is at war
        let homeKingdomAtWar: Bool
        if let homeKingdomId = player.hometownKingdomId,
           let homeKingdom = kingdoms.first(where: { $0.id == homeKingdomId }) {
            homeKingdomAtWar = homeKingdom.isAtWar
        } else {
            homeKingdomAtWar = false
        }
        
        // Check if CURRENT kingdom is at war (where player is right now)
        let currentKingdomAtWar: Bool
        if let currentKingdomId = player.currentKingdom,
           let currentKingdom = kingdoms.first(where: { $0.id == currentKingdomId }) {
            currentKingdomAtWar = currentKingdom.isAtWar
        } else {
            currentKingdomAtWar = false
        }
        
        // Check if any RULED kingdoms are at war
        let ruledKingdoms = kingdoms.filter { $0.rulerId == player.playerId }
        let ruledKingdomsAtWar = ruledKingdoms.contains { $0.isAtWar }
        
        // Also check activeCoupInHomeKingdom for backwards compat (from /notifications/updates)
        let hasActiveCoup = activeCoupInHomeKingdom != nil
        
        isInWarState = homeKingdomAtWar || currentKingdomAtWar || ruledKingdomsAtWar || hasActiveCoup
        
        // Update music if war state changed
        if isInWarState != wasInWar {
            if isInWarState {
                print("🎵 ⚔️ WAR STATE DETECTED - Switching to war music")
                if homeKingdomAtWar { print("   - Home kingdom is at war") }
                if currentKingdomAtWar { print("   - Current kingdom is at war") }
                if ruledKingdomsAtWar { print("   - Ruled kingdom(s) at war") }
                if hasActiveCoup { print("   - Active coup in home kingdom") }
                musicService.transitionToWarMusic()
            } else {
                print("🎵 ☮️ PEACE RESTORED - Switching to peaceful music")
                musicService.transitionToPeacefulMusic()
            }
        }
    }
    
    // MARK: - Player Sync
    
    // NOTE: Player ID sync now happens in /player/state via player.updateFromAPIState()
    // No separate /auth/me call needed - removed duplicate call
    
    /// Sync ruled kingdoms - now deprecated, use backend data only
    /// The /notifications/updates endpoint provides the kingdoms array which is source of truth
    func syncPlayerKingdomsPublic() {
        // No-op - backend is source of truth for ruled kingdoms
        // Ruled kingdoms are synced via player.updateRuledKingdoms() from /notifications/updates
        print("ℹ️ syncPlayerKingdomsPublic called - ruled kingdoms come from backend only")
    }

    func syncPlayerKingdoms() {
        // DEPRECATED: Backend is the ONLY source of truth for ruler status
        // - isRuler comes from /player/state's is_ruler field
        // - ruledKingdomIds/ruledKingdomNames come from /notifications/updates kingdoms array
        // Do NOT calculate ruler status locally!
        print("ℹ️ syncPlayerKingdoms called - ruled kingdoms come from backend only")
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


