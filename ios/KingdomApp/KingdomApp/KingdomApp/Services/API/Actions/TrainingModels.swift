import Foundation

// MARK: - Training Contract

struct TrainingContract: Codable, Identifiable {
    let id: String
    let type: String
    let actionsRequired: Int
    let actionsCompleted: Int
    let costPaid: Int
    let createdAt: String
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case id, type, status
        case actionsRequired = "actions_required"
        case actionsCompleted = "actions_completed"
        case costPaid = "cost_paid"
        case createdAt = "created_at"
    }
    
    var progress: Double {
        return Double(actionsCompleted) / Double(actionsRequired)
    }
}

// MARK: - Training Costs

struct TrainingCosts: Codable {
    let attack: Int
    let defense: Int
    let leadership: Int
    let building: Int
}

// MARK: - Training Costs Response

struct TrainingCostsResponse: Codable {
    let totalTrainingPurchases: Int
    let costs: TrainingCosts
    let currentStats: CurrentStats
    let gold: Int
    
    struct CurrentStats: Codable {
        let attack: Int
        let defense: Int
        let leadership: Int
        let building: Int
        let intelligence: Int
    }
    
    enum CodingKeys: String, CodingKey {
        case costs, gold
        case totalTrainingPurchases = "total_training_purchases"
        case currentStats = "current_stats"
    }
}

// MARK: - Training Action Response

struct TrainingActionResponse: Codable {
    let success: Bool
    let message: String
    let contractId: String
    let trainingType: String
    let actionsCompleted: Int
    let actionsRequired: Int
    let progressPercent: Int
    let isComplete: Bool
    let nextTrainAvailableAt: Date
    let rewards: ActionRewards?
    
    enum CodingKeys: String, CodingKey {
        case success, message, rewards
        case contractId = "contract_id"
        case trainingType = "training_type"
        case actionsCompleted = "actions_completed"
        case actionsRequired = "actions_required"
        case progressPercent = "progress_percent"
        case isComplete = "is_complete"
        case nextTrainAvailableAt = "next_train_available_at"
    }
}

// MARK: - Purchase Training Response

struct PurchaseTrainingResponse: Codable {
    let success: Bool
    let message: String
    let trainingType: String
    let cost: Int
    let contractId: String
    let actionsRequired: Int
    
    enum CodingKeys: String, CodingKey {
        case success, message, cost
        case trainingType = "training_type"
        case contractId = "contract_id"
        case actionsRequired = "actions_required"
    }
}



