import Foundation
import SwiftUI
import CoreLocation

// MARK: - Request Models

struct TransferFundsRequest: Codable {
    let sourceKingdomId: String
    let targetKingdomId: String
    let amount: Int
    
    enum CodingKeys: String, CodingKey {
        case sourceKingdomId = "source_kingdom_id"
        case targetKingdomId = "target_kingdom_id"
        case amount
    }
}

struct TreasuryWithdrawRequest: Codable {
    let amount: Int
}

struct TreasuryDepositRequest: Codable {
    let amount: Int
}

// MARK: - Response Models

struct TreasuryLocationOption: Codable, Identifiable, Hashable {
    let id: String
    let type: String  // "personal", "current_kingdom", "other_kingdom"
    let label: String
    let icon: String
    let balance: Int
}

struct ActiveContractSummary: Codable {
    let id: Int
    let buildingType: String
    let buildingDisplayName: String
    let buildingIcon: String
    let targetLevel: Int
    let actionsCompleted: Int
    let actionsRequired: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case buildingType = "building_type"
        case buildingDisplayName = "building_display_name"
        case buildingIcon = "building_icon"
        case targetLevel = "target_level"
        case actionsCompleted = "actions_completed"
        case actionsRequired = "actions_required"
    }
    
    var progressPercent: CGFloat {
        guard actionsRequired > 0 else { return 1.0 }
        return CGFloat(actionsCompleted) / CGFloat(actionsRequired)
    }
}

struct EmpireKingdomSummary: Codable, Identifiable {
    let id: String
    let name: String
    let treasuryGold: Int
    let taxRate: Int
    let travelFee: Int
    let checkedInPlayers: Int
    let wallLevel: Int
    let vaultLevel: Int
    let isCapital: Bool
    let rulerStartedAt: String?
    let activeContract: ActiveContractSummary?
    let treasuryFromOptions: [TreasuryLocationOption]
    let treasuryToOptions: [TreasuryLocationOption]
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case treasuryGold = "treasury_gold"
        case taxRate = "tax_rate"
        case travelFee = "travel_fee"
        case checkedInPlayers = "checked_in_players"
        case wallLevel = "wall_level"
        case vaultLevel = "vault_level"
        case isCapital = "is_capital"
        case rulerStartedAt = "ruler_started_at"
        case activeContract = "active_contract"
        case treasuryFromOptions = "treasury_from_options"
        case treasuryToOptions = "treasury_to_options"
    }
}

struct ActiveWarSummary: Codable, Identifiable {
    var id: Int { battleId }
    let battleId: Int
    let type: String  // "attacking" or "defending"
    let targetKingdomId: String
    let targetKingdomName: String
    let attackingFromKingdomId: String?
    let attackingFromKingdomName: String?
    let initiatorName: String
    let pledgeEndTime: String
    let phase: String  // "pledge" or "battle"
    let attackerCount: Int
    let defenderCount: Int
    
    enum CodingKeys: String, CodingKey {
        case battleId = "battle_id"
        case type
        case targetKingdomId = "target_kingdom_id"
        case targetKingdomName = "target_kingdom_name"
        case attackingFromKingdomId = "attacking_from_kingdom_id"
        case attackingFromKingdomName = "attacking_from_kingdom_name"
        case initiatorName = "initiator_name"
        case pledgeEndTime = "pledge_end_time"
        case phase
        case attackerCount = "attacker_count"
        case defenderCount = "defender_count"
    }
}

struct EmpireAllianceSummary: Codable, Identifiable {
    var id: Int { allianceId }
    let allianceId: Int
    let alliedEmpireId: String
    let alliedEmpireName: String
    let alliedKingdomCount: Int
    let expiresAt: String
    let daysRemaining: Int
    
    enum CodingKeys: String, CodingKey {
        case allianceId = "alliance_id"
        case alliedEmpireId = "allied_empire_id"
        case alliedEmpireName = "allied_empire_name"
        case alliedKingdomCount = "allied_kingdom_count"
        case expiresAt = "expires_at"
        case daysRemaining = "days_remaining"
    }
}

// MARK: - Server-Driven UI Config Models

struct StatConfig: Codable {
    let id: String
    let label: String
    let icon: String
    let color: String  // Theme color name (e.g., "imperialGold", "inkMedium")
    let colorInactive: String?
    let format: String
    let suffix: String?
    
    enum CodingKeys: String, CodingKey {
        case id, label, icon, color, format, suffix
        case colorInactive = "color_inactive"
    }
    
    /// Get Color from theme name
    var swiftColor: Color {
        KingdomTheme.Colors.color(fromThemeName: color)
    }
    
    var swiftColorInactive: Color {
        if let inactive = colorInactive {
            return KingdomTheme.Colors.color(fromThemeName: inactive)
        }
        return swiftColor
    }
}

struct SectionConfig: Codable {
    let title: String
    let icon: String
    let color: String  // Theme color name
    let emptyMessage: String?
    
    enum CodingKeys: String, CodingKey {
        case title, icon, color
        case emptyMessage = "empty_message"
    }
    
    var swiftColor: Color {
        KingdomTheme.Colors.color(fromThemeName: color)
    }
}

struct KingdomActionConfig: Codable {
    let id: String
    let label: String
    let icon: String
    let color: String  // Theme color name
    
    var swiftColor: Color {
        KingdomTheme.Colors.color(fromThemeName: color)
    }
}

struct TreasuryActionConfig: Codable, Identifiable {
    let id: String
    let label: String
    let icon: String
    let description: String
    let source: String
    let target: String
    let requiresMultipleKingdoms: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, label, icon, description, source, target
        case requiresMultipleKingdoms = "requires_multiple_kingdoms"
    }
}

struct EmpireUIConfig: Codable {
    // Header
    let headerIcon: String
    let headerIconColor: String
    let subtitleTemplate: String
    
    // Stats
    let stats: [StatConfig]
    
    // Wars section
    let warsSection: SectionConfig
    let warsAttackingIcon: String
    let warsDefendingIcon: String
    let warsAttackingColor: String
    let warsDefendingColor: String
    
    // Alliances section
    let alliancesSection: SectionConfig
    let alliancesAllyIcon: String
    let alliancesDaysLabel: String
    let alliancesKingdomsLabel: String
    
    // Kingdoms section
    let kingdomsSection: SectionConfig
    let kingdomsCapitalBadge: String
    let kingdomsCapitalIcon: String
    let kingdomsCapitalColor: String
    
    // Kingdom card
    let kingdomStats: [StatConfig]
    let kingdomActions: [KingdomActionConfig]
    
    // Treasury management
    let treasuryAllowPersonal: Bool?
    let treasuryAllowTransfers: Bool?
    let treasuryActions: [TreasuryActionConfig]
    
    // Convenience getters with defaults
    var allowPersonalGold: Bool { treasuryAllowPersonal ?? true }
    var allowTransfers: Bool { treasuryAllowTransfers ?? true }
    let quickAmounts: [Int]
    let quickMaxLabel: String
    
    // Messages
    let noEmpireTitle: String
    let noEmpireSubtitle: String
    let noEmpireIcon: String
    let loadingMessage: String
    let errorTitle: String
    let errorRetry: String
    let transferNoKingdomsMessage: String
    
    enum CodingKeys: String, CodingKey {
        case headerIcon = "header_icon"
        case headerIconColor = "header_icon_color"
        case subtitleTemplate = "subtitle_template"
        case stats
        case warsSection = "wars_section"
        case warsAttackingIcon = "wars_attacking_icon"
        case warsDefendingIcon = "wars_defending_icon"
        case warsAttackingColor = "wars_attacking_color"
        case warsDefendingColor = "wars_defending_color"
        case alliancesSection = "alliances_section"
        case alliancesAllyIcon = "alliances_ally_icon"
        case alliancesDaysLabel = "alliances_days_label"
        case alliancesKingdomsLabel = "alliances_kingdoms_label"
        case kingdomsSection = "kingdoms_section"
        case kingdomsCapitalBadge = "kingdoms_capital_badge"
        case kingdomsCapitalIcon = "kingdoms_capital_icon"
        case kingdomsCapitalColor = "kingdoms_capital_color"
        case kingdomStats = "kingdom_stats"
        case kingdomActions = "kingdom_actions"
        case treasuryAllowPersonal = "treasury_allow_personal"
        case treasuryAllowTransfers = "treasury_allow_transfers"
        case treasuryActions = "treasury_actions"
        case quickAmounts = "quick_amounts"
        case quickMaxLabel = "quick_max_label"
        case noEmpireTitle = "no_empire_title"
        case noEmpireSubtitle = "no_empire_subtitle"
        case noEmpireIcon = "no_empire_icon"
        case loadingMessage = "loading_message"
        case errorTitle = "error_title"
        case errorRetry = "error_retry"
        case transferNoKingdomsMessage = "transfer_no_kingdoms_message"
    }
    
    /// Get color from theme name
    func color(_ themeName: String) -> Color {
        KingdomTheme.Colors.color(fromThemeName: themeName)
    }
    
    var headerSwiftColor: Color {
        KingdomTheme.Colors.color(fromThemeName: headerIconColor)
    }
    
    var warsAttackingSwiftColor: Color {
        KingdomTheme.Colors.color(fromThemeName: warsAttackingColor)
    }
    
    var warsDefendingSwiftColor: Color {
        KingdomTheme.Colors.color(fromThemeName: warsDefendingColor)
    }
    
    var kingdomsCapitalSwiftColor: Color {
        KingdomTheme.Colors.color(fromThemeName: kingdomsCapitalColor)
    }
}

struct EmpireOverviewResponse: Codable {
    let empireId: String
    let empireName: String
    let totalTreasury: Int
    let totalSubjects: Int
    let kingdomCount: Int
    let personalGold: Int
    let kingdoms: [EmpireKingdomSummary]
    let activeWars: [ActiveWarSummary]
    let warsAttacking: Int
    let warsDefending: Int
    let alliances: [EmpireAllianceSummary]
    let allianceCount: Int
    let uiConfig: EmpireUIConfig  // Server-driven UI config!
    
    enum CodingKeys: String, CodingKey {
        case empireId = "empire_id"
        case empireName = "empire_name"
        case totalTreasury = "total_treasury"
        case totalSubjects = "total_subjects"
        case kingdomCount = "kingdom_count"
        case personalGold = "personal_gold"
        case kingdoms
        case activeWars = "active_wars"
        case warsAttacking = "wars_attacking"
        case warsDefending = "wars_defending"
        case alliances
        case allianceCount = "alliance_count"
        case uiConfig = "ui_config"
    }
}

struct TransferFundsResponse: Codable {
    let success: Bool
    let message: String
    let amountTransferred: Int
    let sourceKingdomId: String
    let sourceKingdomName: String
    let sourceTreasuryRemaining: Int
    let targetKingdomId: String
    let targetKingdomName: String
    let targetTreasuryNew: Int
    
    enum CodingKeys: String, CodingKey {
        case success, message
        case amountTransferred = "amount_transferred"
        case sourceKingdomId = "source_kingdom_id"
        case sourceKingdomName = "source_kingdom_name"
        case sourceTreasuryRemaining = "source_treasury_remaining"
        case targetKingdomId = "target_kingdom_id"
        case targetKingdomName = "target_kingdom_name"
        case targetTreasuryNew = "target_treasury_new"
    }
}

struct TreasuryWithdrawResponse: Codable {
    let success: Bool
    let message: String
    let amountWithdrawn: Int
    let kingdomId: String
    let kingdomName: String
    let treasuryRemaining: Int
    let personalGoldNew: Int
    
    enum CodingKeys: String, CodingKey {
        case success, message
        case amountWithdrawn = "amount_withdrawn"
        case kingdomId = "kingdom_id"
        case kingdomName = "kingdom_name"
        case treasuryRemaining = "treasury_remaining"
        case personalGoldNew = "personal_gold_new"
    }
}

struct TreasuryDepositResponse: Codable {
    let success: Bool
    let message: String
    let amountDeposited: Int
    let kingdomId: String
    let kingdomName: String
    let treasuryNew: Int
    let personalGoldRemaining: Int
    
    enum CodingKeys: String, CodingKey {
        case success, message
        case amountDeposited = "amount_deposited"
        case kingdomId = "kingdom_id"
        case kingdomName = "kingdom_name"
        case treasuryNew = "treasury_new"
        case personalGoldRemaining = "personal_gold_remaining"
    }
}

// MARK: - Managed Kingdom Models (for Empire Management)

struct ManagedBuildingUpgradeCost: Codable, Hashable {
    let actionsRequired: Int
    let constructionCost: Int
    let canAfford: Bool
    
    enum CodingKeys: String, CodingKey {
        case actionsRequired = "actions_required"
        case constructionCost = "construction_cost"
        case canAfford = "can_afford"
    }
}

struct ManagedBuildingTierInfo: Codable {
    let tier: Int
    let name: String
    let benefit: String
    let description: String
    let perActionCosts: [[String: AnyCodable]]
    
    enum CodingKeys: String, CodingKey {
        case tier, name, benefit, description
        case perActionCosts = "per_action_costs"
    }
}

struct ManagedBuildingClickAction: Codable, Hashable {
    let type: String
    let resource: String?
    let exhausted: Bool
    let exhaustedMessage: String?
    let dailyLimit: Int?
    let gatheredToday: Int?
    let remainingToday: Int?
    
    enum CodingKeys: String, CodingKey {
        case type, resource, exhausted
        case exhaustedMessage = "exhausted_message"
        case dailyLimit = "daily_limit"
        case gatheredToday = "gathered_today"
        case remainingToday = "remaining_today"
    }
}

struct ManagedBuildingCatchupInfo: Codable, Hashable {
    let needsCatchup: Bool
    let canUse: Bool
    let actionsRequired: Int
    let actionsCompleted: Int
    let actionsRemaining: Int
    
    enum CodingKeys: String, CodingKey {
        case needsCatchup = "needs_catchup"
        case canUse = "can_use"
        case actionsRequired = "actions_required"
        case actionsCompleted = "actions_completed"
        case actionsRemaining = "actions_remaining"
    }
}

struct ManagedBuildingPermitInfo: Codable, Hashable {
    let canAccess: Bool
    let reason: String
    let isHometown: Bool
    let isAllied: Bool
    let needsPermit: Bool
    let hasValidPermit: Bool
    let permitExpiresAt: String?
    let permitMinutesRemaining: Int
    let hometownHasBuilding: Bool
    let hometownBuildingLevel: Int
    let hasActiveCatchup: Bool
    let canBuyPermit: Bool
    let permitCost: Int
    let permitDurationMinutes: Int
    
    enum CodingKeys: String, CodingKey {
        case canAccess = "can_access"
        case reason
        case isHometown = "is_hometown"
        case isAllied = "is_allied"
        case needsPermit = "needs_permit"
        case hasValidPermit = "has_valid_permit"
        case permitExpiresAt = "permit_expires_at"
        case permitMinutesRemaining = "permit_minutes_remaining"
        case hometownHasBuilding = "hometown_has_building"
        case hometownBuildingLevel = "hometown_building_level"
        case hasActiveCatchup = "has_active_catchup"
        case canBuyPermit = "can_buy_permit"
        case permitCost = "permit_cost"
        case permitDurationMinutes = "permit_duration_minutes"
    }
}

struct ManagedKingdomBuilding: Codable, Identifiable {
    var id: String { type }
    let type: String
    let displayName: String
    let icon: String
    let color: String
    let category: String
    let description: String
    let level: Int
    let maxLevel: Int
    let sortOrder: Int
    let upgradeCost: ManagedBuildingUpgradeCost?
    let clickAction: ManagedBuildingClickAction?
    let catchup: ManagedBuildingCatchupInfo?
    let permit: ManagedBuildingPermitInfo?
    let tierName: String
    let tierBenefit: String
    let allTiers: [ManagedBuildingTierInfo]
    
    enum CodingKeys: String, CodingKey {
        case type
        case displayName = "display_name"
        case icon, color, category, description, level
        case maxLevel = "max_level"
        case sortOrder = "sort_order"
        case upgradeCost = "upgrade_cost"
        case clickAction = "click_action"
        case catchup, permit
        case tierName = "tier_name"
        case tierBenefit = "tier_benefit"
        case allTiers = "all_tiers"
    }
}

struct ManagedKingdom: Codable, Identifiable {
    let id: String
    let name: String
    let rulerId: Int
    let rulerName: String
    let treasuryGold: Int
    let taxRate: Int
    let travelFee: Int
    let activeCitizens: Int
    let checkedInPlayers: Int
    let buildings: [ManagedKingdomBuilding]
    let isCapital: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case rulerId = "ruler_id"
        case rulerName = "ruler_name"
        case treasuryGold = "treasury_gold"
        case taxRate = "tax_rate"
        case travelFee = "travel_fee"
        case activeCitizens = "active_citizens"
        case checkedInPlayers = "checked_in_players"
        case buildings
        case isCapital = "is_capital"
    }
    
}

// MARK: - ManagedKingdom to Kingdom Conversion

extension ManagedKingdom {
    /// Convert to Kingdom for use with existing views
    func toKingdom() -> Kingdom? {
        let dummyTerritory = Territory.circular(
            center: .init(latitude: 0, longitude: 0),
            radiusMeters: 1000,
            osmId: id
        )
        
        guard var kingdom = Kingdom(
            name: name,
            rulerName: rulerName,
            rulerId: rulerId,
            territory: dummyTerritory,
            color: .bronze
        ) else { return nil }
        
        kingdom.treasuryGold = treasuryGold
        kingdom.taxRate = taxRate
        kingdom.travelFee = travelFee
        kingdom.activeCitizens = activeCitizens
        kingdom.checkedInPlayers = checkedInPlayers
        
        for b in buildings {
            kingdom.buildingLevels[b.type] = b.level
            
            if let cost = b.upgradeCost {
                kingdom.buildingUpgradeCosts[b.type] = BuildingUpgradeCost(
                    actionsRequired: cost.actionsRequired,
                    constructionCost: cost.constructionCost,
                    canAfford: cost.canAfford
                )
            }
            
            let allTiers = b.allTiers.map { tier in
                BuildingTierInfo(
                    tier: tier.tier,
                    name: tier.name,
                    benefit: tier.benefit,
                    tierDescription: tier.description,
                    perActionCosts: []
                )
            }
            
            var clickAction: BuildingClickAction? = nil
            if let ca = b.clickAction {
                clickAction = BuildingClickAction(
                    type: ca.type,
                    resource: ca.resource,
                    exhausted: ca.exhausted,
                    exhaustedMessage: ca.exhaustedMessage
                )
            }
            
            var upgradeCost: BuildingUpgradeCost? = nil
            if let uc = b.upgradeCost {
                upgradeCost = BuildingUpgradeCost(
                    actionsRequired: uc.actionsRequired,
                    constructionCost: uc.constructionCost,
                    canAfford: uc.canAfford
                )
            }
            
            kingdom.buildingMetadata[b.type] = BuildingMetadata(
                type: b.type,
                displayName: b.displayName,
                icon: b.icon,
                colorHex: b.color,
                category: b.category,
                description: b.description,
                level: b.level,
                maxLevel: b.maxLevel,
                sortOrder: b.sortOrder,
                upgradeCost: upgradeCost,
                clickAction: clickAction,
                catchup: nil,
                permit: nil,
                tierName: b.tierName,
                tierBenefit: b.tierBenefit,
                allTiers: allTiers
            )
        }
        
        return kingdom
    }
}

// MARK: - APIClient Extension

extension APIClient {
    
    // MARK: - Empire Operations
    
    /// Get full empire overview for the current ruler
    func getMyEmpire() async throws -> EmpireOverviewResponse {
        let request = self.request(endpoint: "/empire/my-empire", method: "GET")
        let response: EmpireOverviewResponse = try await execute(request)
        return response
    }
    
    /// Transfer funds between kingdoms you rule
    func transferFunds(sourceKingdomId: String, targetKingdomId: String, amount: Int) async throws -> TransferFundsResponse {
        let body = TransferFundsRequest(
            sourceKingdomId: sourceKingdomId,
            targetKingdomId: targetKingdomId,
            amount: amount
        )
        let request = try self.request(endpoint: "/empire/transfer-funds", method: "POST", body: body)
        let response: TransferFundsResponse = try await execute(request)
        return response
    }
    
    /// Withdraw gold from kingdom treasury to personal wallet
    func withdrawFromTreasury(kingdomId: String, amount: Int) async throws -> TreasuryWithdrawResponse {
        let body = TreasuryWithdrawRequest(amount: amount)
        let request = try self.request(endpoint: "/empire/kingdoms/\(kingdomId)/treasury/withdraw", method: "POST", body: body)
        let response: TreasuryWithdrawResponse = try await execute(request)
        return response
    }
    
    /// Deposit personal gold into kingdom treasury
    func depositToTreasury(kingdomId: String, amount: Int) async throws -> TreasuryDepositResponse {
        let body = TreasuryDepositRequest(amount: amount)
        let request = try self.request(endpoint: "/empire/kingdoms/\(kingdomId)/treasury/deposit", method: "POST", body: body)
        let response: TreasuryDepositResponse = try await execute(request)
        return response
    }
    
    /// Get full kingdom data for empire management (works from anywhere)
    func getManagedKingdom(kingdomId: String) async throws -> ManagedKingdom {
        let request = self.request(endpoint: "/empire/kingdoms/\(kingdomId)", method: "GET")
        let response: ManagedKingdom = try await execute(request)
        return response
    }
    
    /// Get empire overview with optional current kingdom sorting
    func getMyEmpire(currentKingdomId: String? = nil) async throws -> EmpireOverviewResponse {
        var endpoint = "/empire/my-empire"
        if let currentId = currentKingdomId {
            endpoint += "?current_kingdom_id=\(currentId)"
        }
        let request = self.request(endpoint: endpoint, method: "GET")
        let response: EmpireOverviewResponse = try await execute(request)
        return response
    }
}
