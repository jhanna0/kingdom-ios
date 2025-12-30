import Foundation
import CoreLocation

// MARK: - Check-in & Claiming
extension MapViewModel {
    
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
    
    /// Claim the current kingdom - backend validates and returns success/error
    /// Throws error if: not inside kingdom, someone else claimed it first, you already rule a kingdom, etc.
    func claimKingdom() async throws {
        guard let kingdom = currentKingdomInside else {
            throw NSError(domain: "MapViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not inside a kingdom"])
        }
        
        guard let osmId = kingdom.territory.osmId else {
            throw NSError(domain: "MapViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "Kingdom has no OSM ID"])
        }
        
        // Call backend - it validates everything (unclaimed, user doesn't rule others, etc.)
        // If this throws an error, the celebration won't show
        let kingdomAPI = KingdomAPI()
        let apiKingdom = try await kingdomAPI.createKingdom(
            name: kingdom.name,
            osmId: osmId
        )
        
        // SUCCESS! Backend confirmed the claim (no exception thrown). Update local state.
        await MainActor.run {
            if let index = kingdoms.firstIndex(where: { $0.id == kingdom.id }) {
                kingdoms[index].rulerId = apiKingdom.ruler_id
                kingdoms[index].rulerName = player.name
                kingdoms[index].canClaim = false  // Can't claim anymore
                player.claimKingdom(kingdom.name)
                
                // Update currentKingdomInside to reflect the change
                currentKingdomInside = kingdoms[index]
                
                // Sync player kingdoms to ensure UI updates everywhere
                syncPlayerKingdoms()
                
                print("👑 Successfully claimed \(kingdom.name)")
                
                // Show celebration popup (no rewards from claim endpoint)
                claimCelebrationKingdom = kingdom.name
                showClaimCelebration = true
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
}


