import Foundation

// MARK: - Ruler Actions (Building Upgrades & Income)
extension MapViewModel {
    
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
                print("⛏️ Upgraded mine to level \(kingdoms[index].mineLevel) (unlocks materials)")
            }
        case .market:
            if kingdoms[index].marketLevel < 5 {
                kingdoms[index].marketLevel += 1
                print("🏪 Upgraded market to level \(kingdoms[index].marketLevel) (+income)")
            }
        case .farm:
            if kingdoms[index].farmLevel < 5 {
                kingdoms[index].farmLevel += 1
                print("🌾 Upgraded farm to level \(kingdoms[index].farmLevel) (faster contracts)")
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
}


