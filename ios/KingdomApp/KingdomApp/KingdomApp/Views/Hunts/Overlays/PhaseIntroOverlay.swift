import SwiftUI

// MARK: - Phase Intro Overlay
// Full-screen intro shown at the start of each hunt phase
// Uses brutalist styling - NO transparent/pulsing effects

struct PhaseIntroOverlay: View {
    let phase: HuntPhase
    let config: HuntConfigResponse?
    let onBegin: () -> Void
    
    @State private var iconScale: CGFloat = 0.5
    @State private var textOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Solid parchment background - NO transparency
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            // Decorative border pattern
            VStack {
                decorativeBorder
                Spacer()
                decorativeBorder
            }
            .ignoresSafeArea()
            
            VStack(spacing: KingdomTheme.Spacing.xxLarge) {
                Spacer()
                
                // Phase icon with brutalist badge styling
                ZStack {
                    // Offset shadow
                    Circle()
                        .fill(Color.black)
                        .frame(width: 144, height: 144)
                        .offset(x: 4, y: 4)
                    
                    // Main circle - SOLID parchment base, then colored border
                    Circle()
                        .fill(KingdomTheme.Colors.parchmentLight)
                        .frame(width: 140, height: 140)
                        .overlay(
                            Circle()
                                .stroke(phaseColor, lineWidth: 4)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 3)
                        )
                    
                    Image(systemName: phase.icon)
                        .font(.system(size: 60, weight: .medium))
                        .foregroundColor(phaseColor)
                }
                .scaleEffect(iconScale)
                
                VStack(spacing: 12) {
                    Text(phase.displayName.uppercased())
                        .font(.system(size: 36, weight: .black, design: .serif))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .tracking(4)
                    
                    Text(phaseDescription)
                        .font(KingdomTheme.Typography.body())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .opacity(textOpacity)
                
                if phase == .track, let animals = config?.animals {
                    possibleCreaturesPreview(animals: animals)
                        .opacity(textOpacity)
                }
                
                Spacer()
                
                // Begin button - brutalist style
                Button {
                    onBegin()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                        Text("BEGIN")
                            .font(.system(size: 22, weight: .black))
                            .tracking(2)
                    }
                }
                .buttonStyle(.brutalist(backgroundColor: phaseColor, foregroundColor: .white))
                .opacity(buttonOpacity)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                iconScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                textOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.6)) {
                buttonOpacity = 1.0
            }
        }
    }
    
    @ViewBuilder
    private func possibleCreaturesPreview(animals: [HuntAnimalConfig]) -> some View {
        VStack(spacing: 8) {
            Text("Possible Finds:")
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            HStack(spacing: 12) {
                ForEach(animals.sorted { $0.tier < $1.tier }, id: \.id) { animal in
                    VStack(spacing: 4) {
                        Text(animal.icon)
                            .font(.system(size: 28))
                        
                        // Tier stars
                        HStack(spacing: 1) {
                            ForEach(0..<max(1, animal.tier + 1), id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 6))
                                    .foregroundColor(KingdomTheme.Colors.gold)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .offset(x: 2, y: 2)
                RoundedRectangle(cornerRadius: 12)
                    .fill(KingdomTheme.Colors.parchmentLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
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
    
    private var decorativeBorder: some View {
        HStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { _ in
                Image(systemName: "diamond.fill")
                    .font(.caption2)
                    .foregroundColor(KingdomTheme.Colors.border.opacity(0.4))
            }
        }
        .padding(.vertical, 12)
    }
}
