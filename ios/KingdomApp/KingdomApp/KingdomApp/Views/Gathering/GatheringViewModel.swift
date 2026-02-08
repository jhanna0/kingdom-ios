import Foundation
import SwiftUI
import Combine

// MARK: - Tunable Constants

private let kGatherCooldownSeconds: TimeInterval = 1.0

// MARK: - Gathering View Model

@MainActor
class GatheringViewModel: ObservableObject {
    
    // MARK: - State
    
    @Published var config: GatherConfigResponse?
    @Published var isLoading = false
    @Published var error: String?
    
    // Current resource being gathered
    @Published var selectedResource: String = "wood"
    
    // Last gather result (for display)
    @Published var lastResult: GatherResponse?
    
    // Running totals (keyed by resource id)
    @Published var resourceTotals: [String: Int] = [:]
    
    // Cooldown state
    @Published var isOnCooldown = false
    
    // Animation triggers
    @Published var showResultAnimation = false
    @Published var resultAnimationAmount: Int = 0
    @Published var resultAnimationColor: Color = .gray
    
    // Session stats
    @Published var sessionGathered: Int = 0
    @Published var sessionTaps: Int = 0
    
    // Exhausted state (daily limit reached)
    @Published var isExhausted: Bool = false
    @Published var exhaustedMessage: String = ""
    
    private let apiService = KingdomAPIService.shared
    
    // MARK: - Computed Properties
    
    /// Get the config for the currently selected resource
    var currentResourceConfig: GatherResourceConfig? {
        config?.resources.first { $0.id == selectedResource }
    }
    
    var currentTotal: Int {
        resourceTotals[selectedResource] ?? 0
    }
    
    var resourceIcon: String {
        currentResourceConfig?.icon ?? "questionmark"
    }
    
    var resourceName: String {
        currentResourceConfig?.name ?? selectedResource.capitalized
    }
    
    var visualType: String {
        currentResourceConfig?.visualType ?? (selectedResource == "wood" ? "tree" : "rock")
    }
    
    var actionVerb: String {
        currentResourceConfig?.actionVerb ?? (selectedResource == "wood" ? "Chop" : "Mine")
    }
    
    var canGather: Bool {
        !isOnCooldown && !isLoading
    }
    
    // MARK: - API Methods
    
    func loadConfig() async {
        do {
            config = try await apiService.actions.getGatherConfig()
        } catch {
            self.error = "Failed to load config: \(error.localizedDescription)"
        }
    }
    
    /// Perform a gather action
    func gather() async {
        guard canGather else { return }
        
        // Start cooldown immediately
        startCooldown()
        sessionTaps += 1
        
        do {
            let response = try await apiService.actions.gatherResource(resourceType: selectedResource)
            
            // Check if exhausted (daily limit reached)
            if response.exhausted == true {
                isExhausted = true
                exhaustedMessage = response.exhaustedMessage ?? "You've gathered all available resources for today."
                
                // Schedule notification for when the resource resets
                if let resetSeconds = response.resetSeconds, resetSeconds > 0 {
                    Task {
                        await NotificationManager.shared.scheduleResourceResetNotification(
                            resourceType: response.resourceType,
                            secondsUntilReset: resetSeconds
                        )
                    }
                }
                return
            }
            
            // Update state
            lastResult = response
            
            // Update totals for this resource
            resourceTotals[selectedResource] = response.newTotal
            
            // Update session stats
            sessionGathered += response.amount
            
            // Trigger animation
            triggerResultAnimation(amount: response.amount, color: response.tierColor)
            
        } catch {
            self.error = "Gather failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Cooldown Management
    
    private func startCooldown() {
        isOnCooldown = true
        
        Task {
            try? await Task.sleep(nanoseconds: UInt64(kGatherCooldownSeconds * 1_000_000_000))
            isOnCooldown = false
        }
    }
    
    // MARK: - Animation
    
    private func triggerResultAnimation(amount: Int, color: Color) {
        resultAnimationAmount = amount
        resultAnimationColor = color
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showResultAnimation = true
        }
        
        // Reset after animation
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            withAnimation {
                showResultAnimation = false
            }
        }
    }
    
    // MARK: - Resource Selection
    
    func selectResource(_ resource: String) {
        // Accept any resource string - validation happens on backend
        selectedResource = resource
        lastResult = nil
        showResultAnimation = false
    }
    
    // MARK: - Session Management
    
    func resetSession() {
        sessionGathered = 0
        sessionTaps = 0
        lastResult = nil
    }
}
