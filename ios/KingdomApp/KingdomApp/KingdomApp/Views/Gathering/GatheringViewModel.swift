import Foundation
import SwiftUI
import Combine

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
    
    // Running totals
    @Published var woodTotal: Int = 0
    @Published var ironTotal: Int = 0
    
    // Cooldown state (0.5s between taps)
    @Published var isOnCooldown = false
    private let cooldownDuration: TimeInterval = 0.5
    
    // Animation triggers
    @Published var showResultAnimation = false
    @Published var resultAnimationAmount: Int = 0
    @Published var resultAnimationColor: Color = .gray
    
    // Session stats
    @Published var sessionGathered: Int = 0
    @Published var sessionTaps: Int = 0
    
    private let apiService = KingdomAPIService.shared
    
    // MARK: - Computed Properties
    
    var currentTotal: Int {
        selectedResource == "wood" ? woodTotal : ironTotal
    }
    
    var resourceIcon: String {
        selectedResource == "wood" ? "tree.fill" : "mountain.2.fill"
    }
    
    var resourceName: String {
        selectedResource == "wood" ? "Wood" : "Iron"
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
            
            // Update state
            lastResult = response
            
            // Update totals
            if selectedResource == "wood" {
                woodTotal = response.newTotal
            } else {
                ironTotal = response.newTotal
            }
            
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
            try? await Task.sleep(nanoseconds: UInt64(cooldownDuration * 1_000_000_000))
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
        guard resource == "wood" || resource == "iron" else { return }
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
