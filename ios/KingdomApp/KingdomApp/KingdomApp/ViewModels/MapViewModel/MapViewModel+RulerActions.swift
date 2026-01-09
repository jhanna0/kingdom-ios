import Foundation

// ⚠️ WARNING: This entire file does LOCAL validation and state updates
// TODO: Replace ALL methods here with backend API calls
// Backend should validate ruler ownership, treasury, building levels, etc.
// Frontend should ONLY call API and update UI with response

// MARK: - Ruler Actions (Building Upgrades & Income)
extension MapViewModel {
    
    /// Upgrade a building (uses kingdom treasury, not player gold) - FULLY DYNAMIC with string building types
    func upgradeBuilding(kingdom: Kingdom, buildingType: String, cost: Int) {
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
        
        // Upgrade the building - FULLY DYNAMIC using metadata
        let currentLevel = kingdoms[index].buildingLevel(buildingType)
        let maxLevel = kingdoms[index].getBuildingMetadata(buildingType)?.maxLevel ?? 5
        
        if currentLevel < maxLevel {
            kingdoms[index].buildingLevels[buildingType] = currentLevel + 1
            let displayName = kingdoms[index].getBuildingMetadata(buildingType)?.displayName ?? buildingType.capitalized
            print("✅ Upgraded \(displayName) to level \(currentLevel + 1)")
        }
        
        // Update currentKingdomInside if it's the same kingdom
        if currentKingdomInside?.id == kingdom.id {
            currentKingdomInside = kingdoms[index]
        }
    }
    
    // NOTE: Income collection removed - backend handles this automatically at night
    // Kingdom treasury values come from backend API responses
    
    /// Set the kingdom tax rate (ruler only)
    func setKingdomTaxRate(_ rate: Int, for kingdomId: String) {
        // Clamp rate to 0-100
        let clampedRate = max(0, min(100, rate))
        
        Task {
            do {
                // Call backend API
                let response = try await KingdomAPIService.shared.kingdom.setTaxRate(kingdomId: kingdomId, taxRate: clampedRate)
                
                await MainActor.run {
                    // Update local state with response
                    if let kingdomIndex = kingdoms.firstIndex(where: { $0.id == kingdomId }) {
                        kingdoms[kingdomIndex].taxRate = response.taxRate
                        print("✅ Tax rate updated to \(response.taxRate)%")
                        
                        // Update currentKingdomInside if it's the same kingdom
                        if currentKingdomInside?.id == kingdomId {
                            currentKingdomInside = kingdoms[kingdomIndex]
                        }
                    }
                }
            } catch {
                print("❌ Failed to set tax rate: \(error.localizedDescription)")
            }
        }
    }
}


