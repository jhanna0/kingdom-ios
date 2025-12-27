import SwiftUI

// MARK: - Contract Card
// Displays a contract in a list

struct ContractCard: View {
    let contract: Contract
    
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
                    
                    Text("\(contract.workCompleted) / \(contract.totalWorkRequired)")
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
            
            // Reward info
            HStack {
                Label("\(contract.rewardPool)g", systemImage: "crown.fill")
                    .font(KingdomTheme.Typography.body())
                    .foregroundColor(KingdomTheme.Colors.gold)
                
                Spacer()
                
                Label("\(contract.contributors.count)", systemImage: "person.2.fill")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            }
        }
        .padding(KingdomTheme.Spacing.large)
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
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
        case .expired: return KingdomTheme.Colors.inkLight
        }
    }
    
    var statusText: String {
        switch status {
        case .open: return "Open"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .expired: return "Expired"
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

