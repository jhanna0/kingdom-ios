import Foundation

// MARK: - Achievement Models

/// Rewards structure for an achievement tier
struct APIAchievementRewards: Codable {
    let gold: Int
    let experience: Int
    let book: Int
    let items: [[String: String]]?  // Optional array of item dicts
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gold = try container.decodeIfPresent(Int.self, forKey: .gold) ?? 0
        experience = try container.decodeIfPresent(Int.self, forKey: .experience) ?? 0
        book = try container.decodeIfPresent(Int.self, forKey: .book) ?? 0
        items = try container.decodeIfPresent([[String: String]].self, forKey: .items)
    }
    
    enum CodingKeys: String, CodingKey {
        case gold, experience, book, items
    }
}

/// A single tier of an achievement
struct APIAchievementTier: Codable, Identifiable {
    let id: Int
    let tier: Int
    let target_value: Int
    let rewards: APIAchievementRewards
    let display_name: String
    let description: String?
    let is_completed: Bool
    let is_claimed: Bool
    let claimed_at: String?
}

/// An achievement type with all its tiers
struct APIAchievement: Codable, Identifiable {
    var id: String { achievement_type }
    
    let achievement_type: String
    let display_name: String
    let description: String?
    let icon: String?
    let category: String
    let type_display_name: String?  // Optional clear description like "Total Fish Caught"
    let current_value: Int
    let tiers: [APIAchievementTier]
    let current_tier: Int
    let next_tier_target: Int?
    let progress_percent: Double
    let has_claimable: Bool
}

/// Grouped achievements by category
struct APIAchievementCategory: Codable, Identifiable {
    var id: String { category }
    
    let category: String
    let display_name: String
    let icon: String
    let achievements: [APIAchievement]
}

/// Response for achievements list
struct APIAchievementsResponse: Codable {
    let success: Bool
    let categories: [APIAchievementCategory]
    let total_achievements: Int  // Number of unique achievement types
    let total_tiers: Int  // Total number of claimable tiers
    let total_completed: Int  // Number of tiers completed (met target)
    let total_claimed: Int  // Number of tiers with rewards claimed
    let total_claimable: Int  // Number of tiers completed but not yet claimed
    let overall_progress_percent: Double  // Claimed tiers / total tiers * 100
}

/// Request to claim an achievement tier reward
struct ClaimAchievementRequest: Codable {
    let achievement_tier_id: Int
}

/// Response after claiming a reward
struct APIClaimRewardResponse: Codable {
    let success: Bool
    let message: String
    let rewards_granted: APIAchievementRewards
    let new_gold: Int
    let new_experience: Int
    let new_level: Int?
    let achievement_type: String
    let tier: Int
    let display_name: String
}

/// Quick summary response for badge counts
struct APIAchievementsSummary: Codable {
    let total_tiers: Int
    let claimed_count: Int
    let claimable_count: Int
    let completion_percent: Double
}
