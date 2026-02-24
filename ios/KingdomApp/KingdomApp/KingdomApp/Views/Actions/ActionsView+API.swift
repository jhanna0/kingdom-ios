import SwiftUI

// MARK: - API Calls

extension ActionsView {
    
    // MARK: - Load Action Status
    
    func loadActionStatus(force: Bool = false, caller: String = #function, file: String = #file, line: Int = #line) async {
        print("🔍 loadActionStatus CALLED from \(file.split(separator: "/").last ?? ""):\(line) - \(caller)")
        print("   - isLoading: \(isLoading), force: \(force)")
        print("   - statusFetchedAt: \(statusFetchedAt?.description ?? "nil")")
        print("   - Time since last fetch: \(statusFetchedAt.map { Date().timeIntervalSince($0) } ?? -1) seconds")
        
        // Prevent duplicate requests if we just loaded (within 3 seconds) - UNLESS forced
        if !force, let lastFetch = statusFetchedAt, Date().timeIntervalSince(lastFetch) < 3 {
            print("⏭️ Skipping loadActionStatus - recent data exists")
            return
        }
        
        // Prevent concurrent requests
        guard !isLoading else {
            print("⏭️ Skipping loadActionStatus - already loading")
            return
        }
        
        isLoading = true
        print("📡 Making API call to /actions/status...")
        do {
            let status = try await KingdomAPIService.shared.actions.getActionStatus()
            print("✅ Got action status response")
            actionStatus = status
            statusFetchedAt = Date()
            print("✅ Set actionStatus and statusFetchedAt")
            
            await MainActor.run {
                viewModel.availableContracts = status.contracts.compactMap { apiContract in
                    // Convert per-action costs from API format
                    let perActionCosts = apiContract.per_action_costs?.map { apiCost in
                        ContractPerActionCost(
                            resource: apiCost.resource,
                            amount: apiCost.amount,
                            displayName: apiCost.display_name,
                            icon: apiCost.icon,
                            color: apiCost.color,
                            canAfford: apiCost.can_afford
                        )
                    }
                    
                    return Contract(
                        id: apiContract.id,
                        kingdomId: apiContract.kingdom_id,
                        kingdomName: apiContract.kingdom_name,
                        buildingType: apiContract.building_type,
                        buildingLevel: apiContract.building_level,
                        buildingBenefit: apiContract.building_benefit,
                        buildingIcon: apiContract.building_icon,
                        buildingDisplayName: apiContract.building_display_name,
                        basePopulation: apiContract.base_population,
                        baseHoursRequired: apiContract.base_hours_required,
                        workStartedAt: apiContract.work_started_at.flatMap { ISO8601DateFormatter().date(from: $0) },
                        totalActionsRequired: apiContract.total_actions_required,
                        actionsCompleted: apiContract.actions_completed,
                        actionContributions: apiContract.action_contributions,
                        constructionCost: apiContract.construction_cost ?? 0,
                        rewardPool: apiContract.reward_pool,
                        actionReward: apiContract.action_reward,
                        perActionCosts: perActionCosts,
                        canAfford: apiContract.can_afford,
                        endpoint: apiContract.endpoint,
                        createdBy: apiContract.created_by,
                        createdAt: ISO8601DateFormatter().date(from: apiContract.created_at) ?? Date(),
                        completedAt: apiContract.completed_at.flatMap { ISO8601DateFormatter().date(from: $0) },
                        status: Contract.ContractStatus(rawValue: apiContract.status) ?? .open
                    )
                }
            }
        } catch let error as APIError {
            print("❌ loadActionStatus error: \(error)")
            await MainActor.run {
                errorMessage = "Status Error: \(error.localizedDescription)"
                showError = true
            }
        } catch {
            print("❌ loadActionStatus error: \(error)")
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        isLoading = false
    }
    
    // MARK: - Perform Work
    
    func performWork(contractId: String) {
        Task {
            do {
                let previousGold = viewModel.player.gold
                let previousReputation = viewModel.player.reputation
                let previousExperience = viewModel.player.experience
                
                let response = try await KingdomAPIService.shared.actions.workOnContract(contractId: contractId)
                
                await loadActionStatus(force: true)
                await viewModel.refreshPlayerFromBackend()
                viewModel.refreshCooldown()
                
                // Schedule notification for cooldown completion
                await scheduleNotificationForCooldown(actionName: "Work", slot: actionStatus?.work.slot)
                
                await MainActor.run {
                    if let rewards = response.rewards {
                        currentReward = Reward(
                            goldReward: rewards.gold ?? 0,
                            reputationReward: rewards.reputation ?? 0,
                            experienceReward: rewards.experience ?? 0,
                            message: response.message,
                            previousGold: previousGold,
                            previousReputation: previousReputation,
                            previousExperience: previousExperience,
                            currentGold: viewModel.player.gold,
                            currentReputation: viewModel.player.reputation,
                            currentExperience: viewModel.player.experience
                        )
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            showReward = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    // MARK: - Perform Generic Work Action
    
    func performGenericWorkAction(endpoint: String) {
        Task {
            do {
                let response = try await KingdomAPIService.shared.actions.performGenericAction(endpoint: endpoint)
                
                await loadActionStatus(force: true)
                await viewModel.refreshPlayerFromBackend()
                viewModel.refreshCooldown()
                
                await scheduleNotificationForCooldown(actionName: "Work", slot: actionStatus?.work.slot)
                
                await MainActor.run {
                    actionResultSuccess = response.success
                    actionResultTitle = response.success ? "Progress!" : "Failed"
                    actionResultMessage = response.message
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showActionResult = true
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    // MARK: - Perform Training
    
    func performTraining(contractId: String) {
        Task {
            do {
                let previousExperience = viewModel.player.experience
                
                let response = try await KingdomAPIService.shared.actions.workOnTraining(contractId: contractId)
                
                await loadActionStatus(force: true)
                await viewModel.refreshPlayerFromBackend()
                viewModel.refreshCooldown()
                
                // Schedule notification for cooldown completion
                await scheduleNotificationForCooldown(actionName: "Training", slot: actionStatus?.training.slot)
                
                await MainActor.run {
                    if let rewards = response.rewards {
                        currentReward = Reward(
                            goldReward: 0,
                            reputationReward: 0,
                            experienceReward: rewards.experience ?? 0,
                            message: response.message,
                            previousGold: viewModel.player.gold,
                            previousReputation: viewModel.player.reputation,
                            previousExperience: previousExperience,
                            currentGold: viewModel.player.gold,
                            currentReputation: viewModel.player.reputation,
                            currentExperience: viewModel.player.experience
                        )
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            showReward = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    // MARK: - Perform Property Upgrade
    
    func performPropertyUpgrade(contract: PropertyUpgradeContract) {
        guard let endpoint = contract.endpoint else {
            errorMessage = "Action not available (no endpoint)"
            showError = true
            return
        }
        
        Task {
            do {
                let response = try await KingdomAPIService.shared.actions.performGenericAction(endpoint: endpoint)
                
                await loadActionStatus(force: true)
                await viewModel.refreshPlayerFromBackend()
                viewModel.refreshCooldown()
                
                // Schedule notification for cooldown completion
                await scheduleNotificationForCooldown(actionName: "Property Upgrade", slot: actionStatus?.work.slot)
                
                await MainActor.run {
                    currentReward = Reward(
                        goldReward: 0,
                        reputationReward: 0,
                        experienceReward: 0,
                        message: response.message,
                        previousGold: viewModel.player.gold,
                        previousReputation: viewModel.player.reputation,
                        previousExperience: viewModel.player.experience,
                        currentGold: viewModel.player.gold,
                        currentReputation: viewModel.player.reputation,
                        currentExperience: viewModel.player.experience
                    )
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showReward = true
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    // MARK: - Perform Workshop Work
    
    func performWorkshopWork(contract: WorkshopContract) {
        guard let endpoint = contract.endpoint else {
            errorMessage = "Action not available (no endpoint)"
            showError = true
            return
        }
        
        Task {
            do {
                let previousExperience = viewModel.player.experience
                
                let response = try await KingdomAPIService.shared.actions.performGenericAction(endpoint: endpoint)
                
                await loadActionStatus(force: true)
                await viewModel.refreshPlayerFromBackend()
                viewModel.refreshCooldown()
                
                // Schedule notification for cooldown completion
                await scheduleNotificationForCooldown(actionName: "Workshop", slot: actionStatus?.crafting.slot)
                
                await MainActor.run {
                    if let rewards = response.rewards {
                        currentReward = Reward(
                            goldReward: 0,
                            reputationReward: 0,
                            experienceReward: rewards.experience ?? 0,
                            message: response.message,
                            previousGold: viewModel.player.gold,
                            previousReputation: viewModel.player.reputation,
                            previousExperience: previousExperience,
                            currentGold: viewModel.player.gold,
                            currentReputation: viewModel.player.reputation,
                            currentExperience: viewModel.player.experience
                        )
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            showReward = true
                        }
                    } else {
                        actionResultSuccess = response.success
                        actionResultTitle = response.success ? "Progress!" : "Failed"
                        actionResultMessage = response.message
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            showActionResult = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    // MARK: - Perform Generic Action
    
    /// FULLY DYNAMIC ACTION HANDLER
    /// Backend provides complete endpoint with all params - we just POST to it!
    func performGenericAction(action: ActionStatus) {
        guard let endpoint = action.endpoint else {
            errorMessage = "Action not available (no endpoint)"
            showError = true
            return
        }
        
        Task {
            do {
                let previousGold = viewModel.player.gold
                let previousReputation = viewModel.player.reputation
                let previousExperience = viewModel.player.experience
                
                let response = try await KingdomAPIService.shared.actions.performGenericAction(endpoint: endpoint)
                
                await loadActionStatus(force: true)
                await viewModel.refreshPlayerFromBackend()
                viewModel.refreshCooldown()
                
                // Schedule notification for cooldown completion (use action's slot)
                await scheduleNotificationForCooldown(actionName: action.title ?? "Action", slot: action.slot)
                
                await MainActor.run {
                    // Check if this is a scout action - use special slot machine popup
                    let isScoutAction = endpoint.contains("scout") || action.actionType == "scout"
                    
                    if isScoutAction {
                        // Scout action - show slot machine popup
                        scoutResultSuccess = response.success
                        scoutResultTitle = response.success ? "Success!" : "Detected!"
                        scoutResultMessage = response.message
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            showScoutResult = true
                        }
                    } else if let rewards = response.rewards {
                        // Show reward popup for actions with rewards
                        currentReward = Reward(
                            goldReward: rewards.gold ?? 0,
                            reputationReward: rewards.reputation ?? 0,
                            experienceReward: rewards.experience ?? 0,
                            message: response.message,
                            previousGold: previousGold,
                            previousReputation: previousReputation,
                            previousExperience: previousExperience,
                            currentGold: viewModel.player.gold,
                            currentReputation: viewModel.player.reputation,
                            currentExperience: viewModel.player.experience
                        )
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            showReward = true
                        }
                    } else if !response.message.isEmpty {
                        // Show themed popup for actions without rewards
                        actionResultSuccess = response.success
                        actionResultTitle = response.success ? "Success!" : "Failed"
                        actionResultMessage = response.message
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            showActionResult = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}
