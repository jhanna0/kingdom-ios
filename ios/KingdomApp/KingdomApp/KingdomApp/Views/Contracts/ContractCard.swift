import SwiftUI

// MARK: - Contract Card
// Displays a contract in a list

struct ContractCard: View {
    let contract: Contract
    var isPlayerWorking: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(contract.kingdomName)
                        .font(KingdomTheme.Typography.headline())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("\(contract.buildingType) - Level \(contract.buildingLevel)")
                        .font(KingdomTheme.Typography.subheadline())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
                
                StatusBadge(status: contract.status)
            }
            
            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Progress")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                    
                    Spacer()
                    
                    Text("\(Int(contract.progress * 100))%")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(KingdomTheme.Colors.parchmentDark)
                            .frame(height: 8)
                        
                        Rectangle()
                            .fill(KingdomTheme.Colors.gold)
                            .frame(width: geometry.size.width * contract.progress, height: 8)
                    }
                    .cornerRadius(4)
                }
                .frame(height: 8)
            }
            
            // Status badges
            HStack(spacing: KingdomTheme.Spacing.small) {
                if isPlayerWorking {
                    HStack(spacing: 4) {
                        Image(systemName: "hammer.fill")
                            .font(.caption2)
                        Text("Working")
                            .font(KingdomTheme.Typography.caption2())
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(KingdomTheme.Colors.buttonPrimary)
                    .cornerRadius(4)
                }
                
                if contract.workerCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                        Text("\(contract.workerCount) workers")
                            .font(KingdomTheme.Typography.caption2())
                    }
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(KingdomTheme.Colors.parchmentDark)
                    .cornerRadius(4)
                }
                
                // Time remaining
                if let hoursRemaining = contract.hoursRemaining {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                        Text(formatTime(hoursRemaining))
                            .font(KingdomTheme.Typography.caption2())
                    }
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(KingdomTheme.Colors.parchmentLight)
                    .cornerRadius(4)
                }
                
                Spacer()
            }
            
            // Reward info
            HStack {
                Label("\(contract.rewardPool)g total", systemImage: "crown.fill")
                    .font(KingdomTheme.Typography.body())
                    .foregroundColor(KingdomTheme.Colors.gold)
                
                Spacer()
                
                if contract.workerCount > 0 {
                    Text("\(contract.rewardPerWorker)g per worker")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
            }
        }
        .padding(KingdomTheme.Spacing.large)
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func formatTime(_ hours: Double) -> String {
        if hours < 1 {
            let minutes = Int(hours * 60)
            return "\(minutes)m"
        } else if hours < 24 {
            return String(format: "%.1fh", hours)
        } else {
            let days = Int(hours / 24)
            let remainingHours = Int(hours.truncatingRemainder(dividingBy: 24))
            return "\(days)d \(remainingHours)h"
        }
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let status: Contract.ContractStatus
    
    var badgeColor: Color {
        switch status {
        case .open: return KingdomTheme.Colors.buttonSuccess
        case .inProgress: return KingdomTheme.Colors.buttonWarning
        case .completed: return KingdomTheme.Colors.gold
        case .cancelled: return KingdomTheme.Colors.inkLight
        }
    }
    
    var statusText: String {
        switch status {
        case .open: return "Open"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var body: some View {
        Text(statusText)
            .font(KingdomTheme.Typography.caption())
            .fontWeight(.semibold)
            .foregroundColor(KingdomTheme.Colors.parchment)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor)
            .cornerRadius(KingdomTheme.CornerRadius.small)
    }
}

#Preview {
    VStack(spacing: 16) {
        ContractCard(contract: Contract.sample)
        ContractCard(contract: Contract.samples[1])
    }
    .padding()
    .parchmentBackground()
}

