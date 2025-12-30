import Foundation

// MARK: - Subject Reward Distribution System
extension MapViewModel {
    
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
}


