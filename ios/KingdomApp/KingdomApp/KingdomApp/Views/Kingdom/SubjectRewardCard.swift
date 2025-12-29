import SwiftUI

/// Card showing subject's merit score and estimated rewards
struct SubjectRewardCard: View {
    let kingdom: Kingdom
    let player: Player
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundColor(KingdomTheme.Colors.gold)
                Text("Subject Rewards")
                    .font(KingdomTheme.Typography.title3())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                if kingdom.subjectRewardRate == 0 {
                    Text("DISABLED")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(.red)
                } else {
                    Text("\(kingdom.subjectRewardRate)% Pool")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.gold)
                }
            }
            
            // Check eligibility
            let isEligible = player.isEligibleForRewards(inKingdom: kingdom.id, rulerId: kingdom.rulerId)
            
            if !isEligible {
                ineligibleView
            } else {
                eligibleView
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(KingdomTheme.Colors.parchmentLight)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        )
    }
    
    @ViewBuilder
    private var ineligibleView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Not Eligible")
                .font(KingdomTheme.Typography.headline())
                .foregroundColor(.red)
            
            let rep = player.getKingdomReputation(kingdom.id)
            
            if player.playerId == kingdom.rulerId {
                Text("Rulers manage treasury directly")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            } else if rep < 50 {
                Text("Need 50+ reputation (currently \(rep))")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            } else {
                Text("Must check in within last 7 days")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
        }
    }
    
    @ViewBuilder
    private var eligibleView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Merit Score Breakdown
            let merit = player.calculateMeritScore(inKingdom: kingdom.id)
            let rep = player.getKingdomReputation(kingdom.id)
            let skillTotal = player.attackPower + player.defensePower + player.leadership + player.buildingSkill
            let repPoints = rep
            let skillPoints = Int(Double(skillTotal) * 0.5)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Merit Score: \(merit)")
                    .font(KingdomTheme.Typography.headline())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                HStack {
                    Text("├─ Reputation: \(rep)")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    Text("(×1.0) = \(repPoints)")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.gold)
                }
                
                HStack {
                    Text("└─ Skills: \(skillTotal)")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    Text("(×0.5) = \(skillPoints)")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.gold)
                }
            }
            
            Divider()
                .background(KingdomTheme.Colors.inkLight)
            
            // Estimated Daily Reward
            if kingdom.subjectRewardRate > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Daily Pool:")
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        Text("\(kingdom.dailyRewardPool)g")
                            .font(KingdomTheme.Typography.body())
                            .foregroundColor(KingdomTheme.Colors.gold)
                    }
                    
                    Text("Your estimated share: ~\(kingdom.dailyRewardPool)g/day")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .italic()
                    
                    Text("(In multiplayer, share based on merit vs other subjects)")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            
            // Last Reward Received
            if let lastReward = player.lastRewardReceived,
               player.lastRewardAmount > 0 {
                Divider()
                    .background(KingdomTheme.Colors.inkLight)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Reward:")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    HStack {
                        Text("+\(player.lastRewardAmount)g")
                            .font(KingdomTheme.Typography.body())
                            .foregroundColor(KingdomTheme.Colors.gold)
                        
                        Text(timeAgoString(from: lastReward))
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    
                    Text("Total lifetime: \(player.totalRewardsReceived)g")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
        }
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

