import SwiftUI

// MARK: - Notification Components
// Shared components used by NotificationsSheet

// MARK: - Notification Detail Popup

struct NotificationDetailPopup: View {
    let notification: ActivityNotification
    @Binding var isShowing: Bool
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                // Icon
                Image(systemName: notification.icon ?? "bell.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .brutalistBadge(backgroundColor: iconColor, cornerRadius: 14)
                
                // Title
                Text(notification.title)
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .multilineTextAlignment(.center)
                
                // Full message
                Text(notification.message)
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Timestamp
                Text(notification.timeAgo)
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                
                // Dismiss button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isShowing = false
                    }
                }) {
                    Text("Got it")
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black)
                            .offset(x: 2, y: 2)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(KingdomTheme.Colors.buttonPrimary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.black, lineWidth: 2)
                            )
                    }
                )
                .padding(.top, 8)
            }
            .padding(24)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                        .fill(Color.black)
                        .offset(x: KingdomTheme.Brutalist.offsetShadow, y: KingdomTheme.Brutalist.offsetShadow)
                    
                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                        .fill(KingdomTheme.Colors.parchmentLight)
                        .overlay(
                            RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                                .stroke(Color.black, lineWidth: KingdomTheme.Brutalist.borderWidth)
                        )
                }
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
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isShowing = false
                    }
                }
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
    
    private var iconColor: Color {
        if let colorName = notification.priorityColor {
            return ThemeColorHelper.color(for: colorName)
        }
        return KingdomTheme.Colors.inkMedium
    }
}

// MARK: - Notification Card

struct NotificationCard: View {
    let notification: ActivityNotification
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                HStack(spacing: KingdomTheme.Spacing.medium) {
                    Image(systemName: iconForNotification)
                        .font(FontStyles.iconMedium)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .brutalistBadge(backgroundColor: iconColor, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(notification.title)
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Text(notification.message)
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                            .lineLimit(3)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(FontStyles.iconSmall)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
                
                // Coup-specific info (only show for active coups with participant data)
                if let coupData = notification.coupData,
                   let attackerCount = coupData.attackerCount,
                   let defenderCount = coupData.defenderCount {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 1)
                    
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(FontStyles.iconMini)
                                .foregroundColor(KingdomTheme.Colors.buttonDanger)
                            Text("\(attackerCount)")
                                .font(FontStyles.labelBold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "shield.fill")
                                .font(FontStyles.iconMini)
                                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                            Text("\(defenderCount)")
                                .font(FontStyles.labelBold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                        }
                        
                        Spacer()
                        
                        if coupData.timeRemainingSeconds != nil {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(FontStyles.iconMini)
                                Text(coupData.timeRemainingFormatted)
                                    .font(FontStyles.labelBold)
                            }
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                    }
                }
                
                // Invasion-specific info
                if let invasionData = notification.invasionData {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 1)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "flag.fill")
                                .font(FontStyles.iconMini)
                                .foregroundColor(KingdomTheme.Colors.buttonDanger)
                            Text(invasionData.attackingFromKingdomName)
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            Image(systemName: "arrow.right")
                                .font(FontStyles.iconMini)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                            Text(invasionData.targetKingdomName)
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                        }
                        
                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                    .font(FontStyles.iconMini)
                                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
                                Text("\(invasionData.attackerCount)")
                                    .font(FontStyles.labelBold)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "shield.fill")
                                    .font(FontStyles.iconMini)
                                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                                Text("\(invasionData.defenderCount)")
                                    .font(FontStyles.labelBold)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(FontStyles.iconMini)
                                Text(invasionData.timeRemainingFormatted)
                                    .font(FontStyles.labelBold)
                            }
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        
                        // Show alliance badge if applicable
                        if invasionData.isAllied == true {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(FontStyles.iconMini)
                                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                                Text("Allied Empire")
                                    .font(FontStyles.labelSmall)
                                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                            }
                        }
                    }
                }
                
            }
            .padding()
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
    
    // MARK: - Dynamic from Backend (no switch statements!)
    
    private var iconForNotification: String {
        // Use backend-provided icon, fallback to bell
        notification.icon ?? "bell.fill"
    }
    
    private var iconColor: Color {
        // Use backend-provided color, fallback based on priority
        if let colorName = notification.priorityColor {
            return ThemeColorHelper.color(for: colorName)
        }
        // Fallback
        return KingdomTheme.Colors.inkMedium
    }
    
    private var borderColor: Color {
        // Use backend-provided border color
        if let colorName = notification.borderColor {
            return ThemeColorHelper.color(for: colorName).opacity(0.5)
        }
        // Fallback
        return KingdomTheme.Colors.inkMedium.opacity(0.3)
    }
}

// MARK: - Theme Color Helper

/// Maps backend color names to KingdomTheme.Colors
/// SINGLE SOURCE OF TRUTH - backend sends color name, frontend renders
struct ThemeColorHelper {
    static func color(for name: String) -> Color {
        switch name {
        case "buttonDanger": return KingdomTheme.Colors.buttonDanger
        case "buttonWarning": return KingdomTheme.Colors.buttonWarning
        case "buttonSuccess": return KingdomTheme.Colors.buttonSuccess
        case "buttonPrimary": return KingdomTheme.Colors.buttonPrimary
        case "imperialGold": return KingdomTheme.Colors.imperialGold
        case "inkDark": return KingdomTheme.Colors.inkDark
        case "inkMedium": return KingdomTheme.Colors.inkMedium
        case "inkLight": return KingdomTheme.Colors.inkLight
        case "royalBlue": return KingdomTheme.Colors.royalBlue
        case "royalEmerald": return KingdomTheme.Colors.royalEmerald
        default: return KingdomTheme.Colors.inkMedium
        }
    }
}
