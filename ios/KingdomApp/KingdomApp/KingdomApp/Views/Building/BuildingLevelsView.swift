import SwiftUI

/// View to see all building levels at once
struct BuildingLevelsView: View {
    let buildingName: String
    let icon: String
    let currentLevel: Int
    let maxLevel: Int
    let benefitForLevel: (Int) -> String
    let costForLevel: (Int) -> Int
    let detailedBenefits: ((Int) -> [String])?
    @Environment(\.dismiss) var dismiss
    @State private var selectedLevel: Int = 1
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Level selector with picker
                TierSelectorCard(
                    currentTier: currentLevel,
                    maxTier: maxLevel,
                    selectedTier: $selectedLevel
                ) { level in
                    levelContent(level: level)
                }
            }
            .padding()
        }
        .background(KingdomTheme.Colors.parchment.ignoresSafeArea())
        .navigationTitle("All \(buildingName) Levels")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .onAppear {
            selectedLevel = currentLevel
        }
    }
    
    private func levelContent(level: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Level name
            Text("Level \(level)")
                .font(.headline)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            // Benefits
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "star.fill", title: "Benefits")
                
                if let detailedBenefits = detailedBenefits {
                    ForEach(detailedBenefits(level), id: \.self) { benefit in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: level <= currentLevel ? "checkmark.circle.fill" : "lock.circle.fill")
                                .font(.subheadline)
                                .foregroundColor(level <= currentLevel ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkDark.opacity(0.3))
                                .frame(width: 20)
                            
                            Text(benefit)
                                .font(.subheadline)
                                .foregroundColor(level <= currentLevel ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.inkMedium)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: level <= currentLevel ? "checkmark.circle.fill" : "lock.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(level <= currentLevel ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkDark.opacity(0.3))
                            .frame(width: 20)
                        
                        Text(benefitForLevel(level))
                            .font(.subheadline)
                            .foregroundColor(level <= currentLevel ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.inkMedium)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            
            Divider()
            
            // Cost
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "dollarsign.circle.fill", title: "Cost")
                
                HStack {
                    Image(systemName: "building.columns.fill")
                        .foregroundColor(KingdomTheme.Colors.gold)
                        .frame(width: 20)
                    Text("\(costForLevel(level)) Gold")
                        .font(.subheadline)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    Spacer()
                    Text("From Treasury")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            
            // Status
            if level <= currentLevel {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.subheadline)
                    Text("Unlocked")
                        .font(.subheadline.bold())
                }
                .foregroundColor(KingdomTheme.Colors.gold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(KingdomTheme.Colors.gold.opacity(0.1))
                .cornerRadius(10)
            } else if level > currentLevel + 1 {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.subheadline)
                    Text("Complete Level \(currentLevel + 1) first")
                        .font(.subheadline)
                }
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(KingdomTheme.Colors.inkDark.opacity(0.05))
                .cornerRadius(10)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.subheadline)
                    Text("Locked")
                        .font(.subheadline)
                }
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(KingdomTheme.Colors.inkDark.opacity(0.05))
                .cornerRadius(10)
            }
        }
    }
    
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(KingdomTheme.Colors.gold)
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
    }
}

