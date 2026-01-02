import SwiftUI

/// Reusable component for selecting and viewing tiers with consistent styling
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
        VStack(spacing: 16) {
            // Tier pills - visual tier browser
            HStack(spacing: 12) {
                ForEach(1...maxTier, id: \.self) { tier in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTier = tier
                        }
                    }) {
                        VStack(spacing: 4) {
                            // Tier indicator
                            ZStack {
                                Circle()
                                    .fill(tierColor(tier))
                                    .frame(width: 44, height: 44)
                                
                                if tier == currentTier && showCurrentBadge {
                                    Circle()
                                        .stroke(KingdomTheme.Colors.inkMedium, lineWidth: 3)
                                        .frame(width: 44, height: 44)
                                }
                                
                                Text("\(tier)")
                                    .font(.system(.body, design: .rounded).bold())
                                    .foregroundColor(.white)
                            }
                            
                            // Status text
                            Text(statusText(tier))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(statusColor(tier))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            
            // Content for selected tier
            content(selectedTier)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        }
        .padding()
        .background(KingdomTheme.Colors.parchmentLight)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KingdomTheme.Colors.inkDark.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func tierColor(_ tier: Int) -> Color {
        if tier <= currentTier {
            return KingdomTheme.Colors.inkMedium
        } else if tier == selectedTier {
            return KingdomTheme.Colors.buttonPrimary
        } else {
            return KingdomTheme.Colors.inkDark.opacity(0.3)
        }
    }
    
    private func statusText(_ tier: Int) -> String {
        if tier < currentTier {
            return "Past"
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
            return KingdomTheme.Colors.inkDark.opacity(0.5)
        }
    }
}



