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
    @Published var playerResources: PlayerResources  // Equipment, resources, properties
    @Published var currentKingdomInside: Kingdom?  // Kingdom player is currently inside
    
    // API Service - connects to backend server
    var apiService = KingdomAPIService.shared
    let contractAPI = ContractAPI()
    
    // Configuration
    var loadRadiusMiles: Double = 10  // How many miles around user to load cities
    
    private var hasInitializedLocation = false
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Initialize player (loads from UserDefaults automatically)
        self.player = Player()
        self.playerResources = PlayerResources.load()
        
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
    
    /// Sync player ID with backend user ID (called on init)
    /// This fixes the bug where local player had different ID than backend user
    private func syncPlayerIdWithBackend() async {
        guard apiService.isAuthenticated else {
            print("⚠️ Not authenticated - using local player ID")
            return
        }
        
        // Fetch current user from backend
        do {
            let request = APIClient.shared.request(endpoint: "/auth/me")
            let userData: UserData = try await APIClient.shared.execute(request)
            
            // Update player with backend ID and name
            await MainActor.run {
                player.playerId = userData.id  // Integer from Postgres auto-increment
                player.name = userData.display_name
                player.saveToUserDefaults()
                
                print("✅ Synced player ID with backend: \(userData.id)")
                
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
    
    private func syncPlayerKingdoms() {
        var updatedFiefs = Set<String>()
        
        for kingdom in kingdoms {
            if kingdom.rulerId == player.playerId {
                updatedFiefs.insert(kingdom.name)
            }
        }
        
        // Update player's fiefsRuled to match reality
        player.fiefsRuled = updatedFiefs
        player.isRuler = !updatedFiefs.isEmpty
        player.saveToUserDefaults()
        
        if !updatedFiefs.isEmpty {
            print("🔄 Synced player kingdoms: \(updatedFiefs.joined(separator: ", "))")
        }
    }
    
    func updateUserLocation(_ location: CLLocationCoordinate2D) {
        userLocation = location
        
        // Check which kingdom user is inside (local detection)
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
        
        // Handle entering/leaving kingdoms
        if let current = currentKingdomInside, previousKingdom?.id != current.id {
            print("🏰 Entered \(current.name)")
            
            // AUTOMATIC CHECK-IN: Load player state with kingdom_id
            // Backend will auto-check us in and return updated state
            Task {
                do {
                    let updatedState = try await apiService.loadPlayerState(
                        kingdomId: current.id
                    )
                    
                    await MainActor.run {
                        // Update player from backend response (includes check-in rewards)
                        player.gold = updatedState.gold
                        player.level = updatedState.level
                        player.experience = updatedState.experience
                        player.reputation = updatedState.reputation
                        player.currentKingdom = current.name
                        player.saveToUserDefaults()
                        
                        print("✅ Auto-checked in to \(current.name)")
                    }
                } catch {
                    print("⚠️ Failed to auto check-in: \(error.localizedDescription)")
                }
            }
        } else if previousKingdom != nil && currentKingdomInside == nil {
            print("🚪 Left \(previousKingdom!.name)")
            player.currentKingdom = nil
            player.saveToUserDefaults()
        }
    }
    
    /// Check if a kingdom is the player's home kingdom
    func isHomeKingdom(_ kingdom: Kingdom) -> Bool {
        // Home kingdom is one where:
        // 1. Player is the ruler, OR
        // 2. It's their most frequently checked-in kingdom
        return kingdom.rulerId == player.playerId || player.homeKingdomId == kingdom.name
    }
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLoc = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLoc = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLoc.distance(from: toLoc)  // Returns meters
    }
    
    /// Load real town data from backend API
    /// Backend handles caching and ensures all clients get consistent city boundaries
    func loadRealTowns(around location: CLLocationCoordinate2D) {
        guard !isLoading else { return }
        
        isLoading = true
        loadingStatus = "Consulting the kingdom cartographers..."
        errorMessage = nil
        
        Task {
            // Fetch directly from backend API (no local cache)
            do {
                // Fetch cities from backend API (which handles OSM fetching and DB caching)
                let foundKingdoms = try await apiService.fetchCities(
                    lat: location.latitude,
                    lon: location.longitude,
                    radiusKm: loadRadiusMiles * 1.60934  // Convert miles to km
                )
                
                if foundKingdoms.isEmpty {
                    loadingStatus = "The realm lies shrouded in fog..."
                    errorMessage = "No cities found in this area."
                    print("❌ No towns found from API")
                    isLoading = false
                } else {
                    // Backend is the source of truth - just use it directly
                    kingdoms = foundKingdoms
                    
                    // Sync player's fiefsRuled with kingdoms they rule
                    syncPlayerKingdoms()
                    
                    print("✅ Loaded \(foundKingdoms.count) towns from backend API")
                    
                    // Re-check location now that kingdoms are loaded
                    if let currentLocation = userLocation {
                        checkKingdomLocation(currentLocation)
                    }
                    
                    // Done loading
                    isLoading = false
                }
            } catch {
                loadingStatus = "The royal cartographers have failed..."
                errorMessage = "API Error: \(error.localizedDescription)"
                print("❌ Failed to fetch cities from API: \(error.localizedDescription)")
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
        
        // Claim kingdom via API
        Task {
            do {
                let kingdomAPI = KingdomAPI()
                
                guard let osmId = kingdom.territory.osmId else {
                    print("❌ Cannot claim - kingdom has no OSM ID")
                    return
                }
                
                guard osmId == kingdom.id else {
                    print("❌ Kingdom ID mismatch! id=\(kingdom.id), osmId=\(osmId)")
                    return
                }
                
                // Claim the kingdom (kingdoms already exist from /cities call)
                let apiKingdom = try await kingdomAPI.createKingdom(
                    name: kingdom.name,
                    osmId: osmId
                )
                
                // Update local state with the server response
                await MainActor.run {
                    if let index = kingdoms.firstIndex(where: { $0.id == kingdom.id }) {
                        kingdoms[index].rulerId = apiKingdom.ruler_id
                        kingdoms[index].rulerName = player.name
                        player.claimKingdom(kingdom.name)
                        
                        // Update currentKingdomInside to reflect the change
                        currentKingdomInside = kingdoms[index]
                        
                        // Sync player kingdoms to ensure UI updates everywhere
                        syncPlayerKingdoms()
                        
                        print("👑 Successfully claimed \(kingdom.name)")
                    }
                }
            } catch {
                print("❌ Failed to claim kingdom: \(error.localizedDescription)")
                // Still update local state as fallback for offline mode
                await MainActor.run {
                    if let index = kingdoms.firstIndex(where: { $0.id == kingdom.id }) {
                        kingdoms[index].setRuler(playerId: player.playerId, playerName: player.name)
                        player.claimKingdom(kingdom.name)
                        currentKingdomInside = kingdoms[index]
                        
                        // Sync player kingdoms to ensure UI updates everywhere
                        syncPlayerKingdoms()
                        
                        print("⚠️ Claimed locally only - will sync when connection available")
                    }
                }
            }
        }
        
        return true
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
        case .education:
            if kingdoms[index].educationLevel < 5 {
                kingdoms[index].educationLevel += 1
                print("📚 Upgraded education to level \(kingdoms[index].educationLevel) (faster training)")
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
        }
        
        // Update currentKingdomInside if it's the same kingdom
        if currentKingdomInside?.id == kingdom.id {
            currentKingdomInside = kingdoms[index]
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
    
    // MARK: - Contract System
    
    /// Create a new contract for building upgrade
    func createContract(kingdom: Kingdom, buildingType: BuildingType, rewardPool: Int) async throws -> Bool {
        guard let index = kingdoms.firstIndex(where: { $0.id == kingdom.id }) else {
            print("❌ Kingdom not found")
            throw NSError(domain: "MapViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Kingdom not found"])
        }
        
        // Check if ruler owns this kingdom
        guard kingdoms[index].rulerId == player.playerId else {
            print("❌ You don't rule this kingdom")
            throw NSError(domain: "MapViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "You don't rule this kingdom"])
        }
        
        // Get building type string and next level
        let (buildingTypeStr, currentLevel) = getBuildingInfo(kingdom: kingdoms[index], buildingType: buildingType)
        
        // Check if building can be upgraded
        if currentLevel >= 5 {
            print("❌ Building already at max level")
            throw NSError(domain: "MapViewModel", code: 3, userInfo: [NSLocalizedDescriptionKey: "Building already at max level"])
        }
        
        let nextLevel = currentLevel + 1
        
        // Call API to create contract
        do {
            let apiContract = try await contractAPI.createContract(
                kingdomId: kingdom.id,
                kingdomName: kingdom.name,
                buildingType: buildingTypeStr,
                buildingLevel: nextLevel,
                rewardPool: rewardPool,
                basePopulation: kingdoms[index].checkedInPlayers
            )
            
            print("✅ Contract created via API: \(apiContract.id)")
            
            // Reload contracts to show the new one
            await loadContracts()
            
            return true
        } catch {
            print("❌ Failed to create contract: \(error)")
            throw error
        }
    }
    
    
    /// Refresh kingdom data from backend (force fetch)
    func refreshKingdomData() async {
        guard let location = userLocation else { return }
        
        do {
            let foundKingdoms = try await apiService.fetchCities(
                lat: location.latitude,
                lon: location.longitude,
                radiusKm: loadRadiusMiles * 1.60934
            )
            
            await MainActor.run {
                // Backend is the source of truth - just use it
                kingdoms = foundKingdoms
                
                // Update currentKingdomInside if needed
                if let currentId = currentKingdomInside?.id {
                    currentKingdomInside = kingdoms.first(where: { $0.id == currentId })
                }
                
                print("✅ Refreshed kingdom data from backend")
            }
        } catch {
            print("❌ Failed to refresh kingdoms: \(error)")
        }
    }
    
    
    /// Refresh a specific kingdom from backend
    private func refreshKingdomFromBackend(kingdomId: String) async {
        do {
            let apiKingdom = try await apiService.kingdom.getKingdom(id: kingdomId)
            
            await MainActor.run {
                if let index = kingdoms.firstIndex(where: { $0.id == kingdomId }) {
                    kingdoms[index].treasuryGold = apiKingdom.treasury_gold
                    kingdoms[index].wallLevel = apiKingdom.wall_level
                    kingdoms[index].vaultLevel = apiKingdom.vault_level
                    kingdoms[index].mineLevel = apiKingdom.mine_level
                    kingdoms[index].marketLevel = apiKingdom.market_level
                    kingdoms[index].checkedInPlayers = apiKingdom.population
                    kingdoms[index].activeContract = nil // Clear completed contract
                    
                    // Update currentKingdomInside if it's the same kingdom
                    if currentKingdomInside?.id == kingdomId {
                        currentKingdomInside = kingdoms[index]
                    }
                    
                    print("✅ Refreshed kingdom \(apiKingdom.name) - Market Lv.\(apiKingdom.market_level)")
                }
            }
        } catch {
            print("❌ Failed to refresh kingdom: \(error)")
        }
    }
    
    /// Refresh player data from backend
    func refreshPlayerFromBackend() async {
        do {
            let apiPlayerState = try await apiService.loadPlayerState()
            
            await MainActor.run {
                player.gold = apiPlayerState.gold
                player.reputation = apiPlayerState.reputation
                player.level = apiPlayerState.level
                player.contractsCompleted = apiPlayerState.contracts_completed
                player.saveToUserDefaults()
                
                print("✅ Refreshed player state - Gold: \(apiPlayerState.gold)")
            }
        } catch {
            print("❌ Failed to refresh player state: \(error)")
        }
    }
    
    /// Get all available contracts (from API)
    func getAvailableContracts() -> [Contract] {
        // TODO: Fetch from API
        // For now return empty - we'll load async
        return []
    }
    
    /// Fetch contracts from API
    @Published var availableContracts: [Contract] = []
    
    func loadContracts() async {
        do {
            print("🔄 Loading contracts from API...")
            // Load both open AND in_progress contracts so users can see their active work
            let openContracts = try await contractAPI.listContracts(kingdomId: nil, status: "open")
            print("   📋 Open contracts: \(openContracts.count)")
            let inProgressContracts = try await contractAPI.listContracts(kingdomId: nil, status: "in_progress")
            print("   📋 In-progress contracts: \(inProgressContracts.count)")
            let allContracts = openContracts + inProgressContracts
            
            await MainActor.run {
                // Convert APIContract to local Contract model
                self.availableContracts = allContracts.compactMap { apiContract in
                    Contract(
                        id: apiContract.id,
                        kingdomId: apiContract.kingdom_id,
                        kingdomName: apiContract.kingdom_name,
                        buildingType: apiContract.building_type,
                        buildingLevel: apiContract.building_level,
                        basePopulation: apiContract.base_population,
                        baseHoursRequired: apiContract.base_hours_required,
                        workStartedAt: apiContract.work_started_at.flatMap { ISO8601DateFormatter().date(from: $0) },
                        totalActionsRequired: apiContract.total_actions_required,
                        actionsCompleted: apiContract.actions_completed,
                        actionContributions: apiContract.action_contributions,
                        rewardPool: apiContract.reward_pool,
                        createdBy: apiContract.created_by,
                        createdAt: ISO8601DateFormatter().date(from: apiContract.created_at) ?? Date(),
                        completedAt: apiContract.completed_at.flatMap { ISO8601DateFormatter().date(from: $0) },
                        status: Contract.ContractStatus(rawValue: apiContract.status) ?? .open
                    )
                }
                print("✅ Loaded \(self.availableContracts.count) contracts from API (open: \(openContracts.count), in_progress: \(inProgressContracts.count))")
            }
        } catch {
            print("❌ Failed to load contracts: \(error)")
        }
    }
    
    
    // Helper to get building info
    private func getBuildingInfo(kingdom: Kingdom, buildingType: BuildingType) -> (String, Int) {
        switch buildingType {
        case .walls:
            return ("Walls", kingdom.wallLevel)
        case .vault:
            return ("Vault", kingdom.vaultLevel)
        case .mine:
            return ("Mine", kingdom.mineLevel)
        case .market:
            return ("Market", kingdom.marketLevel)
        case .education:
            return ("Education", kingdom.educationLevel)
        }
    }
    
    // MARK: - Subject Reward Distribution System
    
    /// Distribute rewards to eligible subjects in a kingdom (ruler action)
    /// Returns the distribution record or nil if failed
    func distributeSubjectRewards(for kingdomId: String) -> DistributionRecord? {
        guard let kingdomIndex = kingdoms.firstIndex(where: { $0.id == kingdomId }) else {
            print("❌ Kingdom not found")
            return nil
        }
        
        var kingdom = kingdoms[kingdomIndex]
        
        // Check cooldown (23 hours minimum between distributions)
        guard kingdom.canDistributeRewards else {
            print("❌ Distribution on cooldown")
            return nil
        }
        
        // Calculate reward pool
        let rewardPool = kingdom.pendingRewardPool
        
        guard rewardPool > 0 else {
            print("❌ No rewards to distribute (0g pool)")
            return nil
        }
        
        // Check treasury has enough
        guard kingdom.treasuryGold >= rewardPool else {
            print("❌ Insufficient treasury funds")
            return nil
        }
        
        // Get all eligible subjects
        // In single-player, this is just the player if they're a subject
        var eligibleSubjects: [(player: Player, merit: Int)] = []
        
        // Check if current player is eligible
        if player.isEligibleForRewards(inKingdom: kingdom.id, rulerId: kingdom.rulerId) {
            let merit = player.calculateMeritScore(inKingdom: kingdom.id)
            if merit > 0 {
                eligibleSubjects.append((player, merit))
            }
        }
        
        // TODO: When multiplayer, fetch all players in this kingdom and check eligibility
        
        guard !eligibleSubjects.isEmpty else {
            print("ℹ️ No eligible subjects for distribution")
            // Still update timestamp so ruler can try again tomorrow
            kingdom.lastRewardDistribution = Date()
            kingdoms[kingdomIndex] = kingdom
            return nil
        }
        
        // Calculate total merit
        let totalMerit = eligibleSubjects.reduce(0) { $0 + $1.merit }
        
        // Calculate and distribute shares
        var recipients: [RecipientRecord] = []
        
        for (subject, merit) in eligibleSubjects {
            let share = Int(Double(rewardPool) * Double(merit) / Double(totalMerit))
            
            // Give reward to subject
            if subject.playerId == player.playerId {
                player.receiveReward(share)
            }
            // TODO: When multiplayer, send rewards to other players
            
            // Create receipt record
            let rep = subject.getKingdomReputation(kingdom.id)
            let skillTotal = subject.attackPower + subject.defensePower + subject.leadership + subject.buildingSkill
            
            let record = RecipientRecord(
                playerId: subject.playerId,
                playerName: subject.name,
                goldReceived: share,
                meritScore: merit,
                reputation: rep,
                skillTotal: skillTotal
            )
            recipients.append(record)
            
            print("💎 \(subject.name) received \(share)g (merit: \(merit)/\(totalMerit))")
        }
        
        // Deduct from treasury
        kingdom.treasuryGold -= rewardPool
        kingdom.totalRewardsDistributed += rewardPool
        
        // Create distribution record
        let distribution = DistributionRecord(totalPool: rewardPool, recipients: recipients)
        kingdom.distributionHistory.insert(distribution, at: 0)
        
        // Keep only last 30 distributions
        if kingdom.distributionHistory.count > 30 {
            kingdom.distributionHistory = Array(kingdom.distributionHistory.prefix(30))
        }
        
        // Update last distribution time
        kingdom.lastRewardDistribution = Date()
        
        // Save changes
        kingdoms[kingdomIndex] = kingdom
        
        print("✅ Distributed \(rewardPool)g to \(recipients.count) subjects")
        
        return distribution
    }
    
    /// Get estimated reward share for a player in a kingdom
    func getEstimatedRewardShare(for playerId: Int, in kingdomId: String) -> Int {
        guard let kingdom = kingdoms.first(where: { $0.id == kingdomId }) else {
            return 0
        }
        
        // Check if player is eligible
        guard player.playerId == playerId else { return 0 }
        guard player.isEligibleForRewards(inKingdom: kingdom.id, rulerId: kingdom.rulerId) else {
            return 0
        }
        
        // Calculate player's merit
        let _ = player.calculateMeritScore(inKingdom: kingdom.id)  // TODO: Use in multiplayer
        
        // For single-player, player gets 100% if they're the only eligible subject
        // TODO: When multiplayer, calculate based on all subjects
        
        let rewardPool = kingdom.dailyRewardPool
        
        // For now, estimate 100% since single-player
        // In multiplayer, this would be: playerMerit / totalMeritOfAllEligible * rewardPool
        return rewardPool
    }
    
    /// Set the subject reward rate for a kingdom (ruler only)
    func setSubjectRewardRate(_ rate: Int, for kingdomId: String) {
        guard let kingdomIndex = kingdoms.firstIndex(where: { $0.id == kingdomId }) else {
            return
        }
        
        // Check if player is ruler
        guard kingdoms[kingdomIndex].rulerId == player.playerId else {
            print("❌ Only ruler can set reward rate")
            return
        }
        
        kingdoms[kingdomIndex].setSubjectRewardRate(rate)
        print("✅ Set reward rate to \(rate)%")
    }
    
    // MARK: - API Sync Methods
    
    /// Sync player data to backend API
    func syncPlayerToAPI() {
        Task {
            do {
                try await apiService.syncPlayer(player)
                print("✅ Player synced to API")
            } catch {
                print("⚠️ Failed to sync player to API: \(error.localizedDescription)")
            }
        }
    }
    
    /// Sync kingdom to backend API
    /// Note: Kingdoms are server-authoritative and updated through specific actions
    /// (check-in, conquest, contracts, etc.) rather than direct state sync
    func syncKingdomToAPI(_ kingdom: Kingdom) {
        // Kingdom state is managed by the server through specific actions:
        // - Check-ins update population and activity
        // - Conquests change rulers
        // - Contracts upgrade buildings
        // - Economy system handles treasury
        // No direct client-to-server kingdom state sync needed
        print("ℹ️ Kingdom state is server-authoritative: \(kingdom.name)")
    }
    
    /// Check-in with API integration
    func checkInWithAPI() {
        guard let kingdom = currentKingdomInside,
              let location = userLocation else {
            print("❌ Cannot check in - not inside a kingdom")
            return
        }
        
        // Do local check-in first
        let success = checkIn()
        
        if success {
            // Sync to API
            Task {
                do {
                    let response = try await apiService.checkIn(
                        kingdomId: kingdom.id,
                        location: location
                    )
                    
                    print("✅ API check-in: \(response.message)")
                    print("💰 Rewards: \(response.rewards.gold)g, \(response.rewards.experience) XP")
                    
                    // Update player with API rewards
                    player.addGold(response.rewards.gold)
                    player.addExperience(response.rewards.experience)
                    
                } catch {
                    print("⚠️ API check-in failed: \(error.localizedDescription)")
                    // Local check-in still succeeded, so this is just a warning
                }
            }
        }
    }
    
    /// Test API connectivity
    func testAPIConnection() {
        Task {
            let isConnected = await apiService.testConnection()
            if isConnected {
                print("✅ API connection successful")
            } else {
                print("❌ API connection failed")
            }
        }
    }
}
