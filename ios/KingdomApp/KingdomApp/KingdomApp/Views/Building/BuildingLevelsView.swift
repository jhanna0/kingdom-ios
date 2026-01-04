import SwiftUI

/// View to see all building levels at once with brutalist styling
struct BuildingLevelsView: View {
    let buildingName: String
    let icon: String
    let currentLevel: Int
    let maxLevel: Int
    let benefitForLevel: (Int) -> String
    let costForLevel: (Int) -> Int
    let detailedBenefits: ((Int) -> [String])?
    let accentColor: Color?
    @Environment(\.dismiss) var dismiss
    @State private var selectedLevel: Int = 1
    
    var body: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.large) {
                // Level selector with picker
                TierSelectorCard(
                    currentTier: currentLevel,
                    maxTier: maxLevel,
                    selectedTier: $selectedLevel,
                    accentColor: accentColor ?? KingdomTheme.Colors.royalPurple
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
            selectedLevel = currentLevel > 0 ? currentLevel : 1
        }
    }
    
    private func levelContent(level: Int) -> some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            // Level header
            HStack(spacing: KingdomTheme.Spacing.medium) {
                Image(systemName: icon)
                    .font(FontStyles.iconLarge)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .brutalistBadge(
                        backgroundColor: levelColor(level),
                        cornerRadius: 10,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(buildingName) Level \(level)")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(level <= currentLevel ? "Built" : "Not Built")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(level <= currentLevel ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.inkLight)
                }
                
                Spacer()
                
                if level <= currentLevel {
                    Text("Active")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.black)
                                    .offset(x: 1, y: 1)
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(KingdomTheme.Colors.inkMedium)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.black, lineWidth: 1.5)
                                    )
                            }
                        )
                }
            }
            
            Rectangle()
                .fill((accentColor ?? KingdomTheme.Colors.royalPurple).opacity(0.3))
                .frame(height: 2)
            
            // Benefits
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                sectionHeader(icon: "star.fill", title: "Benefits")
                
                if let detailedBenefits = detailedBenefits {
                    ForEach(detailedBenefits(level), id: \.self) { benefit in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: level <= currentLevel ? "checkmark.circle.fill" : "lock.circle.fill")
                                .font(FontStyles.iconSmall)
                                .foregroundColor(level <= currentLevel ? (accentColor ?? KingdomTheme.Colors.royalPurple) : KingdomTheme.Colors.inkDark.opacity(0.3))
                                .frame(width: 20)
                            
                            Text(benefit)
                                .font(FontStyles.bodySmall)
                                .foregroundColor(level <= currentLevel ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.inkMedium)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: level <= currentLevel ? "checkmark.circle.fill" : "lock.circle.fill")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(level <= currentLevel ? (accentColor ?? KingdomTheme.Colors.royalPurple) : KingdomTheme.Colors.inkDark.opacity(0.3))
                            .frame(width: 20)
                        
                        Text(benefitForLevel(level))
                            .font(FontStyles.bodySmall)
                            .foregroundColor(level <= currentLevel ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.inkMedium)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            
            Rectangle()
                .fill((accentColor ?? KingdomTheme.Colors.royalPurple).opacity(0.3))
                .frame(height: 2)
            
            // Cost
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                sectionHeader(icon: "dollarsign.circle.fill", title: "Upgrade Cost")
                
                HStack {
                    Image(systemName: "g.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(KingdomTheme.Colors.goldLight)
                        .frame(width: 20)
                    
                    Text("\(costForLevel(level)) Gold")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Spacer()
                    
                    Text("From Treasury")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            
            // Status indicator - MapHUD style
            if level <= currentLevel {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Built")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black)
                            .offset(x: 2, y: 2)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(KingdomTheme.Colors.inkMedium)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.black, lineWidth: 2)
                            )
                    }
                )
            } else if level > currentLevel + 1 {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .medium))
                    Text("Complete Level \(currentLevel + 1) first")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black)
                            .offset(x: 2, y: 2)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(KingdomTheme.Colors.parchmentLight)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.black, lineWidth: 2)
                            )
                    }
                )
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Available to Build")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black)
                            .offset(x: 2, y: 2)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(KingdomTheme.Colors.parchment)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.black, lineWidth: 2)
                            )
                    }
                )
            }
        }
    }
    
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(FontStyles.iconSmall)
                .foregroundColor((accentColor ?? KingdomTheme.Colors.royalPurple).opacity(0.5))
            Text(title)
                .font(FontStyles.bodyMediumBold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
    }
    
    private func levelColor(_ level: Int) -> Color {
        let color = accentColor ?? KingdomTheme.Colors.royalPurple
        if level <= currentLevel {
            return color
        } else if level == currentLevel + 1 {
            return color.opacity(0.7)
        } else {
            return color.opacity(0.3)
        }
    }
}
