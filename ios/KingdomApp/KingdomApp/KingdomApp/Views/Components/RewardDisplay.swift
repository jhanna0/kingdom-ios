import SwiftUI

struct Reward {
    let gold: Int?
    let reputation: Int?
    let iron: Int?
    let message: String
}

struct RewardDisplayView: View {
    let reward: Reward
    @Binding var isShowing: Bool
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var bounceOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 20) {
            // Main reward card
            VStack(spacing: 16) {
                // Success icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.green.opacity(0.8),
                                    Color.green.opacity(0.6)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }
                .scaleEffect(scale)
                .offset(y: bounceOffset)
                
                // Message
                Text(reward.message)
                    .font(KingdomTheme.Typography.headline())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Rewards earned
                VStack(spacing: 12) {
                    if let gold = reward.gold, gold > 0 {
                        RewardRow(
                            icon: "dollarsign.circle.fill",
                            label: "Gold",
                            amount: "+\(gold)",
                            color: KingdomTheme.Colors.gold
                        )
                    }
                    
                    if let reputation = reward.reputation, reputation > 0 {
                        RewardRow(
                            icon: "star.circle.fill",
                            label: "Reputation",
                            amount: "+\(reputation)",
                            color: Color.purple
                        )
                    }
                    
                    if let iron = reward.iron, iron > 0 {
                        RewardRow(
                            icon: "shield.fill",
                            label: "Iron",
                            amount: "+\(iron)",
                            color: Color.gray
                        )
                    }
                }
                .padding(.horizontal)
                
                // Close button
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        isShowing = false
                    }
                }) {
                    Text("Continue")
                        .font(KingdomTheme.Typography.body())
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(KingdomTheme.Colors.buttonSuccess)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(KingdomTheme.Colors.parchment)
                    .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 40)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .opacity(opacity)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        isShowing = false
                    }
                }
        )
        .onAppear {
            // Entrance animation
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // Bounce animation for the checkmark
            withAnimation(
                Animation.easeInOut(duration: 0.5)
                    .repeatForever(autoreverses: true)
                    .delay(0.3)
            ) {
                bounceOffset = -5
            }
        }
    }
}

struct RewardRow: View {
    let icon: String
    let label: String
    let amount: String
    let color: Color
    
    @State private var slideIn = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
            }
            
            // Label
            Text(label)
                .font(KingdomTheme.Typography.body())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            Spacer()
            
            // Amount
            Text(amount)
                .font(KingdomTheme.Typography.headline())
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
        .offset(x: slideIn ? 0 : 300)
        .opacity(slideIn ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2)) {
                slideIn = true
            }
        }
    }
}

// MARK: - Compact Success Banner (Alternative)

struct CompactRewardBanner: View {
    let reward: Reward
    @Binding var isShowing: Bool
    
    @State private var offset: CGFloat = -200
    
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(reward.message)
                        .font(KingdomTheme.Typography.body())
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 16) {
                        if let gold = reward.gold, gold > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .foregroundColor(KingdomTheme.Colors.gold)
                                Text("+\(gold)")
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                        }
                        
                        if let reputation = reward.reputation, reputation > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "star.circle.fill")
                                    .foregroundColor(.yellow)
                                Text("+\(reputation)")
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                        }
                        
                        if let iron = reward.iron, iron > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "shield.fill")
                                    .foregroundColor(.gray)
                                Text("+\(iron)")
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                        }
                    }
                    .font(KingdomTheme.Typography.caption())
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.green.opacity(0.95),
                                Color.green.opacity(0.85)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
            )
            .padding(.horizontal)
            .offset(y: offset)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    offset = 0
                }
                
                // Auto-dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.spring(response: 0.4)) {
                        offset = -200
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isShowing = false
                    }
                }
            }
            
            Spacer()
        }
    }
}

#Preview("Full Reward Display") {
    ZStack {
        Color.gray.ignoresSafeArea()
        
        RewardDisplayView(
            reward: Reward(
                gold: 50,
                reputation: 10,
                iron: nil,
                message: "Work completed successfully!"
            ),
            isShowing: .constant(true)
        )
    }
}

#Preview("Compact Banner") {
    ZStack {
        Color.gray.ignoresSafeArea()
        
        CompactRewardBanner(
            reward: Reward(
                gold: 50,
                reputation: 5,
                iron: 10,
                message: "Mining complete!"
            ),
            isShowing: .constant(true)
        )
    }
}

