import SwiftUI

/// Kingdom marker with flying activity icons that trickle out when players are active
/// For kingdoms with rulers, generates fake activity to show the kingdom is "alive"
struct KingdomMarkerWithActivity: View {
    let kingdom: Kingdom
    let homeKingdomId: String?
    let playerId: Int
    var markerScale: CGFloat = 1.0  // Scale factor based on territory size
    
    // Flying icons state
    @State private var flyingIcons: [FlyingIconData] = []
    @State private var activityTimer: Timer?
    
    // Activity generation configuration
    private let minInterval: TimeInterval = 0.4   // Minimum seconds between activities
    private let maxInterval: TimeInterval = 1.5   // Maximum seconds between activities
    private let maxFlyingIcons: Int = 8           // Allow more simultaneous icons
    
    // Activity types with their icon and color sources
    // Uses SkillConfig for skills, ActionIconHelper for actions
    private struct ActivityType {
        let icon: String
        let color: Color
        
        // Skill-based activities (use SkillConfig)
        static let attack = ActivityType(
            icon: SkillConfig.get("attack").icon,
            color: SkillConfig.get("attack").color
        )
        static let defense = ActivityType(
            icon: SkillConfig.get("defense").icon,
            color: SkillConfig.get("defense").color
        )
        static let leadership = ActivityType(
            icon: SkillConfig.get("leadership").icon,
            color: SkillConfig.get("leadership").color
        )
        static let building = ActivityType(
            icon: SkillConfig.get("building").icon,
            color: SkillConfig.get("building").color
        )
        static let intelligence = ActivityType(
            icon: SkillConfig.get("intelligence").icon,
            color: SkillConfig.get("intelligence").color
        )
        static let science = ActivityType(
            icon: SkillConfig.get("science").icon,
            color: SkillConfig.get("science").color
        )
        static let faith = ActivityType(
            icon: SkillConfig.get("faith").icon,
            color: SkillConfig.get("faith").color
        )
        
        // Action-based activities (use ActionIconHelper)
        static let farm = ActivityType(
            icon: ActionIconHelper.icon(for: "farm"),
            color: ActionIconHelper.actionColor(for: "farm")
        )
        static let patrol = ActivityType(
            icon: ActionIconHelper.icon(for: "patrol"),
            color: ActionIconHelper.actionColor(for: "patrol")
        )
        static let craft = ActivityType(
            icon: ActionIconHelper.icon(for: "craft"),
            color: ActionIconHelper.actionColor(for: "craft")
        )
        static let sabotage = ActivityType(
            icon: ActionIconHelper.icon(for: "sabotage"),
            color: ActionIconHelper.actionColor(for: "sabotage")
        )
    }
    
    private static let allActivities: [ActivityType] = [
        // Skills (training)
        .attack,
        .defense,
        .leadership,
        .building,
        .intelligence,
        .science,
        .faith,
        // Actions
        .farm,
        .patrol,
        .craft,
        .sabotage
    ]
    
    /// Only generate activity for kingdoms that have a ruler
    private var shouldShowActivity: Bool {
        return !kingdom.isUnclaimed
    }
    
    var body: some View {
        ZStack {
            // Flying icons layer (behind and around the marker)
            ForEach(flyingIcons) { iconData in
                FlyingActivityIcon(
                    icon: iconData.icon,
                    color: iconData.color,
                    angle: iconData.angle,
                    onComplete: {
                        removeIcon(id: iconData.id)
                    }
                )
            }
            
            // The actual kingdom marker
            KingdomMarker(
                kingdom: kingdom,
                homeKingdomId: homeKingdomId,
                playerId: playerId,
                markerScale: markerScale
            )
        }
        .onAppear {
            startActivityGeneration()
        }
        .onDisappear {
            stopActivityGeneration()
        }
        .onChange(of: kingdom.isUnclaimed) { _, newValue in
            // Start/stop activity when kingdom claim status changes
            if newValue {
                stopActivityGeneration()
            } else {
                startActivityGeneration()
            }
        }
    }
    
    // MARK: - Fake Activity Generation
    
    private func startActivityGeneration() {
        guard shouldShowActivity else { return }
        
        // Schedule first activity after a random delay
        scheduleNextActivity()
    }
    
    private func stopActivityGeneration() {
        activityTimer?.invalidate()
        activityTimer = nil
    }
    
    private func scheduleNextActivity() {
        guard shouldShowActivity else { return }
        
        // Random interval between activities
        let interval = Double.random(in: minInterval...maxInterval)
        
        activityTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            Task { @MainActor in
                spawnRandomActivity()
                scheduleNextActivity()  // Schedule the next one
            }
        }
    }
    
    private func spawnRandomActivity() {
        // Don't spawn too many at once
        guard flyingIcons.count < maxFlyingIcons else { return }
        
        // Pick a random activity
        guard let activity = Self.allActivities.randomElement() else { return }
        
        // Random angle for variety (full 360°)
        let angle = Double.random(in: 0..<360)
        
        let iconData = FlyingIconData(
            icon: activity.icon,
            color: activity.color,
            angle: angle
        )
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            flyingIcons.append(iconData)
        }
    }
    
    private func removeIcon(id: UUID) {
        flyingIcons.removeAll { $0.id == id }
    }
}
