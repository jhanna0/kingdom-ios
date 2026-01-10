import SwiftUI

// MARK: - Phase Intro Overlay
// Full-screen intro shown at the start of each hunt phase
// Clean, dramatic styling with proper spacing

struct PhaseIntroOverlay: View {
    let phase: HuntPhase
    let config: HuntConfigResponse?
    let hunt: HuntSession?  // Need hunt to check if animal can drop rare
    let onBegin: () -> Void
    
    @State private var iconScale: CGFloat = 0.3
    @State private var contentOpacity: Double = 0
    @State private var buttonSlide: CGFloat = 60
    
    var body: some View {
        ZStack {
            // Solid parchment background
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // HERO: Phase icon with brutalist styling
                ZStack {
                    // Offset shadow
                    Circle()
                        .fill(Color.black)
                        .frame(width: 134, height: 134)
                        .offset(x: 4, y: 4)
                    
                    // Main circle
                    Circle()
                        .fill(KingdomTheme.Colors.parchmentLight)
                        .frame(width: 130, height: 130)
                        .overlay(
                            Circle()
                                .stroke(phaseColor, lineWidth: 4)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 3)
                        )
                    
                    Image(systemName: phase.icon)
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(phaseColor)
                }
                .scaleEffect(iconScale)
                
                // Phase name
                Text(phaseTitle.uppercased())
                    .font(.system(size: 36, weight: .black, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .tracking(4)
                    .padding(.top, 24)
                    .opacity(contentOpacity)
                
                // Phase description
                Text(phaseDescription)
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 10)
                    .opacity(contentOpacity)
                
                // Phase-specific content
                phaseSpecificContent
                    .padding(.top, 24)
                    .opacity(contentOpacity)
                
                Spacer()
                
                // BEGIN BUTTON
                Button {
                    onBegin()
                } label: {
                    HStack(spacing: 10) {
                        Text(buttonLabel)
                            .font(.system(size: 15, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.brutalist(backgroundColor: phaseColor, foregroundColor: .white, fullWidth: true))
                .padding(.horizontal, KingdomTheme.Spacing.large)
                .padding(.bottom, 40)
                .offset(y: buttonSlide)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                iconScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                contentOpacity = 1.0
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.3)) {
                buttonSlide = 0
            }
        }
    }
    
    // MARK: - Phase-Specific Content
    
    @ViewBuilder
    private var phaseSpecificContent: some View {
        switch phase {
        case .track:
            if let animals = config?.animals {
                creaturesCard(animals: animals)
            }
        case .strike:
            if let animal = config?.animals.first(where: { $0.name == "Deer" }) {
                // Just show a hint about the target
                targetHintCard
            } else {
                targetHintCard
            }
        case .blessing:
            blessingHintCard
        default:
            EmptyView()
        }
    }
    
    private func creaturesCard(animals: [HuntAnimalConfig]) -> some View {
        VStack(spacing: 12) {
            Text("POSSIBLE PREY")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            // Scrollable horizontal list of animals
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(animals.sorted { $0.tier < $1.tier }, id: \.id) { animal in
                        VStack(spacing: 4) {
                            Text(animal.icon)
                                .font(.system(size: 28))
                            
                            Text(animal.name)
                                .font(.system(size: 9, weight: .medium, design: .serif))
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                                .lineLimit(1)
                            
                            // Tier indicator
                            HStack(spacing: 1) {
                                ForEach(0..<max(1, animal.tier + 1), id: \.self) { _ in
                                    Circle()
                                        .fill(tierColor(animal.tier))
                                        .frame(width: 5, height: 5)
                                }
                            }
                        }
                        .frame(width: 54)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .offset(x: 3, y: 3)
                RoundedRectangle(cornerRadius: 12)
                    .fill(KingdomTheme.Colors.parchmentLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black, lineWidth: 2)
                    )
            }
        )
        .padding(.horizontal, KingdomTheme.Spacing.large)
    }
    
    private var targetHintCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "scope")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(phaseColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("AIM CAREFULLY")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                Text("Each shot shifts your odds")
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .offset(x: 3, y: 3)
                RoundedRectangle(cornerRadius: 12)
                    .fill(KingdomTheme.Colors.parchmentLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black, lineWidth: 2)
                    )
            }
        )
        .padding(.horizontal, KingdomTheme.Spacing.large)
    }
    
    private var blessingHintCard: some View {
        // Get rare drop info from backend (nil if animal can't drop rare)
        let rareDrop = hunt?.animal?.rare_drop
        
        return HStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(phaseColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(rareDrop != nil ? "RARE DROP CHANCE" : "SEEK BLESSING")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                Text("Prayers increase loot quality")
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
            
            // Show rare item badge from backend (same style as InventoryGridItem)
            if let drop = rareDrop {
                VStack(spacing: 4) {
                    Image(systemName: drop.item_icon)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .brutalistBadge(
                            backgroundColor: .brown,
                            cornerRadius: 8,
                            shadowOffset: 2,
                            borderWidth: 2
                        )
                    
                    Text(drop.item_name)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .offset(x: 3, y: 3)
                RoundedRectangle(cornerRadius: 12)
                    .fill(KingdomTheme.Colors.parchmentLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black, lineWidth: 2)
                    )
            }
        )
        .padding(.horizontal, KingdomTheme.Spacing.large)
    }
    
    // MARK: - Helpers
    
    private var phaseColor: Color {
        switch phase {
        case .track: return KingdomTheme.Colors.royalBlue
        case .strike: return KingdomTheme.Colors.buttonDanger
        case .blessing: return KingdomTheme.Colors.regalPurple
        default: return KingdomTheme.Colors.inkMedium
        }
    }
    
    private var phaseTitle: String {
        switch phase {
        case .track: return "Tracking"
        case .strike: return "The Hunt"
        case .blessing: return "Blessing"
        default: return phase.displayName
        }
    }
    
    private var phaseDescription: String {
        switch phase {
        case .track: return "Scout the wilderness to find prey"
        case .strike: return "Take aim and bring down your quarry"
        case .blessing: return "Pray for fortune on your spoils"
        default: return ""
        }
    }
    
    private var buttonLabel: String {
        switch phase {
        case .track: return "BEGIN TRACKING"
        case .strike: return "TAKE AIM"
        case .blessing: return "SEEK BLESSING"
        default: return "BEGIN"
        }
    }
    
    private func tierColor(_ tier: Int) -> Color {
        switch tier {
        case 0: return KingdomTheme.Colors.inkMedium
        case 1: return KingdomTheme.Colors.buttonSuccess
        case 2: return KingdomTheme.Colors.buttonWarning
        case 3: return KingdomTheme.Colors.buttonDanger
        case 4: return KingdomTheme.Colors.regalPurple
        default: return KingdomTheme.Colors.inkMedium
        }
    }
}
