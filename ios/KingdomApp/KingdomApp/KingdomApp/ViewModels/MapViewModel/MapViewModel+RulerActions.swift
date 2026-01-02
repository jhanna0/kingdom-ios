import Foundation

// ⚠️ WARNING: This entire file does LOCAL validation and state updates
// TODO: Replace ALL methods here with backend API calls
// Backend should validate ruler ownership, treasury, building levels, etc.
// Frontend should ONLY call API and update UI with response

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


