import Foundation

// MARK: - Request Models

struct AllianceProposeRequest: Codable {
    let targetEmpireId: String
    
    enum CodingKeys: String, CodingKey {
        case targetEmpireId = "target_empire_id"
    }
}

extension APIClient {
    
    // MARK: - Alliance Operations
    
    /// Propose an alliance to another empire
    func proposeAlliance(targetEmpireId: String) async throws -> AllianceProposeResponse {
        let body = AllianceProposeRequest(targetEmpireId: targetEmpireId)
        let request = try self.request(endpoint: "/alliances/propose", method: "POST", body: body)
        let response: AllianceProposeResponse = try await execute(request)
        return response
    }
    
    /// Accept an alliance proposal
    func acceptAlliance(allianceId: Int) async throws -> AllianceAcceptResponse {
        let request = self.request(endpoint: "/alliances/\(allianceId)/accept", method: "POST")
        let response: AllianceAcceptResponse = try await execute(request)
        return response
    }
    
    /// Decline an alliance proposal
    func declineAlliance(allianceId: Int) async throws -> AllianceDeclineResponse {
        let request = self.request(endpoint: "/alliances/\(allianceId)/decline", method: "POST")
        let response: AllianceDeclineResponse = try await execute(request)
        return response
    }
    
    /// Get active alliances for your empire
    func getActiveAlliances() async throws -> AllianceListResponse {
        let request = self.request(endpoint: "/alliances/active", method: "GET")
        let response: AllianceListResponse = try await execute(request)
        return response
    }
    
    /// Get pending alliance proposals (sent and received)
    func getPendingAlliances() async throws -> PendingAlliancesResponse {
        let request = self.request(endpoint: "/alliances/pending", method: "GET")
        let response: PendingAlliancesResponse = try await execute(request)
        return response
    }
}

// MARK: - Alliance Models

struct AllianceProposeResponse: Codable {
    let success: Bool
    let message: String
    let allianceId: Int
    let proposalExpiresAt: String
    
    enum CodingKeys: String, CodingKey {
        case success, message
        case allianceId = "alliance_id"
        case proposalExpiresAt = "proposal_expires_at"
    }
}

struct AllianceAcceptResponse: Codable {
    let success: Bool
    let message: String
    let allianceId: Int
    let expiresAt: String
    let benefits: [String]
    
    enum CodingKeys: String, CodingKey {
        case success, message, benefits
        case allianceId = "alliance_id"
        case expiresAt = "expires_at"
    }
}

struct AllianceDeclineResponse: Codable {
    let success: Bool
    let message: String
}

struct AllianceResponse: Codable, Identifiable {
    let id: Int
    let initiatorEmpireId: String
    let targetEmpireId: String
    let initiatorRulerId: Int
    let targetRulerId: Int?
    let initiatorRulerName: String
    let targetRulerName: String?
    let status: String
    let createdAt: String
    let proposalExpiresAt: String
    let acceptedAt: String?
    let expiresAt: String?
    let daysRemaining: Int
    let hoursToRespond: Int
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, status
        case initiatorEmpireId = "initiator_empire_id"
        case targetEmpireId = "target_empire_id"
        case initiatorRulerId = "initiator_ruler_id"
        case targetRulerId = "target_ruler_id"
        case initiatorRulerName = "initiator_ruler_name"
        case targetRulerName = "target_ruler_name"
        case createdAt = "created_at"
        case proposalExpiresAt = "proposal_expires_at"
        case acceptedAt = "accepted_at"
        case expiresAt = "expires_at"
        case daysRemaining = "days_remaining"
        case hoursToRespond = "hours_to_respond"
        case isActive = "is_active"
    }
}

struct AllianceListResponse: Codable {
    let alliances: [AllianceResponse]
    let count: Int
}

struct PendingAlliancesResponse: Codable {
    let sent: [AllianceResponse]
    let received: [AllianceResponse]
    let sentCount: Int
    let receivedCount: Int
    
    enum CodingKeys: String, CodingKey {
        case sent, received
        case sentCount = "sent_count"
        case receivedCount = "received_count"
    }
}

// MARK: - Pending Alliance Request (from action status)

struct PendingAllianceRequest: Codable, Identifiable {
    let id: Int
    let initiatorEmpireId: String
    let initiatorEmpireName: String
    let initiatorRulerName: String
    let hoursToRespond: Int
    let createdAt: String
    let proposalExpiresAt: String
    let acceptEndpoint: String
    let declineEndpoint: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case initiatorEmpireId = "initiator_empire_id"
        case initiatorEmpireName = "initiator_empire_name"
        case initiatorRulerName = "initiator_ruler_name"
        case hoursToRespond = "hours_to_respond"
        case createdAt = "created_at"
        case proposalExpiresAt = "proposal_expires_at"
        case acceptEndpoint = "accept_endpoint"
        case declineEndpoint = "decline_endpoint"
    }
}
