import SwiftUI

/// Card for rulers to manage subject reward distribution
struct RulerRewardManagementCard: View {
    @Binding var kingdom: Kingdom
    @ObservedObject var viewModel: MapViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(KingdomTheme.Colors.gold)
                Text("Subject Reward Pool")
                    .font(KingdomTheme.Typography.title3())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            
            // Distribution Rate Slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Distribution Rate:")
                        .font(KingdomTheme.Typography.body())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Spacer()
                    
                    Text("\(kingdom.subjectRewardRate)%")
                        .font(KingdomTheme.Typography.headline())
                        .foregroundColor(KingdomTheme.Colors.gold)
                }
                
                Slider(
                    value: Binding(
                        get: { Double(kingdom.subjectRewardRate) },
                        set: { newValue in
                            viewModel.setSubjectRewardRate(Int(newValue), for: kingdom.id)
                            // Update local binding
                            if let index = viewModel.kingdoms.firstIndex(where: { $0.id == kingdom.id }) {
                                kingdom = viewModel.kingdoms[index]
                            }
                        }
                    ),
                    in: 0...50,
                    step: 5
                )
                .accentColor(KingdomTheme.Colors.gold)
                
                HStack {
                    Text("Greedy (0%)")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Spacer()
                    
                    Text("Generous (50%)")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            
            Divider()
                .background(KingdomTheme.Colors.inkLight)
            
            // Pool Information
            VStack(alignment: .leading, spacing: 8) {
                statsRow(label: "Daily Income:", value: "\(kingdom.dailyIncome)g")
                statsRow(label: "Daily Pool:", value: "\(kingdom.dailyRewardPool)g", valueColor: KingdomTheme.Colors.gold)
                statsRow(label: "You Keep:", value: "\(kingdom.dailyIncome - kingdom.dailyRewardPool)g", valueColor: KingdomTheme.Colors.goldLight)
                
                if kingdom.pendingRewardPool > 0 {
                    Divider()
                        .background(KingdomTheme.Colors.inkLight)
                    
                    statsRow(label: "Pending Pool:", value: "\(kingdom.pendingRewardPool)g", valueColor: .orange)
                }
            }
            
            Divider()
                .background(KingdomTheme.Colors.inkLight)
            
            // Distribution Info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Eligible Subjects:")
                        .font(KingdomTheme.Typography.body())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    // In single-player, show if player is eligible
                    let playerEligible = viewModel.player.isEligibleForRewards(
                        inKingdom: kingdom.id,
                        rulerId: kingdom.rulerId
                    )
                    
                    Text(playerEligible ? "1" : "0")
                        .font(KingdomTheme.Typography.body())
                        .foregroundColor(KingdomTheme.Colors.parchment)
                    
                    Spacer()
                }
                
                if !kingdom.canDistributeRewards {
                    let timeUntilNext = getTimeUntilNextDistribution()
                    Text("Next auto-distribution: \(timeUntilNext)")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(KingdomTheme.Colors.gold)
                        Text("Auto-distribution ready")
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.gold)
                    }
                }
            }
            
            // Last Distribution Info
            if let lastDistribution = kingdom.distributionHistory.first {
                Divider()
                    .background(KingdomTheme.Colors.inkLight)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Distribution:")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Text("\(lastDistribution.totalPool)g to \(lastDistribution.recipientCount) subjects")
                        .font(KingdomTheme.Typography.body())
                        .foregroundColor(KingdomTheme.Colors.parchment)
                    
                    Text(timeAgoString(from: lastDistribution.timestamp))
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            
            // Distribution Statistics
            if kingdom.totalRewardsDistributed > 0 {
                Divider()
                    .background(KingdomTheme.Colors.inkLight)
                
                Text("Total distributed: \(kingdom.totalRewardsDistributed)g")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(KingdomTheme.Colors.parchmentLight)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        )
    }
    
    private func statsRow(label: String, value: String, valueColor: Color = KingdomTheme.Colors.parchment) -> some View {
        HStack {
            Text(label)
                .font(KingdomTheme.Typography.body())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            Spacer()
            
            Text(value)
                .font(KingdomTheme.Typography.body())
                .foregroundColor(valueColor)
        }
    }
    
    private func getTimeUntilNextDistribution() -> String {
        let elapsed = Date().timeIntervalSince(kingdom.lastRewardDistribution)
        let cooldown = 82800.0 // 23 hours
        let remaining = cooldown - elapsed
        
        if remaining <= 0 {
            return "Now!"
        }
        
        let hours = Int(remaining / 3600)
        let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
        
        return "\(hours)h \(minutes)m"
    }
    
    private func timeAgoString(from date: Date) -> String {
        let elapsed = Date().timeIntervalSince(date)
        let hours = Int(elapsed / 3600)
        
        if hours < 1 {
            let minutes = Int(elapsed / 60)
            return "\(minutes)m ago"
        } else if hours < 24 {
            return "\(hours)h ago"
        } else {
            let days = hours / 24
            return "\(days)d ago"
        }
    }
}

