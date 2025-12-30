import SwiftUI

// MARK: - Sabotage Target Selection View

struct SabotageTargetSelectionView: View {
    let targets: SabotageTargetsResponse
    let onSabotage: (Int) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                KingdomTheme.Colors.parchment
                    .ignoresSafeArea()
                
                if targets.targets.isEmpty {
                    emptyStateView
                } else {
                    targetsListView
                }
            }
            .navigationTitle("Sabotage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: KingdomTheme.Spacing.large) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
            
            Text("No Active Contracts")
                .font(KingdomTheme.Typography.title2())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text(targets.message ?? "This kingdom has no active construction projects to sabotage.")
                .font(KingdomTheme.Typography.body())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Targets List
    
    private var targetsListView: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.large) {
                // Header Info
                headerCard
                
                // Warning
                if !targets.canSabotage {
                    warningBanner
                }
                
                // Target List
                Text("Select a Contract to Sabotage")
                    .font(KingdomTheme.Typography.headline())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                ForEach(targets.targets) { target in
                    SabotageTargetCard(
                        target: target,
                        canSabotage: targets.canSabotage,
                        onSelect: {
                            onSabotage(target.contractId)
                        }
                    )
                }
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Header Card
    
    private var headerCard: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sabotage Target")
                        .font(KingdomTheme.Typography.headline())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(targets.kingdom.name)
                        .font(KingdomTheme.Typography.body())
                        .foregroundColor(KingdomTheme.Colors.buttonDanger)
                }
                
                Spacer()
            }
            
            // Cost and Status
            HStack(spacing: KingdomTheme.Spacing.medium) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cost")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.caption)
                            .foregroundColor(KingdomTheme.Colors.gold)
                        
                        Text("\(targets.sabotageCost)g")
                            .font(KingdomTheme.Typography.body())
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                            .fontWeight(.semibold)
                    }
                }
                
                Divider()
                    .frame(height: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Gold")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Text("\(targets.goldAvailable)g")
                        .font(KingdomTheme.Typography.body())
                        .foregroundColor(targets.canSabotage ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
                        .fontWeight(.semibold)
                }
                
                Spacer()
            }
        }
        .padding()
        .parchmentCard(
            backgroundColor: KingdomTheme.Colors.parchmentLight,
            hasShadow: false
        )
        .padding(.horizontal)
    }
    
    // MARK: - Warning Banner
    
    private var warningBanner: some View {
        HStack(spacing: KingdomTheme.Spacing.small) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(KingdomTheme.Colors.buttonWarning)
            
            if !targets.cooldown.ready {
                Text("Sabotage on cooldown: \(formatSeconds(targets.cooldown.secondsRemaining))")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            } else if targets.goldAvailable < targets.sabotageCost {
                Text("Insufficient gold")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
        }
        .padding()
        .background(KingdomTheme.Colors.buttonWarning.opacity(0.1))
        .cornerRadius(KingdomTheme.CornerRadius.medium)
        .padding(.horizontal)
    }
    
    // MARK: - Helpers
    
    private func formatSeconds(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }
}

