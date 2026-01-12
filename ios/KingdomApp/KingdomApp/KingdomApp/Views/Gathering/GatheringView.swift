import SwiftUI

// MARK: - Floating Number View (self-contained animation)

private struct FloatingNumberView: View {
    let amount: Int
    let color: Color
    let onComplete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1.0
    
    var body: some View {
        Text("+\(amount)")
            .font(FontStyles.resultMedium)
            .foregroundColor(color)
            .offset(x: 100, y: -120 + offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) {
                    offset = -60
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onComplete()
                }
            }
    }
}

// MARK: - Floating Number Model

private struct FloatingNumber: Identifiable {
    let id = UUID()
    let amount: Int
    let color: Color
}

// MARK: - Gathering View

struct GatheringView: View {
    let initialResource: String
    
    @StateObject private var viewModel = GatheringViewModel()
    @Environment(\.dismiss) private var dismiss
    
    init(initialResource: String = "wood") {
        self.initialResource = initialResource
    }
    
    // Animation state
    @State private var floatingNumbers: [FloatingNumber] = []
    @State private var iconColor: Color? = nil  // nil = use base color
    
    var body: some View {
        ZStack {
            // Background
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Nav bar
                navBar
                
                // Simple counter at top
                counterDisplay
                    .padding(.top, KingdomTheme.Spacing.xLarge)
                
                Spacer()
                
                // Big tappable icon with floating numbers
                ZStack {
                    gatherButton
                    
                    // Floating results to top-right of icon
                    ForEach(floatingNumbers) { floating in
                        FloatingNumberView(
                            amount: floating.amount,
                            color: floating.color
                        ) {
                            floatingNumbers.removeAll { $0.id == floating.id }
                        }
                    }
                }
                
                Spacer()
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .task {
            viewModel.selectResource(initialResource)
            await viewModel.loadConfig()
        }
    }
    
    // MARK: - Nav Bar
    
    private var navBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(FontStyles.iconTiny)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .frame(width: 36, height: 36)
                    .background(KingdomTheme.Colors.parchmentDark.opacity(0.5))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text("Gather \(viewModel.resourceName)")
                .font(FontStyles.headingLarge)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Spacer()
            
            // Invisible spacer for centering
            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, KingdomTheme.Spacing.medium)
        .padding(.vertical, KingdomTheme.Spacing.medium)
    }
    
    // MARK: - Counter Display
    
    private var counterDisplay: some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.resourceIcon)
                .font(FontStyles.iconSmall)
                .foregroundColor(baseResourceColor)
            
            Text("\(viewModel.sessionGathered)")
                .font(FontStyles.resultSmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
        .padding(.horizontal, KingdomTheme.Spacing.large)
        .padding(.vertical, KingdomTheme.Spacing.small)
        .background(KingdomTheme.Colors.parchmentLight)
        .cornerRadius(KingdomTheme.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: KingdomTheme.CornerRadius.large)
                .stroke(KingdomTheme.Colors.border.opacity(0.5), lineWidth: KingdomTheme.BorderWidth.thin)
        )
    }
    
    // MARK: - Gather Button
    
    private var gatherButton: some View {
        Image(systemName: viewModel.resourceIcon)
            .font(.system(size: 180, weight: .bold))
            .foregroundColor(iconColor ?? baseResourceColor)
            .shadow(color: KingdomTheme.Colors.inkDark.opacity(0.2), radius: 8, x: 4, y: 6)
            .animation(nil, value: iconColor)
            .contentShape(Rectangle())
            .onTapGesture {
                if viewModel.canGather {
                    Task {
                        await performGather()
                    }
                } else {
                    showCooldownFeedback()
                }
            }
    }
    
    // MARK: - Helpers
    
    private var baseResourceColor: Color {
        switch viewModel.selectedResource {
        case "wood":
            return KingdomTheme.Colors.buttonPrimary
        case "iron":
            return KingdomTheme.Colors.disabled
        default:
            return KingdomTheme.Colors.inkMedium
        }
    }
    
    private func performGather() async {
        await viewModel.gather()
        
        guard let result = viewModel.lastResult else { return }
        
        iconColor = result.tierColor
        
        if let haptic = result.haptic {
            let style: UIImpactFeedbackGenerator.FeedbackStyle = haptic == "heavy" ? .heavy : .medium
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
        
        spawnFloatingNumber(amount: result.amount, color: result.tierColor)
    }
    
    private func showCooldownFeedback() {
        iconColor = KingdomTheme.Colors.inkDark
        spawnFloatingNumber(amount: 0, color: KingdomTheme.Colors.inkDark)
    }
    
    private func spawnFloatingNumber(amount: Int, color: Color) {
        floatingNumbers.append(FloatingNumber(amount: amount, color: color))
    }
}

// MARK: - Preview

#Preview("Wood") {
    NavigationStack {
        GatheringView(initialResource: "wood")
    }
}

#Preview("Iron") {
    NavigationStack {
        GatheringView(initialResource: "iron")
    }
}
