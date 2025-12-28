import Foundation
import MapKit
import SwiftUI
import Combine
import CoreLocation

@MainActor
class MapViewModel: ObservableObject {
    @Published var kingdoms: [Kingdom] = [] {
        didSet {
            // Auto-save kingdoms whenever they change
            // TODO: Replace with backend sync in the future
            saveKingdomsToStorage()
            
            // Populate kingdoms with NPC citizens
            worldSimulator.populateKingdoms(kingdoms)
        }
    }
    @Published var cameraPosition: MapCameraPosition
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var isLoading: Bool = false
    @Published var loadingStatus: String = "Awakening the royal cartographers..."
    @Published var errorMessage: String?
    @Published var player: Player
    @Published var playerResources: PlayerResources  // Equipment, resources, properties
    @Published var currentKingdomInside: Kingdom?  // Kingdom player is currently inside
    
    // World simulation - makes the game feel alive!
    @Published var worldSimulator = WorldSimulator.shared
    @Published var showActivityFeed: Bool = false
    
    // API Service - connects to backend server
    @Published var apiService = KingdomAPIService()
    
    // Configuration
    var loadRadiusMiles: Double = 10  // How many miles around user to load cities
    
    private var hasInitializedLocation = false
    private var hasLoadedPersistedKingdoms = false
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
        
        // Load persisted kingdoms (if any)
        loadPersistedKingdoms()
        
        print("📱 MapViewModel initialized")
    }
    
    /// Load kingdoms from persistent storage
    /// TODO: Replace with backend API call - GET /kingdoms
    private func loadPersistedKingdoms() {
        guard !hasLoadedPersistedKingdoms else { return }
        hasLoadedPersistedKingdoms = true
        
        if let savedKingdoms = KingdomPersistence.shared.loadKingdoms() {
            // Temporarily disable auto-save during load
            let tempKingdoms = savedKingdoms
            kingdoms = []  // Clear first
            
            // Set kingdoms without triggering didSet
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.kingdoms = tempKingdoms
                
                // Sync player's fiefsRuled with kingdoms they actually rule
                self.syncPlayerKingdoms()
                
                // Re-check current location after loading kingdoms
                if let location = self.userLocation {
                    self.checkKingdomLocation(location)
                }
                
                print("✅ Restored \(tempKingdoms.count) kingdoms from storage")
            }
        }
    }
    
    /// Save kingdoms to persistent storage
    /// TODO: Replace with backend API sync
    private func saveKingdomsToStorage() {
        // Only save if we have kingdoms and have finished initial load
        guard !kingdoms.isEmpty && hasLoadedPersistedKingdoms else { return }
        KingdomPersistence.shared.saveKingdoms(kingdoms)
    }
    
    /// Sync player's fiefsRuled with kingdoms they actually rule
    /// Fixes bug where UI doesn't show kingdom button even though player is ruler
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
        
        // Check which kingdom user is inside
        checkKingdomLocation(location)
        
        // Check and complete any ready contracts
        checkAndCompleteContracts()
        
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
    
    /// Load real town data from backend API
    /// Backend handles caching and ensures all clients get consistent city boundaries
    func loadRealTowns(around location: CLLocationCoordinate2D) {
        guard !isLoading else { return }
        
        isLoading = true
        loadingStatus = "Consulting the kingdom cartographers..."
        errorMessage = nil
        
        Task {
            // Fetch directly from backend API (no local cache)
            print("🌐 Fetching cities from backend API...")
            
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
                    // Merge with existing kingdoms to preserve state changes
                    let mergedKingdoms = mergeKingdoms(existing: kingdoms, new: foundKingdoms)
                    kingdoms = mergedKingdoms
                    
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
    
    /// Merge new kingdoms with existing ones, preserving state of existing kingdoms
    /// This is crucial to maintain upgrades, rulers, contracts, etc.
    /// TODO: Backend will handle this via proper sync/merge logic
    private func mergeKingdoms(existing: [Kingdom], new: [Kingdom]) -> [Kingdom] {
        var result: [Kingdom] = []
        
        for newKingdom in new {
            // Check if we already have this kingdom (by name, since GeoJSON doesn't have IDs)
            if let existingKingdom = existing.first(where: { $0.name == newKingdom.name }) {
                // Keep the existing kingdom (preserves all state)
                result.append(existingKingdom)
            } else {
                // New kingdom - add it
                result.append(newKingdom)
            }
        }
        
        return result
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
        }
        
        // Also collect NPC tax income (citizens mining and paying taxes)
        let taxIncome = worldSimulator.simulateTaxIncome(for: &kingdoms[index])
        if taxIncome > 0 {
            print("💰 Citizens paid \(taxIncome)g in taxes!")
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
    func createContract(kingdom: Kingdom, buildingType: BuildingType, rewardPool: Int) -> Bool {
        guard let index = kingdoms.firstIndex(where: { $0.id == kingdom.id }) else {
            print("❌ Kingdom not found")
            return false
        }
        
        // Check if ruler owns this kingdom
        guard kingdoms[index].rulerId == player.playerId else {
            print("❌ You don't rule this kingdom")
            return false
        }
        
        // Check if there's already an active contract
        if kingdoms[index].activeContract != nil {
            print("❌ Kingdom already has an active contract")
            return false
        }
        
        // Get building type string and next level
        let (buildingTypeStr, currentLevel) = getBuildingInfo(kingdom: kingdoms[index], buildingType: buildingType)
        
        // Check if building can be upgraded
        if currentLevel >= 5 {
            print("❌ Building already at max level")
            return false
        }
        
        let nextLevel = currentLevel + 1
        
        // Check if kingdom has enough treasury gold for reward pool
        guard kingdoms[index].treasuryGold >= rewardPool else {
            print("❌ Kingdom treasury insufficient: need \(rewardPool), have \(kingdoms[index].treasuryGold)")
            return false
        }
        
        // Deduct from kingdom treasury
        kingdoms[index].treasuryGold -= rewardPool
        
        // Create the contract
        let contract = Contract.create(
            kingdomId: kingdom.id.uuidString,
            kingdomName: kingdom.name,
            buildingType: buildingTypeStr,
            buildingLevel: nextLevel,
            population: kingdoms[index].checkedInPlayers,
            rewardPool: rewardPool,
            createdBy: player.playerId
        )
        
        kingdoms[index].activeContract = contract
        
        // Have NPC citizens start working on the contract
        let npcWorkers = worldSimulator.simulateContractWork(for: &kingdoms[index])
        
        print("📜 Contract created: \(buildingTypeStr) level \(nextLevel) - ~\(String(format: "%.1f", contract.baseHoursRequired))h with 3 workers")
        if npcWorkers > 0 {
            print("👷 \(npcWorkers) citizens joined the work crew!")
        }
        
        // Update currentKingdomInside if it's the same kingdom
        if currentKingdomInside?.id == kingdom.id {
            currentKingdomInside = kingdoms[index]
        }
        
        return true
    }
    
    /// Accept a contract and start working
    func acceptContract(kingdom: Kingdom) -> Bool {
        guard let index = kingdoms.firstIndex(where: { $0.id == kingdom.id }) else {
            print("❌ Kingdom not found")
            return false
        }
        
        guard var contract = kingdoms[index].activeContract else {
            print("❌ No active contract in this kingdom")
            return false
        }
        
        // Check if contract is already complete
        if contract.isComplete {
            print("❌ Contract already complete")
            return false
        }
        
        // Check if player already working on a different contract
        if let activeId = player.activeContractId, activeId != contract.id {
            print("❌ Already working on another contract")
            return false
        }
        
        // Check if player is already working on this contract
        if contract.workers.contains(player.playerId) {
            print("❌ Already working on this contract")
            return false
        }
        
        // Can't work on your own contract
        if contract.createdBy == player.playerId {
            print("❌ Cannot work on your own contract")
            return false
        }
        
        // Accept the contract - this starts/updates the timer
        contract.addWorker(player.playerId)
        kingdoms[index].activeContract = contract
        player.activeContractId = contract.id
        player.saveToUserDefaults()
        
        let timeEstimate = contract.hoursToComplete
        print("✅ Accepted contract: \(contract.buildingType) level \(contract.buildingLevel) (~\(String(format: "%.1f", timeEstimate))h)")
        
        // Update currentKingdomInside if it's the same kingdom
        if currentKingdomInside?.id == kingdom.id {
            currentKingdomInside = kingdoms[index]
        }
        
        return true
    }
    
    /// Stop working on a contract
    func leaveContract() -> Bool {
        guard let contractId = player.activeContractId else {
            print("❌ Not working on any contract")
            return false
        }
        
        // Find the kingdom with this contract
        guard let kingdomIndex = kingdoms.firstIndex(where: { $0.activeContract?.id == contractId }) else {
            print("❌ Contract not found")
            return false
        }
        
        guard var contract = kingdoms[kingdomIndex].activeContract else {
            return false
        }
        
        contract.removeWorker(player.playerId)
        kingdoms[kingdomIndex].activeContract = contract
        player.activeContractId = nil
        player.saveToUserDefaults()
        
        print("🚪 Left contract")
        
        // Update currentKingdomInside if it's the same kingdom
        if currentKingdomInside?.id == kingdoms[kingdomIndex].id {
            currentKingdomInside = kingdoms[kingdomIndex]
        }
        
        return true
    }
    
    /// Check all contracts and auto-complete any that are ready
    func checkAndCompleteContracts() {
        for (index, kingdom) in kingdoms.enumerated() {
            guard let contract = kingdom.activeContract else { continue }
            
            // Skip if not ready
            guard contract.isReadyToComplete else { continue }
            
            // Complete the contract
            completeContract(kingdomIndex: index)
        }
    }
    
    /// Complete a contract and distribute rewards
    private func completeContract(kingdomIndex: Int) {
        guard var contract = kingdoms[kingdomIndex].activeContract else { return }
        
        let buildingType = contract.buildingType
        let level = contract.buildingLevel
        let rewardPerWorker = contract.rewardPerWorker
        
        // Mark as complete
        contract.complete()
        
        // Upgrade the building
        switch buildingType.lowercased() {
        case "walls":
            kingdoms[kingdomIndex].wallLevel = level
        case "vault":
            kingdoms[kingdomIndex].vaultLevel = level
        case "mine":
            kingdoms[kingdomIndex].mineLevel = level
        case "market":
            kingdoms[kingdomIndex].marketLevel = level
        default:
            break
        }
        
        // Distribute rewards equally to all workers
        for workerId in contract.workers {
            if workerId == player.playerId {
                player.gold += rewardPerWorker
                player.contractsCompleted += 1
                player.activeContractId = nil
                player.saveToUserDefaults()
                print("💰 Contract complete! Earned \(rewardPerWorker) gold")
            }
            // TODO: When multiplayer, distribute to other players
        }
        
        // Clear the contract
        kingdoms[kingdomIndex].activeContract = nil
        
        print("🎉 \(buildingType) upgraded to level \(level)!")
        
        // Update currentKingdomInside if it's the same kingdom
        if currentKingdomInside?.id == kingdoms[kingdomIndex].id {
            currentKingdomInside = kingdoms[kingdomIndex]
        }
    }
    
    /// Get all available contracts
    func getAvailableContracts() -> [Contract] {
        return kingdoms.compactMap { $0.activeContract }
            .filter { !$0.isComplete }
    }
    
    /// Get player's active contract
    func getPlayerActiveContract() -> Contract? {
        guard let contractId = player.activeContractId else { return nil }
        return kingdoms.compactMap { $0.activeContract }
            .first { $0.id == contractId }
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
        }
    }
    
    // MARK: - Subject Reward Distribution System
    
    /// Distribute rewards to eligible subjects in a kingdom (ruler action)
    /// Returns the distribution record or nil if failed
    func distributeSubjectRewards(for kingdomId: UUID) -> DistributionRecord? {
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
        if player.isEligibleForRewards(inKingdom: kingdom.id.uuidString, rulerId: kingdom.rulerId) {
            let merit = player.calculateMeritScore(inKingdom: kingdom.id.uuidString)
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
            let rep = subject.getKingdomReputation(kingdom.id.uuidString)
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
    func getEstimatedRewardShare(for playerId: String, in kingdomId: UUID) -> Int {
        guard let kingdom = kingdoms.first(where: { $0.id == kingdomId }) else {
            return 0
        }
        
        // Check if player is eligible
        guard player.playerId == playerId else { return 0 }
        guard player.isEligibleForRewards(inKingdom: kingdom.id.uuidString, rulerId: kingdom.rulerId) else {
            return 0
        }
        
        // Calculate player's merit
        let playerMerit = player.calculateMeritScore(inKingdom: kingdom.id.uuidString)
        
        // For single-player, player gets 100% if they're the only eligible subject
        // TODO: When multiplayer, calculate based on all subjects
        
        let rewardPool = kingdom.dailyRewardPool
        
        // For now, estimate 100% since single-player
        // In multiplayer, this would be: playerMerit / totalMeritOfAllEligible * rewardPool
        return rewardPool
    }
    
    /// Set the subject reward rate for a kingdom (ruler only)
    func setSubjectRewardRate(_ rate: Int, for kingdomId: UUID) {
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
    func syncKingdomToAPI(_ kingdom: Kingdom) {
        Task {
            do {
                try await apiService.syncKingdom(kingdom)
                print("✅ Kingdom synced to API: \(kingdom.name)")
            } catch {
                print("⚠️ Failed to sync kingdom to API: \(error.localizedDescription)")
            }
        }
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
                        playerId: player.playerId,
                        kingdomId: kingdom.id.uuidString,
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
