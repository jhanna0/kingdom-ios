import Foundation
import CoreLocation

// MARK: - Kingdom Claiming
// NOTE: Check-in happens AUTOMATICALLY in MapViewModel+Location.swift
// when user enters a kingdom via loadPlayerState(kingdomId:)
extension MapViewModel {
    
    // Check-in methods removed - backend handles automatically
    
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
}


