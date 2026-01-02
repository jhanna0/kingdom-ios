import SwiftUI

/// Reusable component for selecting and viewing tiers with brutalist styling
struct TierSelectorCard<Content: View>: View {
    let currentTier: Int
    let maxTier: Int
    @Binding var selectedTier: Int
    let showCurrentBadge: Bool
    let content: (Int) -> Content
    
    init(
        currentTier: Int,
        maxTier: Int = 5,
        selectedTier: Binding<Int>,
        showCurrentBadge: Bool = true,
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self.currentTier = currentTier
        self.maxTier = maxTier
        self._selectedTier = selectedTier
        self.showCurrentBadge = showCurrentBadge
        self.content = content
    }
    
    var body: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            // Tier selector header
            HStack {
                Image(systemName: "list.number")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("Select Tier")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                if currentTier > 0 {
                    Text("Current: \(currentTier)")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Tier pills - brutalist style matching MapHUD
            HStack(spacing: 10) {
                ForEach(1...maxTier, id: \.self) { tier in
                    tierButton(tier: tier)
                }
            }
            .frame(maxWidth: .infinity)
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Content for selected tier
            content(selectedTier)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
    }
    
    private func tierButton(tier: Int) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTier = tier
            }
        }) {
            VStack(spacing: 6) {
                // Tier number badge - EXACT MapHUD style
                ZStack {
                    Text("\(tier)")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.black)
                                    .offset(x: 2, y: 2)
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(tierColor(tier))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                            }
                        )
                    
                    // Current tier checkmark
                    if tier == currentTier && showCurrentBadge {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.goldLight)
                            .offset(x: 16, y: -16)
                    }
                }
                
                // Status text
                Text(statusText(tier))
                    .font(FontStyles.labelTiny)
                    .foregroundColor(statusColor(tier))
            }
        }
        .buttonStyle(.plain)
    }
    
    private func tierColor(_ tier: Int) -> Color {
        if tier <= currentTier {
            return KingdomTheme.Colors.inkMedium
        } else if tier == selectedTier {
            return KingdomTheme.Colors.buttonPrimary
        } else {
            return KingdomTheme.Colors.inkLight
        }
    }
    
    private func statusText(_ tier: Int) -> String {
        if tier < currentTier {
            return "Done"
        } else if tier == currentTier {
            return "Current"
        } else if tier == currentTier + 1 {
            return "Next"
        } else {
            return "Locked"
        }
    }
    
    private func statusColor(_ tier: Int) -> Color {
        if tier <= currentTier {
            return KingdomTheme.Colors.inkMedium
        } else if tier == selectedTier {
            return KingdomTheme.Colors.buttonPrimary
        } else {
            return KingdomTheme.Colors.inkLight
        }
    }
}
