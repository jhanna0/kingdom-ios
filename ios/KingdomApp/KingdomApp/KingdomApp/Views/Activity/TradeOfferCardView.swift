import SwiftUI

// MARK: - Trade Offer Card

struct TradeOfferCard: View {
    let trade: TradeOffer
    let onAccept: () async -> Void
    let onDecline: () async -> Void
    
    @State private var isProcessing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack(spacing: 12) {
                // Sender avatar
                Text(String(trade.senderName.prefix(1)).uppercased())
                    .font(FontStyles.headingSmall)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonPrimary, cornerRadius: 10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(trade.senderName)
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    // Offer description
                    HStack(spacing: 4) {
                        if trade.offerType == "gold" {
                            Image(systemName: "g.circle.fill")
                                .font(FontStyles.iconMini)
                                .foregroundColor(KingdomTheme.Colors.imperialGold)
                            Text("Sending \(trade.goldAmount)g")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        } else if let itemIcon = trade.itemIcon, let itemName = trade.itemDisplayName, let qty = trade.itemQuantity {
                            Image(systemName: itemIcon)
                                .font(FontStyles.iconMini)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                            if trade.goldAmount > 0 {
                                Text("\(qty) \(itemName) for \(trade.goldAmount)g")
                                    .font(FontStyles.labelSmall)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                            } else {
                                Text("\(qty) \(itemName) (gift)")
                                    .font(FontStyles.labelSmall)
                                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            
            // Message if any
            if let message = trade.message, !message.isEmpty {
                Text("\"\(message)\"")
                    .font(FontStyles.bodySmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .italic()
                    .padding(.horizontal, 4)
            }
            
            // Accept/Decline buttons
            HStack(spacing: KingdomTheme.Spacing.medium) {
                Button(action: {
                    isProcessing = true
                    Task {
                        await onAccept()
                        isProcessing = false
                    }
                }) {
                    Text("Accept")
                        .font(FontStyles.labelBold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSuccess, cornerRadius: 8)
                .disabled(isProcessing)
                
                Button(action: {
                    isProcessing = true
                    Task {
                        await onDecline()
                        isProcessing = false
                    }
                }) {
                    Text("Decline")
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 8)
                .disabled(isProcessing)
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .padding(.horizontal)
    }
}

// MARK: - Outgoing Trade Card

struct OutgoingTradeCard: View {
    let trade: TradeOffer
    let onCancel: () async -> Void
    
    @State private var isProcessing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            HStack(spacing: 12) {
                // Recipient avatar
                Text(String(trade.recipientName.prefix(1)).uppercased())
                    .font(FontStyles.headingSmall)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.imperialGold, cornerRadius: 10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("To \(trade.recipientName)")
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    // Offer description
                    HStack(spacing: 4) {
                        if trade.offerType == "gold" {
                            Image(systemName: "g.circle.fill")
                                .font(FontStyles.iconMini)
                                .foregroundColor(KingdomTheme.Colors.imperialGold)
                            Text("Sending \(trade.goldAmount)g")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        } else if let itemIcon = trade.itemIcon, let itemName = trade.itemDisplayName, let qty = trade.itemQuantity {
                            Image(systemName: itemIcon)
                                .font(FontStyles.iconMini)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                            if trade.goldAmount > 0 {
                                Text("\(qty) \(itemName) for \(trade.goldAmount)g")
                                    .font(FontStyles.labelSmall)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                            } else {
                                Text("\(qty) \(itemName) (gift)")
                                    .font(FontStyles.labelSmall)
                                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Cancel button
                Button(action: {
                    isProcessing = true
                    Task {
                        await onCancel()
                        isProcessing = false
                    }
                }) {
                    Text("Cancel")
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 8)
                .disabled(isProcessing)
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .padding(.horizontal)
    }
}

// MARK: - Trade History Card

struct TradeHistoryCard: View {
    let trade: TradeOffer
    
    var statusColor: Color {
        switch trade.status {
        case .accepted:
            return KingdomTheme.Colors.buttonSuccess
        case .declined:
            return KingdomTheme.Colors.buttonDanger
        case .cancelled:
            return KingdomTheme.Colors.inkMedium
        case .expired:
            return KingdomTheme.Colors.inkLight
        default:
            return KingdomTheme.Colors.inkMedium
        }
    }
    
    var statusText: String {
        switch trade.status {
        case .accepted:
            return "Accepted"
        case .declined:
            return "Declined"
        case .cancelled:
            return "Cancelled"
        case .expired:
            return "Expired"
        default:
            return "Unknown"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Direction indicator
            Image(systemName: trade.isIncoming ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .font(FontStyles.iconMedium)
                .foregroundColor(trade.isIncoming ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.imperialGold)
            
            VStack(alignment: .leading, spacing: 4) {
                // Who and what
                HStack(spacing: 4) {
                    Text(trade.isIncoming ? "From \(trade.senderName)" : "To \(trade.recipientName)")
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                // Offer description
                HStack(spacing: 4) {
                    if trade.offerType == "gold" {
                        Image(systemName: "g.circle.fill")
                            .font(FontStyles.iconMini)
                            .foregroundColor(KingdomTheme.Colors.imperialGold)
                        Text("\(trade.goldAmount)g")
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    } else if let itemIcon = trade.itemIcon, let itemName = trade.itemDisplayName, let qty = trade.itemQuantity {
                        Image(systemName: itemIcon)
                            .font(FontStyles.iconMini)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        if trade.goldAmount > 0 {
                            Text("\(qty) \(itemName) for \(trade.goldAmount)g")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        } else {
                            Text("\(qty) \(itemName)")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Status badge
            Text(statusText)
                .font(FontStyles.labelBold)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .brutalistBadge(backgroundColor: statusColor, cornerRadius: 8, shadowOffset: 1, borderWidth: 1.5)
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .padding(.horizontal)
    }
}

// MARK: - Duel Challenge Card

struct DuelChallengeCard: View {
    let challenge: DuelInvitation
    let onAccept: () async -> Void
    let onDecline: () async -> Void
    
    @State private var isProcessing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack(spacing: 12) {
                // Challenger icon
                Image(systemName: "figure.fencing")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.royalCrimson, cornerRadius: 10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.inviterName)
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("challenges you to a duel!")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    // Show challenger stats if available
                    if let stats = challenge.challengerStats {
                        HStack(spacing: 8) {
                            HStack(spacing: 2) {
                                Image(systemName: "burst.fill")
                                    .font(.system(size: 9))
                                Text("\(stats.attack)")
                            }
                            .foregroundColor(KingdomTheme.Colors.buttonDanger)
                            
                            HStack(spacing: 2) {
                                Image(systemName: "shield.fill")
                                    .font(.system(size: 9))
                                Text("\(stats.defense)")
                            }
                            .foregroundColor(KingdomTheme.Colors.royalBlue)
                        }
                        .font(FontStyles.labelTiny)
                    }
                    
                    // Wager if any
                    if challenge.wagerGold > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "g.circle.fill")
                                .font(FontStyles.iconMini)
                                .foregroundColor(KingdomTheme.Colors.imperialGold)
                            Text("\(challenge.wagerGold) gold wager")
                                .font(FontStyles.labelTiny)
                                .foregroundColor(KingdomTheme.Colors.imperialGold)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Accept/Decline buttons
            HStack(spacing: KingdomTheme.Spacing.medium) {
                Button(action: {
                    isProcessing = true
                    Task {
                        await onAccept()
                        isProcessing = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(FontStyles.iconMini)
                        Text("Accept")
                            .font(FontStyles.labelBold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSuccess, cornerRadius: 8)
                .disabled(isProcessing)
                
                Button(action: {
                    isProcessing = true
                    Task {
                        await onDecline()
                        isProcessing = false
                    }
                }) {
                    Text("Decline")
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 8)
                .disabled(isProcessing)
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .padding(.horizontal)
    }
}
