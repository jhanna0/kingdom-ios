import SwiftUI

// MARK: - Creature Reveal Overlay
// Dramatic reveal when a creature is found during tracking
// Uses brutalist styling - NO transparent pulsing effects

struct CreatureRevealOverlay: View {
    @ObservedObject var viewModel: HuntViewModel
    let onContinue: () -> Void
    
    @State private var creatureScale: CGFloat = 0.3
    @State private var creatureOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var starsAnimated: Bool = false
    
    var body: some View {
        ZStack {
            // Solid parchment background - NO transparency
            KingdomTheme.Colors.parchmentLight
                .ignoresSafeArea()
            
            // Decorative corner flourishes
            decorativeCorners
            
            VStack(spacing: KingdomTheme.Spacing.xLarge) {
                Spacer()
                
                // "FOUND!" banner
                Text("FOUND!")
                    .font(.system(size: 28, weight: .black, design: .serif))
                    .tracking(6)
                    .foregroundColor(tierColor)
                    .opacity(textOpacity)
                
                // DRAMATIC creature display with brutalist styling
                ZStack {
                    // Offset shadow
                    Circle()
                        .fill(Color.black)
                        .frame(width: 204, height: 204)
                        .offset(x: 6, y: 6)
                    
                    // Main circle background - SOLID parchment, no transparency!
                    Circle()
                        .fill(KingdomTheme.Colors.parchment)
                        .frame(width: 200, height: 200)
                        .overlay(
                            Circle()
                                .stroke(tierColor, lineWidth: 6)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 4)
                        )
                    
                    // THE CREATURE - BIG
                    Text(viewModel.hunt?.animal?.icon ?? "🎯")
                        .font(.system(size: 100))
                }
                .scaleEffect(creatureScale)
                .opacity(creatureOpacity)
                
                // Creature name with tier stars
                VStack(spacing: 16) {
                    Text(viewModel.hunt?.animal?.name ?? "Unknown")
                        .font(.system(size: 36, weight: .black, design: .serif))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    // Tier stars with animation
                    if let tier = viewModel.hunt?.animal?.tier {
                        HStack(spacing: 8) {
                            ForEach(0..<max(tier + 1, 1), id: \.self) { index in
                                Image(systemName: "star.fill")
                                    .font(.title2)
                                    .foregroundColor(KingdomTheme.Colors.gold)
                                    .scaleEffect(starsAnimated ? 1.0 : 0.0)
                                    .animation(
                                        .spring(response: 0.4, dampingFraction: 0.6)
                                            .delay(Double(index) * 0.1 + 0.8),
                                        value: starsAnimated
                                    )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black)
                                    .offset(x: 2, y: 2)
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(KingdomTheme.Colors.parchment)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                            }
                        )
                    }
                    
                    // Animal stats preview
                    if let animal = viewModel.hunt?.animal {
                        HStack(spacing: 16) {
                            CreatureStatBadge(icon: "heart.fill", value: "\(animal.hp ?? 1) HP", color: KingdomTheme.Colors.buttonDanger)
                            CreatureStatBadge(icon: "flame.fill", value: "\(animal.meat ?? 0) Meat", color: KingdomTheme.Colors.buttonSuccess)
                        }
                        
                        // Potential drops from backend - fully dynamic!
                        if let drops = animal.potential_drops, !drops.isEmpty {
                            HStack(spacing: 12) {
                                ForEach(drops) { drop in
                                    PotentialDropBadge(drop: drop)
                                }
                            }
                        }
                    }
                }
                .opacity(textOpacity)
                
                Spacer()
                
                // Continue button
                Button {
                    onContinue()
                } label: {
                    HStack(spacing: 8) {
                        Text("Begin the Hunt")
                            .font(FontStyles.headingSmall)
                        Image(systemName: "arrow.right")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.brutalist(backgroundColor: tierColor, foregroundColor: .white, fullWidth: true))
                .opacity(buttonOpacity)
                .padding(.bottom, 50)
            }
            .padding(.horizontal, KingdomTheme.Spacing.large)
        }
        .onAppear {
            animateEntrance()
        }
    }
    
    private func animateEntrance() {
        // Creature appears with spring animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.5).delay(0.2)) {
            creatureScale = 1.0
            creatureOpacity = 1.0
        }
        
        // Text fades in
        withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
            textOpacity = 1.0
        }
        
        // Stars animate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            starsAnimated = true
        }
        
        // Button appears last
        withAnimation(.easeOut(duration: 0.4).delay(1.2)) {
            buttonOpacity = 1.0
        }
    }
    
    private var tierColor: Color {
        guard let tier = viewModel.hunt?.animal?.tier else { return KingdomTheme.Colors.inkMedium }
        switch tier {
        case 0: return KingdomTheme.Colors.inkMedium
        case 1: return KingdomTheme.Colors.buttonSuccess
        case 2: return KingdomTheme.Colors.buttonWarning
        case 3: return KingdomTheme.Colors.buttonDanger
        case 4: return KingdomTheme.Colors.regalPurple
        default: return KingdomTheme.Colors.inkMedium
        }
    }
    
    private var decorativeCorners: some View {
        GeometryReader { geo in
            Group {
                // Top left
                Image(systemName: "leaf.fill")
                    .font(.system(size: 40))
                    .foregroundColor(tierColor.opacity(0.2))
                    .position(x: 40, y: 60)
                
                // Top right
                Image(systemName: "leaf.fill")
                    .font(.system(size: 40))
                    .foregroundColor(tierColor.opacity(0.2))
                    .rotationEffect(.degrees(90))
                    .position(x: geo.size.width - 40, y: 60)
                
                // Bottom left
                Image(systemName: "leaf.fill")
                    .font(.system(size: 40))
                    .foregroundColor(tierColor.opacity(0.2))
                    .rotationEffect(.degrees(-90))
                    .position(x: 40, y: geo.size.height - 60)
                
                // Bottom right
                Image(systemName: "leaf.fill")
                    .font(.system(size: 40))
                    .foregroundColor(tierColor.opacity(0.2))
                    .rotationEffect(.degrees(180))
                    .position(x: geo.size.width - 40, y: geo.size.height - 60)
            }
        }
    }
}

// MARK: - Creature Stat Badge
private struct CreatureStatBadge: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black)
                    .offset(x: 1, y: 1)
                RoundedRectangle(cornerRadius: 8)
                    .fill(KingdomTheme.Colors.parchment)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black, lineWidth: 1.5)
                    )
            }
        )
    }
}

// MARK: - Potential Drop Badge (fully dynamic from backend)
private struct PotentialDropBadge: View {
    let drop: PotentialDropInfo
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: drop.item_icon)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .brutalistBadge(
                    backgroundColor: badgeColor,
                    cornerRadius: 8,
                    shadowOffset: 2,
                    borderWidth: 2
                )
            
            Text(drop.item_name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .lineLimit(1)
            
            // Rarity label
            Text(drop.rarity?.uppercased() ?? "")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(badgeColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black)
                    .offset(x: 1, y: 1)
                RoundedRectangle(cornerRadius: 8)
                    .fill(KingdomTheme.Colors.parchment)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black, lineWidth: 1.5)
                    )
            }
        )
    }
    
    /// Color from backend config
    private var badgeColor: Color {
        guard let colorName = drop.item_color else { return .gray }
        switch colorName.lowercased() {
        case "orange": return .orange
        case "brown": return .brown
        case "purple": return KingdomTheme.Colors.regalPurple
        case "blue": return .blue
        case "green": return .green
        case "red": return .red
        case "gray", "grey": return .gray
        default: return .gray
        }
    }
}
