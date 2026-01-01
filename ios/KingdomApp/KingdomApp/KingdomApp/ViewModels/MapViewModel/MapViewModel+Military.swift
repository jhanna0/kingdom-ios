import Foundation

// MARK: - Military & Intelligence
extension MapViewModel {
    
    /// Fetch military strength for a kingdom
    func fetchMilitaryStrength(kingdomId: String) async {
        print("🔍 FETCHING military strength for kingdom: \(kingdomId)")
        do {
            let response = try await APIClient.shared.getMilitaryStrength(kingdomId: kingdomId)
            print("🔍 GOT RESPONSE from API")
            
            await MainActor.run {
                let strength = MilitaryStrength(from: response)
                militaryStrengthCache[kingdomId] = strength
                print("✅ Loaded military strength for \(response.kingdomName)")
            }
        } catch {
            print("❌ Failed to load military strength: \(error)")
        }
    }
    
    /// Gather intelligence on an enemy kingdom
    func gatherIntelligence(kingdomId: String) async throws -> GatherIntelligenceResponse {
        let response = try await APIClient.shared.gatherIntelligence(kingdomId: kingdomId)
        
        // Refresh player state (gold was deducted)
        await refreshPlayerFromBackend()
        
        // Refresh military strength to show new intel
        if response.success {
            await fetchMilitaryStrength(kingdomId: kingdomId)
        }
        
        return response
    }
}




