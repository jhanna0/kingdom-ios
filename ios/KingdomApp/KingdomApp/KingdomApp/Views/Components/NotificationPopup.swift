import SwiftUI

/// Generic popup for backend-triggered notifications (show_popup = true)
/// Handles coup results, throne changes, etc.
struct NotificationPopup: View {
    let notification: AppNotification
    let playerName: String
    let onDismiss: () -> Void
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var iconRotation: Double = -20
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissWithAnimation()
                }
            
            VStack(spacing: 24) {
                // Icon with brutalist badge
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 110, height: 110)
                        .offset(x: 4, y: 4)
                    
                    Circle()
                        .fill(iconBackgroundColor)
                        .frame(width: 110, height: 110)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 3)
                        )
                    
                    Image(systemName: iconName)
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(shouldAnimateIcon ? iconRotation : 0))
                }
                
                // Main message
                VStack(spacing: 8) {
                    Text(headlineText)
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.black)
                        .tracking(2)
                        .multilineTextAlignment(.center)
                    
                    if let subtitle = subtitleText {
                        Text(subtitle)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black.opacity(0.6))
                    }
                    
                    if let kingdomName = notification.coup_data?.kingdom_name {
                        Text(kingdomName)
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                
                // Decorative divider
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 3)
                    .padding(.horizontal, 40)
                
                // Details (spoils or penalties)
                if let detailText = detailText {
                    Text(detailText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Flavor text
                Text(flavorText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black.opacity(0.5))
                    .italic()
                
                // Dismiss button
                Button(action: {
                    dismissWithAnimation()
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusSmall)
                            .fill(Color.black)
                            .offset(x: 4, y: 4)
                        
                        RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusSmall)
                            .fill(buttonColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusSmall)
                                    .stroke(Color.black, lineWidth: 3)
                            )
                        
                        Text(buttonText)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                    }
                    .frame(height: 52)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            .padding(32)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusLarge)
                        .fill(Color.black)
                        .offset(x: 6, y: 6)
                    
                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusLarge)
                        .fill(KingdomTheme.Colors.parchment)
                        .overlay(
                            RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusLarge)
                                .stroke(Color.black, lineWidth: 4)
                        )
                }
            )
            .frame(maxWidth: 400)
            .padding(.horizontal, 24)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            
            if shouldAnimateIcon {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    iconRotation = 20
                }
            }
        }
    }
    
    // MARK: - Computed Properties Based on Notification Type
    
    private var isNewRuler: Bool { notification.type == "coup_new_ruler" }
    private var isLostThrone: Bool { notification.type == "coup_lost_throne" }
    private var isSideWon: Bool { notification.type == "coup_side_won" }
    private var isSideLost: Bool { notification.type == "coup_side_lost" }
    
    private var iconName: String {
        if isNewRuler { return "crown.fill" }
        if isLostThrone { return "crown.fill" }
        if isSideWon { return "flag.checkered.2.crossed" }
        if isSideLost { return "xmark.shield.fill" }
        return notification.icon ?? "bell.fill"
    }
    
    private var iconBackgroundColor: Color {
        if isNewRuler { return KingdomTheme.Colors.imperialGold }
        if isLostThrone { return KingdomTheme.Colors.buttonDanger }
        if isSideWon { return KingdomTheme.Colors.buttonSuccess }
        if isSideLost { return KingdomTheme.Colors.buttonDanger }
        return KingdomTheme.Colors.buttonPrimary
    }
    
    private var shouldAnimateIcon: Bool {
        isNewRuler
    }
    
    private var headlineText: String {
        if isNewRuler { return "HAIL \(playerName.uppercased())!" }
        if isLostThrone { return "OVERTHROWN!" }
        if isSideWon { return "VICTORY!" }
        if isSideLost { return "DEFEAT!" }
        return notification.title
    }
    
    private var subtitleText: String? {
        if isNewRuler { return "Ruler of" }
        if isLostThrone { return "You have been dethroned in" }
        if isSideWon { return "Your side triumphed in" }
        if isSideLost { return "Your side fell in" }
        return nil
    }
    
    private var detailText: String? {
        if let coupData = notification.coup_data {
            if isNewRuler || isSideWon {
                var parts: [String] = []
                if let gold = coupData.gold_per_winner, gold > 0 {
                    parts.append("+\(gold) gold")
                }
                if let rep = coupData.rep_gained, rep > 0 {
                    parts.append("+\(rep) reputation")
                }
                return parts.isEmpty ? nil : "Spoils: " + parts.joined(separator: ", ")
            }
            if isLostThrone || isSideLost {
                var parts: [String] = []
                if let goldPct = coupData.gold_lost_percent {
                    parts.append("-\(goldPct)% gold")
                }
                if let rep = coupData.rep_lost {
                    parts.append("-\(rep) rep")
                }
                if let atk = coupData.attack_lost {
                    parts.append("-\(atk) attack")
                }
                if let def = coupData.defense_lost {
                    parts.append("-\(def) defense")
                }
                return parts.isEmpty ? nil : "Penalties: " + parts.joined(separator: ", ")
            }
        }
        return nil
    }
    
    private var flavorText: String {
        if isNewRuler { return "Your reign begins" }
        if isLostThrone { return "Your reign has ended" }
        if isSideWon { return "Glory to the victors" }
        if isSideLost { return "Live to fight another day" }
        return ""
    }
    
    private var buttonText: String {
        if isNewRuler { return "Long Live the Ruler!" }
        if isLostThrone { return "Accept Defeat" }
        if isSideWon { return "Claim Spoils" }
        if isSideLost { return "Lick Your Wounds" }
        return "Dismiss"
    }
    
    private var buttonColor: Color {
        if isNewRuler { return KingdomTheme.Colors.buttonPrimary }
        if isLostThrone { return KingdomTheme.Colors.inkMedium }
        if isSideWon { return KingdomTheme.Colors.buttonSuccess }
        if isSideLost { return KingdomTheme.Colors.inkMedium }
        return KingdomTheme.Colors.buttonPrimary
    }
    
    private func dismissWithAnimation() {
        withAnimation(.easeOut(duration: 0.2)) {
            scale = 0.9
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

#Preview {
    NotificationPopup(
        notification: AppNotification(
            type: "coup_new_ruler",
            priority: "critical",
            title: "👑 You Are Now Ruler!",
            message: "Your coup succeeded!",
            action: "view_kingdom",
            action_id: "123",
            created_at: "2025-01-01T00:00:00Z",
            show_popup: true,
            coup_data: AppCoupData(
                id: 1,
                kingdom_id: "123",
                kingdom_name: "San Francisco",
                attacker_victory: true,
                user_won: true,
                gold_per_winner: 500,
                is_new_ruler: true,
                show_celebration: true,
                rep_gained: 100,
                gold_lost_percent: nil,
                rep_lost: nil,
                attack_lost: nil,
                defense_lost: nil,
                leadership_lost: nil,
                new_ruler_name: nil
            ),
            icon: "crown.fill",
            icon_color: "imperialGold",
            priority_color: "buttonDanger",
            border_color: "buttonDanger"
        ),
        playerName: "Gerard",
        onDismiss: {}
    )
}
