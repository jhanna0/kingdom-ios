import SwiftUI

// MARK: - Active Contracts

extension KingdomInfoSheetView {
    
    // MARK: - Active Contract Section
    
    @ViewBuilder
    var activeContractSection: some View {
        if let contract = kingdom.activeContract {
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .font(FontStyles.iconSmall)
                        .foregroundColor(KingdomTheme.Colors.buttonWarning)
                    Text("Active Contract")
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    Spacer()
                    contractStatusBadge(isComplete: contract.isComplete)
                }
                
                contractDetails(contract: contract)
            }
            .padding(KingdomTheme.Spacing.medium)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Contract Status Badge
    
    private func contractStatusBadge(isComplete: Bool) -> some View {
        Group {
            if isComplete {
                Text("Complete")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSuccess, cornerRadius: 6, shadowOffset: 1, borderWidth: 1.5)
            } else {
                Text("In Progress")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonWarning, cornerRadius: 6, shadowOffset: 1, borderWidth: 1.5)
            }
        }
    }
    
    // MARK: - Contract Details
    
    private func contractDetails(contract: Contract) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "building.2.fill")
                    .font(FontStyles.iconMini)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Text("\(contract.buildingType) Level \(contract.buildingLevel)")
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            HStack(spacing: 8) {
                Label("\(contract.contributorCount) contributors", systemImage: "person.2.fill")
                    .font(FontStyles.labelTiny)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                
                Label("\(contract.rewardPool) pool", systemImage: "g.circle.fill")
                    .font(FontStyles.labelTiny)
                    .foregroundColor(KingdomTheme.Colors.goldLight)
            }
            
            // Progress bar
            if !contract.isComplete {
                contractProgressBar(progress: contract.progress)
            }
        }
    }
    
    // MARK: - Contract Progress Bar
    
    private func contractProgressBar(progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Progress")
                    .font(FontStyles.labelTiny)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                Spacer()
                Text(String(format: "%.0f%%", progress * 100))
                    .font(FontStyles.labelTiny)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(KingdomTheme.Colors.inkDark.opacity(0.1))
                        .frame(height: 6)
                        .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                    
                    Rectangle()
                        .fill(KingdomTheme.Colors.buttonWarning)
                        .frame(width: geometry.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}
