import SwiftUI

// MARK: - Catch Box
// Persistent display at top showing session fish tally
// Animates "+1" when fish is caught, shows pet fish if dropped

struct CatchBox: View {
    let meatCount: Int
    let fishCaught: Int
    let petFishDropped: Bool
    
    // Animation state
    @State private var showPlusOne: Bool = false
    @State private var plusOneOffset: CGFloat = 0
    @State private var plusOneOpacity: Double = 1
    @State private var lastFishCount: Int = 0
    
    var body: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            // Fish caught tally
            ZStack {
                HStack(spacing: 8) {
                    Image(systemName: "fish.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.royalBlue)
                    
                    Text("\(fishCaught)")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("caught")
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.parchmentLight,
                    cornerRadius: 12,
                    borderWidth: 2.5
                )
                
                // "+1" animation overlay
                if showPlusOne {
                    Text("+1")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                        .offset(y: plusOneOffset)
                        .opacity(plusOneOpacity)
                }
            }
            
            // Meat earned tally
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
                
                Text("\(meatCount)")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("meat")
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .brutalistBadge(
                backgroundColor: KingdomTheme.Colors.parchmentLight,
                cornerRadius: 12,
                borderWidth: 2.5
            )
            
            Spacer()
            
            // Pet fish (rare drop!)
            if petFishDropped {
                HStack(spacing: 6) {
                    Image(systemName: "fish.circle.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.0, green: 0.9, blue: 0.9),
                                    Color(red: 0.0, green: 0.6, blue: 0.8)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: KingdomTheme.Colors.gold.opacity(0.5), radius: 4)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.gold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.parchmentRich,
                    cornerRadius: 12,
                    borderWidth: 2.5
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.5).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .padding(.horizontal, KingdomTheme.Spacing.large)
        .padding(.vertical, KingdomTheme.Spacing.medium)
        .background(KingdomTheme.Colors.parchment.opacity(0.95))
        .onChange(of: fishCaught) { oldValue, newValue in
            if newValue > oldValue {
                triggerPlusOneAnimation()
            }
            lastFishCount = newValue
        }
        .onAppear {
            lastFishCount = fishCaught
        }
    }
    
    private func triggerPlusOneAnimation() {
        // Reset
        showPlusOne = true
        plusOneOffset = 0
        plusOneOpacity = 1
        
        // Animate up and fade - slower, more satisfying
        withAnimation(.easeOut(duration: 1.2)) {
            plusOneOffset = -35
            plusOneOpacity = 0
        }
        
        // Hide after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            showPlusOne = false
            plusOneOffset = 0
            plusOneOpacity = 1
        }
    }
}

// MARK: - Compact Catch Box
// Smaller version for tight spaces

struct CompactCatchBox: View {
    let meatCount: Int
    let fishCaught: Int
    let petFishDropped: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Meat
            Label("\(meatCount)", systemImage: "flame.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(KingdomTheme.Colors.buttonDanger)
            
            // Fish
            Label("\(fishCaught)", systemImage: "fish.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(KingdomTheme.Colors.royalBlue)
            
            // Pet fish indicator
            if petFishDropped {
                Image(systemName: "fish.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.0, green: 0.9, blue: 0.9),
                                Color(red: 0.0, green: 0.6, blue: 0.8)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .brutalistBadge(
            backgroundColor: KingdomTheme.Colors.parchmentLight,
            cornerRadius: 8,
            borderWidth: 2
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        CatchBox(
            meatCount: 12,
            fishCaught: 5,
            petFishDropped: false
        )
        
        CatchBox(
            meatCount: 25,
            fishCaught: 8,
            petFishDropped: true
        )
        
        CompactCatchBox(
            meatCount: 12,
            fishCaught: 5,
            petFishDropped: true
        )
    }
    .padding()
    .background(KingdomTheme.Colors.parchment)
}
