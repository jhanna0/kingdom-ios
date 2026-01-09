import SwiftUI

// MARK: - Phase Intro Overlay
// Full-screen intro shown at the start of each hunt phase
// GAME STYLE - big, bold, dramatic!

struct PhaseIntroOverlay: View {
    let phase: HuntPhase
    let config: HuntConfigResponse?
    let onBegin: () -> Void
    
    @State private var iconScale: CGFloat = 0.3
    @State private var contentOpacity: Double = 0
    @State private var buttonSlide: CGFloat = 100
    
    var body: some View {
        ZStack {
            // Solid parchment background
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            // Main content - vertically centered
            VStack(spacing: 0) {
                Spacer()
                
                // HERO: Big phase icon - brutalist style
                ZStack {
                    // Offset shadow
                    Circle()
                        .fill(Color.black)
                        .frame(width: 164, height: 164)
                        .offset(x: KingdomTheme.Brutalist.offsetShadow, y: KingdomTheme.Brutalist.offsetShadow)
                    
                    // Main circle
                    Circle()
                        .fill(KingdomTheme.Colors.parchmentLight)
                        .frame(width: 160, height: 160)
                        .overlay(
                            Circle()
                                .stroke(phaseColor, lineWidth: 4)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: KingdomTheme.Brutalist.borderWidth)
                        )
                    
                    Image(systemName: phase.icon)
                        .font(.system(size: 70, weight: .bold))
                        .foregroundColor(phaseColor)
                }
                .scaleEffect(iconScale)
                
                // Phase name - BIG AND BOLD
                Text(phase.displayName.uppercased())
                    .font(.system(size: 42, weight: .black, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .tracking(6)
                    .padding(.top, 32)
                    .opacity(contentOpacity)
                
                // Phase description
                Text(phaseDescription)
                    .font(.system(size: 17, weight: .medium, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)
                    .padding(.top, 12)
                    .opacity(contentOpacity)
                
                // Possible creatures (track phase only)
                if phase == .track, let animals = config?.animals {
                    possibleCreaturesPreview(animals: animals)
                        .padding(.top, 28)
                        .opacity(contentOpacity)
                }
                
                Spacer()
                Spacer()
                
                // BEGIN BUTTON - slides up from bottom
                Button {
                    onBegin()
                } label: {
                    HStack(spacing: 12) {
                        Text("BEGIN \(phase.displayName.uppercased())")
                            .font(.system(size: 18, weight: .black))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                }
                .buttonStyle(.brutalist(backgroundColor: phaseColor, foregroundColor: .white, fullWidth: true))
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
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
    
    @ViewBuilder
    private func possibleCreaturesPreview(animals: [HuntAnimalConfig]) -> some View {
        VStack(spacing: 10) {
            Text("POSSIBLE CREATURES")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            HStack(spacing: 16) {
                ForEach(animals.sorted { $0.tier < $1.tier }, id: \.id) { animal in
                    VStack(spacing: 6) {
                        Text(animal.icon)
                            .font(.system(size: 36))
                        
                        // Tier stars
                        HStack(spacing: 2) {
                            ForEach(0..<max(1, animal.tier + 1), id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(KingdomTheme.Colors.gold)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black)
                    .offset(x: 3, y: 3)
                RoundedRectangle(cornerRadius: 14)
                    .fill(KingdomTheme.Colors.parchmentLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.black, lineWidth: 2)
                    )
            }
        )
    }
    
    private var phaseColor: Color {
        switch phase {
        case .track: return KingdomTheme.Colors.royalBlue
        case .strike: return KingdomTheme.Colors.buttonDanger
        case .blessing: return KingdomTheme.Colors.regalPurple
        default: return KingdomTheme.Colors.inkMedium
        }
    }
    
    private var phaseDescription: String {
        switch phase {
        case .track: return "Use your Intelligence to find animal tracks"
        case .strike: return "Use your Attack to land the killing blow"
        case .blessing: return "Use your Faith to bless the loot"
        default: return ""
        }
    }
}
