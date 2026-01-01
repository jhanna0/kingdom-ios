import Foundation

// MARK: - Sabotage Target

struct SabotageTarget: Codable, Identifiable {
    let contractId: Int
    let buildingType: String
    let buildingLevel: Int
    let progress: String
    let progressPercent: Int
    let createdAt: String?
    let potentialDelay: Int
    
    var id: Int { contractId }
    
    enum CodingKeys: String, CodingKey {
        case contractId = "contract_id"
        case buildingType = "building_type"
        case buildingLevel = "building_level"
        case progress
        case progressPercent = "progress_percent"
        case createdAt = "created_at"
        case potentialDelay = "potential_delay"
    }
}

// MARK: - Sabotage Targets Response

struct SabotageTargetsResponse: Codable {
    struct Kingdom: Codable {
        let id: String
        let name: String
    }
    
    struct Cooldown: Codable {
        let ready: Bool
        let secondsRemaining: Int
        
        enum CodingKeys: String, CodingKey {
            case ready
            case secondsRemaining = "seconds_remaining"
        }
    }
    
    let kingdom: Kingdom
    let targets: [SabotageTarget]
    let sabotageCost: Int
    let canSabotage: Bool
    let cooldown: Cooldown
    let goldAvailable: Int
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case kingdom, targets, cooldown, message
        case sabotageCost = "sabotage_cost"
        case canSabotage = "can_sabotage"
        case goldAvailable = "gold_available"
    }
}

// MARK: - Sabotage Action Response

struct SabotageActionResponse: Codable {
    struct SabotageDetails: Codable {
        struct TargetContract: Codable {
            let id: Int
            let buildingType: String
            let buildingLevel: Int
            
            enum CodingKeys: String, CodingKey {
                case id
                case buildingType = "building_type"
                case buildingLevel = "building_level"
            }
        }
        
        let targetKingdom: String
        let targetContract: TargetContract
        let delayApplied: String
        let newTotalActions: Int
        let currentProgress: String
        
        enum CodingKeys: String, CodingKey {
            case targetKingdom = "target_kingdom"
            case targetContract = "target_contract"
            case delayApplied = "delay_applied"
            case newTotalActions = "new_total_actions"
            case currentProgress = "current_progress"
        }
    }
    
    struct Costs: Codable {
        let goldPaid: Int
        
        enum CodingKeys: String, CodingKey {
            case goldPaid = "gold_paid"
        }
    }
    
    struct Rewards: Codable {
        let gold: Int
        let reputation: Int
        let netGold: Int
        
        enum CodingKeys: String, CodingKey {
            case gold, reputation
            case netGold = "net_gold"
        }
    }
    
    struct Statistics: Codable {
        let totalSabotages: Int
        
        enum CodingKeys: String, CodingKey {
            case totalSabotages = "total_sabotages"
        }
    }
    
    let success: Bool
    let message: String
    let sabotage: SabotageDetails
    let costs: Costs
    let rewards: Rewards
    let nextSabotageAvailableAt: Date
    let statistics: Statistics
    
    enum CodingKeys: String, CodingKey {
        case success, message, sabotage, costs, rewards, statistics
        case nextSabotageAvailableAt = "next_sabotage_available_at"
    }
}



