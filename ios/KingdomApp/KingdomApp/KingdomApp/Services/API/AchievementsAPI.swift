import Foundation

// MARK: - Achievements API

class AchievementsAPI {
    private let client = APIClient.shared
    
    /// Get all achievements with player progress
    func getAchievements() async throws -> APIAchievementsResponse {
        let request = client.request(endpoint: "/achievements", method: "GET")
        return try await client.execute(request)
    }
    
    /// Claim a completed achievement tier reward
    func claimReward(tierId: Int) async throws -> APIClaimRewardResponse {
        let body = ClaimAchievementRequest(achievement_tier_id: tierId)
        let request = try client.request(endpoint: "/achievements/claim", method: "POST", body: body)
        return try await client.execute(request)
    }
    
    /// Get quick summary for badge counts
    func getSummary() async throws -> APIAchievementsSummary {
        let request = client.request(endpoint: "/achievements/summary", method: "GET")
        return try await client.execute(request)
    }
}
