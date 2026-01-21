import SwiftUI

/// Overlay shown when an event is triggered during the march
struct MarchEventOverlay: View {
    @ObservedObject var viewModel: MarchViewModel
    @State private var showContent: Bool = false
    
    var body: some View {
        if let event = viewModel.currentEvent {
            VStack(spacing: 0) {
                // Drag handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)
                
                // Content with staggered appearance
                VStack(spacing: 16) {
                    // Header
                    eventHeader(event: event)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                    
                    // Stats row
                    statsRow(event: event)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 15)
                    
                    // Probability bar
                    probabilityBar(event: event)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 10)
                    
                    // Result display (if rolled)
                    if let outcome = viewModel.lastRollOutcome {
                        resultDisplay(event: event, outcome: outcome)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Faith blessing display
                    if let blessing = viewModel.faithBlessing {
                        blessingDisplay(blessing: blessing)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Action/continue button
                    if viewModel.lastRollOutcome == nil {
                        actionButton(event: event)
                            .opacity(showContent ? 1 : 0)
                            .scaleEffect(showContent ? 1 : 0.9)
                    } else {
                        continueButton
                            .opacity(showContent ? 1 : 0)
                            .scaleEffect(showContent ? 1 : 0.95)
                    }
                }
                .padding(20)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showContent)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.lastRollOutcome != nil)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(KingdomTheme.Colors.parchmentLight)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: -5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.black, lineWidth: 3)
            )
            .onAppear {
                // Stagger the content appearance
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation {
                        showContent = true
                    }
                }
            }
            .onDisappear {
                showContent = false
            }
        }
    }
    
    // MARK: - Header
    
    private func eventHeader(event: MarchEvent) -> some View {
        HStack(spacing: 12) {
            // Event icon
            Image(systemName: event.type.icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(event.type.color)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black, lineWidth: 2)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.type.displayName.uppercased())
                    .font(.system(size: 16, weight: .black, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("Uses \(SkillConfig.get(event.type.skillType).displayName) skill")
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Stats Row
    
    private func statsRow(event: MarchEvent) -> some View {
        let skillConfig = SkillConfig.get(event.type.skillType)
        let skillLevel = viewModel.getSkillLevel(for: event.type)
        
        return HStack(spacing: 12) {
            // Skill level
            statChip(
                label: skillConfig.displayName.prefix(3).uppercased(),
                value: "\(skillLevel)",
                icon: skillConfig.icon,
                color: skillConfig.color
            )
            
            // Hit chance
            statChip(
                label: "HIT",
                value: "\(viewModel.currentHitChance)%",
                icon: "scope",
                color: hitChanceColor
            )
            
            // Critical chance
            statChip(
                label: "CRIT",
                value: "\(viewModel.currentCritChance)%",
                icon: "star.fill",
                color: KingdomTheme.Colors.imperialGold
            )
        }
    }
    
    private var hitChanceColor: Color {
        let chance = viewModel.currentHitChance
        if chance >= 70 { return KingdomTheme.Colors.buttonSuccess }
        if chance >= 50 { return KingdomTheme.Colors.buttonWarning }
        return KingdomTheme.Colors.buttonDanger
    }
    
    private func statChip(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Text(value)
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.white.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Probability Bar
    
    private func probabilityBar(event: MarchEvent) -> some View {
        VStack(spacing: 4) {
            // Label
            HStack {
                Text(viewModel.isRolling ? "ROLLING..." : "ODDS")
                    .font(.system(size: 10, weight: .bold, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Spacer()
                
                if viewModel.isRolling {
                    Text("\(viewModel.lastRollValue)")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
            }
            
            // Bar
            GeometryReader { geo in
                let missWidth = geo.size.width * CGFloat(viewModel.missChance) / 100.0
                let hitWidth = geo.size.width * CGFloat(viewModel.currentHitChance - viewModel.currentCritChance) / 100.0
                let critWidth = geo.size.width * CGFloat(viewModel.currentCritChance) / 100.0
                
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        // Critical section (gold) - low rolls
                        Rectangle()
                            .fill(KingdomTheme.Colors.imperialGold)
                            .frame(width: critWidth)
                            .overlay(
                                Text("CRIT")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.black)
                            )
                        
                        // Hit section (green)
                        Rectangle()
                            .fill(KingdomTheme.Colors.buttonSuccess.opacity(0.8))
                            .frame(width: hitWidth)
                            .overlay(
                                Text("HIT")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        
                        // Miss section (gray) - high rolls
                        Rectangle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: missWidth)
                            .overlay(
                                Text("MISS")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.black, lineWidth: 2)
                    )
                    
                    // Roll marker
                    if viewModel.isRolling || viewModel.lastRollOutcome != nil {
                        let markerX = geo.size.width * CGFloat(viewModel.rollMarkerValue) / 100.0
                        
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 1, x: 1, y: 1)
                            .position(x: max(10, min(geo.size.width - 10, markerX)), y: -8)
                            .animation(.linear(duration: 1.6), value: viewModel.rollMarkerValue)
                    }
                }
            }
            .frame(height: 28)
        }
    }
    
    // MARK: - Result Display
    
    private func resultDisplay(event: MarchEvent, outcome: MarchRollOutcome) -> some View {
        VStack(spacing: 8) {
            // Outcome badge
            Text(outcome.displayName)
                .font(.system(size: 14, weight: .black, design: .serif))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(outcome.color)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Message
            Text(messageForOutcome(event: event, outcome: outcome))
                .font(.system(size: 12, weight: .medium, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
            
            // Reward/penalty
            if outcome != .miss {
                let gain = outcome == .critical ? event.type.baseSoldiersGained * 2 : event.type.baseSoldiersGained
                if gain > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 12))
                        Text("+\(gain) soldiers")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                }
            } else if event.type.soldiersLostOnFail > 0 && !viewModel.hasShieldBuff {
                HStack(spacing: 4) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 12))
                    Text("-\(event.type.soldiersLostOnFail) soldiers")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(KingdomTheme.Colors.buttonDanger)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func messageForOutcome(event: MarchEvent, outcome: MarchRollOutcome) -> String {
        switch outcome {
        case .critical: return event.type.criticalMessage
        case .hit: return event.type.successMessage
        case .miss: return viewModel.hasShieldBuff ? "Shield absorbed the blow!" : event.type.failureMessage
        }
    }
    
    // MARK: - Blessing Display
    
    private func blessingDisplay(blessing: FaithBlessing) -> some View {
        HStack(spacing: 12) {
            Image(systemName: blessing.icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(blessing.displayName)
                    .font(.system(size: 12, weight: .black, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                Text(blessing.description)
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.2)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.purple.opacity(0.5), lineWidth: 2)
        )
    }
    
    // MARK: - Action Button
    
    private func actionButton(event: MarchEvent) -> some View {
        Button {
            Task {
                await viewModel.performRoll()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: event.type.icon)
                    .font(.system(size: 18, weight: .bold))
                Text(event.type.actionText)
                    .font(.system(size: 16, weight: .black, design: .serif))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(event.type.color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black, lineWidth: 3)
            )
            .shadow(color: .black.opacity(0.3), radius: 0, x: 3, y: 3)
        }
        .disabled(viewModel.isRolling)
    }

    private var continueButton: some View {
        Button {
            viewModel.continueAfterEvent()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                Text(continueLabel)
                    .font(.system(size: 14, weight: .black, design: .serif))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(viewModel.canContinueAfterResult ? KingdomTheme.Colors.buttonPrimary : Color.gray.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black, lineWidth: 3)
            )
            .shadow(color: .black.opacity(0.3), radius: 0, x: 3, y: 3)
        }
        .disabled(!viewModel.canContinueAfterResult)
    }

    private var continueLabel: String {
        if !viewModel.canContinueAfterResult {
            return "RESOLVING..."
        }
        return viewModel.requiresManualContinue ? "PUSH THROUGH" : "CONTINUE"
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            
            MarchEventOverlay(viewModel: {
                let vm = MarchViewModel()
                vm.currentEvent = MarchEvent(type: .brokenBridge, distance: 100)
                return vm
            }())
        }
    }
}
