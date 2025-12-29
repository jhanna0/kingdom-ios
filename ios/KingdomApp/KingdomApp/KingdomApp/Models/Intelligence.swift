import Foundation

// MARK: - Military Strength Response

struct MilitaryStrengthResponse: Codable {
    let kingdomId: String
    let kingdomName: String
    let wallLevel: Int
    let totalAttack: Int?
    let totalDefense: Int?
    let totalDefenseWithWalls: Int?
    let activeCitizens: Int?
    let population: Int?
    let isOwnKingdom: Bool
    let hasIntel: Bool
    let intelLevel: Int?
    let intelAgeDays: Int?
    let gatheredBy: String?
    let gatheredAt: String?
    let patrolStrength: String?
    let topPlayers: [TopPlayer]?
    let buildingLevels: BuildingLevels?
    
    enum CodingKeys: String, CodingKey {
        case kingdomId = "kingdom_id"
        case kingdomName = "kingdom_name"
        case wallLevel = "wall_level"
        case totalAttack = "total_attack"
        case totalDefense = "total_defense"
        case totalDefenseWithWalls = "total_defense_with_walls"
        case activeCitizens = "active_citizens"
        case population
        case isOwnKingdom = "is_own_kingdom"
        case hasIntel = "has_intel"
        case intelLevel = "intel_level"
        case intelAgeDays = "intel_age_days"
        case gatheredBy = "gathered_by"
        case gatheredAt = "gathered_at"
        case patrolStrength = "patrol_strength"
        case topPlayers = "top_players"
        case buildingLevels = "building_levels"
    }
}

struct TopPlayer: Codable, Identifiable {
    var id: String { name }
    let name: String
    let attack: Int
    let defense: Int
}

struct BuildingLevels: Codable {
    let walls: Int
    let vault: Int
    let mine: Int
    let market: Int
    let farm: Int
    let education: Int
}

// MARK: - Gather Intelligence Response

struct GatherIntelligenceResponse: Codable {
    let success: Bool
    let caught: Bool
    let message: String
    let costPaid: Int
    let reputationGained: Int?
    let reputationLost: Int?
    let detectionChance: Double
    let intelExpiresInDays: Int?
    let intelLevel: Int?
    let intelData: IntelData?
    let roll: Double?
    
    enum CodingKeys: String, CodingKey {
        case success
        case caught
        case message
        case costPaid = "cost_paid"
        case reputationGained = "reputation_gained"
        case reputationLost = "reputation_lost"
        case detectionChance = "detection_chance"
        case intelExpiresInDays = "intel_expires_in_days"
        case intelLevel = "intel_level"
        case intelData = "intel_data"
        case roll
    }
}

struct IntelData: Codable {
    let wallLevel: Int
    let totalAttack: Int?
    let totalDefense: Int?
    let activeCitizens: Int?
    let population: Int?
    
    enum CodingKeys: String, CodingKey {
        case wallLevel = "wall_level"
        case totalAttack = "total_attack"
        case totalDefense = "total_defense"
        case activeCitizens = "active_citizens"
        case population
    }
}

// MARK: - UI Display Model

struct MilitaryStrength: Identifiable {
    var id: String { kingdomId }
    
    let kingdomId: String
    let kingdomName: String
    let wallLevel: Int
    
    // Only available if own kingdom or have intel
    var totalAttack: Int?
    var totalDefense: Int?
    var totalDefenseWithWalls: Int?
    var activeCitizens: Int?
    var population: Int?
    
    let isOwnKingdom: Bool
    let hasIntel: Bool
    let intelLevel: Int?
    let intelAgeDays: Int?
    let gatheredBy: String?
    let gatheredAt: Date?
    
    init(from response: MilitaryStrengthResponse) {
        self.kingdomId = response.kingdomId
        self.kingdomName = response.kingdomName
        self.wallLevel = response.wallLevel
        self.totalAttack = response.totalAttack
        self.totalDefense = response.totalDefense
        self.totalDefenseWithWalls = response.totalDefenseWithWalls
        self.activeCitizens = response.activeCitizens
        self.population = response.population
        self.isOwnKingdom = response.isOwnKingdom
        self.hasIntel = response.hasIntel
        self.intelLevel = response.intelLevel
        self.intelAgeDays = response.intelAgeDays
        self.gatheredBy = response.gatheredBy
        
        if let gatheredAtString = response.gatheredAt {
            let formatter = ISO8601DateFormatter()
            self.gatheredAt = formatter.date(from: gatheredAtString)
        } else {
            self.gatheredAt = nil
        }
    }
    
    var canDefeatInAttack: Bool {
        guard let ourAttack = totalAttack,
              let theirDefense = totalDefenseWithWalls else {
            return false
        }
        // Need 25% advantage to win
        return Double(ourAttack) > Double(theirDefense) * 1.25
    }
    
    var intelAgeText: String {
        guard let days = intelAgeDays else { return "" }
        if days == 0 {
            return "Today"
        } else if days == 1 {
            return "1 day ago"
        } else {
            return "\(days) days ago"
        }
    }
    
    var isIntelExpiring: Bool {
        guard let days = intelAgeDays else { return false }
        return days >= 5  // Warn when intel is 5+ days old
    }
}

