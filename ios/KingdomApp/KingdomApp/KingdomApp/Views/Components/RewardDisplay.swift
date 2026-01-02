import SwiftUI

struct Reward {
    let goldReward: Int  // Amount earned (e.g., +50)
    let reputationReward: Int  // Amount earned (e.g., +10)
    let experienceReward: Int  // Amount earned (e.g., +10)
    let message: String
    let previousGold: Int  // Before action
    let previousReputation: Int  // Before action
    let previousExperience: Int  // Before action
    let currentGold: Int  // After action (from backend)
    let currentReputation: Int  // After action (from backend)
    let currentExperience: Int  // After action (from backend)
}

struct RewardDisplayView: View {
    let reward: Reward
    @Binding var isShowing: Bool
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    @State private var goldCounter: Int
    @State private var reputationCounter: Int
    @State private var experienceCounter: Int
    
    init(reward: Reward, isShowing: Binding<Bool>) {
        self.reward = reward
        self._isShowing = isShowing
        self._goldCounter = State(initialValue: reward.previousGold)
        self._reputationCounter = State(initialValue: reward.previousReputation)
        self._experienceCounter = State(initialValue: reward.previousExperience)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Main reward card
            VStack(spacing: 20) {
                // Success icon with brutalist style
                ZStack {
                    // Offset shadow
                    Circle()
                        .fill(Color.black)
                        .frame(width: 70, height: 70)
                        .offset(x: 3, y: 3)
                    
                    Circle()
                        .fill(KingdomTheme.Colors.gold)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 3)
                        )
                    
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .symbolEffect(.bounce, options: .speed(0.5))
                }
                .padding(.top, 8)
                
                // Message
                Text(reward.message)
                    .font(KingdomTheme.Typography.title3())
                    .fontWeight(.bold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Rewards with counter animation
                VStack(spacing: 16) {
                    // Gold counter (if earned)
                    if reward.goldReward > 0 {
                        AnimatedRewardCounter(
                            icon: "sparkles",
                            label: "Gold",
                            currentValue: goldCounter,
                            addedValue: reward.goldReward,
                            color: KingdomTheme.Colors.gold
                        )
                    }
                    
                    // Reputation counter (if earned)
                    if reward.reputationReward > 0 {
                        AnimatedRewardCounter(
                            icon: "star.fill",
                            label: "Reputation",
                            currentValue: reputationCounter,
                            addedValue: reward.reputationReward,
                            color: KingdomTheme.Colors.buttonWarning
                        )
                    }
                    
                    // Experience counter (if earned)
                    if reward.experienceReward > 0 {
                        AnimatedRewardCounter(
                            icon: "book.fill",
                            label: "Experience",
                            currentValue: experienceCounter,
                            addedValue: reward.experienceReward,
                            color: KingdomTheme.Colors.buttonSuccess
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                // Close button with brutalist style
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isShowing = false
                    }
                }) {
                    Text("Continue")
                }
                .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonPrimary, fullWidth: true))
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .padding(.vertical, 28)
            .background(
                ZStack {
                    // Offset shadow for brutalist effect
                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                        .fill(Color.black)
                        .offset(x: KingdomTheme.Brutalist.offsetShadow, y: KingdomTheme.Brutalist.offsetShadow)
                    
                    // Main card
                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                        .fill(KingdomTheme.Colors.parchmentLight)
                        .overlay(
                            RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                                .stroke(Color.black, lineWidth: KingdomTheme.Brutalist.borderWidth)
                        )
                }
            )
            // Soft shadow for extra depth
            .shadow(
                color: KingdomTheme.Shadows.brutalistSoft.color,
                radius: KingdomTheme.Shadows.brutalistSoft.radius,
                x: KingdomTheme.Shadows.brutalistSoft.x,
                y: KingdomTheme.Shadows.brutalistSoft.y
            )
            .padding(.horizontal, 32)
            .scaleEffect(scale)
            .opacity(opacity)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .opacity(opacity)
        )
        .onAppear {
            // Entrance animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // Animate counters after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                animateCounters()
            }
        }
    }
    
    private func animateCounters() {
        // Animate gold counter from previous to current
        let goldDiff = reward.currentGold - reward.previousGold
        let goldSteps = min(abs(goldDiff), 30) // Cap animation steps
        
        if goldSteps > 0 {
            let goldIncrement = goldDiff / goldSteps
            
            for step in 0...goldSteps {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.05) {
                    if step == goldSteps {
                        goldCounter = reward.currentGold
                    } else {
                        goldCounter = reward.previousGold + (goldIncrement * step)
                    }
                }
            }
        }
        
        // Animate reputation counter from previous to current
        let repDiff = reward.currentReputation - reward.previousReputation
        let repSteps = min(abs(repDiff), 20)
        
        if repSteps > 0 {
            let repIncrement = max(1, repDiff / repSteps)
            
            for step in 0...repSteps {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.06) {
                    if step == repSteps {
                        reputationCounter = reward.currentReputation
                    } else {
                        reputationCounter = reward.previousReputation + (repIncrement * step)
                    }
                }
            }
        }
        
        // Animate experience counter from previous to current
        let xpDiff = reward.currentExperience - reward.previousExperience
        let xpSteps = min(abs(xpDiff), 20)
        
        if xpSteps > 0 {
            let xpIncrement = max(1, xpDiff / xpSteps)
            
            for step in 0...xpSteps {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.06) {
                    if step == xpSteps {
                        experienceCounter = reward.currentExperience
                    } else {
                        experienceCounter = reward.previousExperience + (xpIncrement * step)
                    }
                }
            }
        }
    }
}

// MARK: - Animated Reward Counter

struct AnimatedRewardCounter: View {
    let icon: String
    let label: String
    let currentValue: Int
    let addedValue: Int
    let color: Color
    
    @State private var showAddition = false
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                
                Text(label)
                    .font(KingdomTheme.Typography.subheadline())
                    .fontWeight(.semibold)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Spacer()
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                // Current total
                Text("\(currentValue)")
                    .font(KingdomTheme.Typography.title2())
                    .fontWeight(.bold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .contentTransition(.numericText())
                
                Spacer()
                
                // Added amount with animation
                if addedValue > 0 {
                    Text("+\(addedValue)")
                        .font(KingdomTheme.Typography.headline())
                        .fontWeight(.bold)
                        .foregroundColor(color)
                        .opacity(showAddition ? 1 : 0)
                        .scaleEffect(showAddition ? 1 : 0.5)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: showAddition)
                }
            }
        }
        .padding(16)
        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .onAppear {
            withAnimation {
                showAddition = true
            }
        }
    }
}

// MARK: - Preview

#Preview("Reward Display") {
    ZStack {
        KingdomTheme.Colors.parchment.ignoresSafeArea()
        
        RewardDisplayView(
            reward: Reward(
                goldReward: 75,
                reputationReward: 0,
                experienceReward: 10,
                message: "Work completed successfully!",
                previousGold: 1250,
                previousReputation: 340,
                previousExperience: 50,
                currentGold: 1325,
                currentReputation: 340,
                currentExperience: 60
            ),
            isShowing: .constant(true)
        )
    }
}

