import SwiftUI

// MARK: - Alliance Request Card

/// Card showing a pending alliance request with accept/decline buttons
struct AllianceRequestCard: View {
    let request: PendingAllianceRequest
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    @State private var isAccepting = false
    @State private var isDeclining = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            // Header
            HStack(alignment: .top, spacing: KingdomTheme.Spacing.medium) {
                // Icon in brutalist badge
                Image(systemName: "handshake.fill")
                    .font(FontStyles.iconLarge)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .brutalistBadge(
                        backgroundColor: KingdomTheme.Colors.buttonSuccess,
                        cornerRadius: 12,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Alliance Proposal")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("From \(request.initiatorRulerName) of \(request.initiatorEmpireName)")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    // Time remaining
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text("\(request.hoursToRespond) hours to respond")
                            .font(FontStyles.labelSmall)
                    }
                    .foregroundColor(request.hoursToRespond < 24 ? KingdomTheme.Colors.buttonWarning : KingdomTheme.Colors.inkLight)
                }
                
                Spacer()
            }
            
            // Benefits preview
            VStack(alignment: .leading, spacing: 4) {
                Text("Benefits of Alliance:")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                HStack(spacing: 12) {
                    benefitPill("🛡️ Protection")
                    benefitPill("🚫 No fees")
                    benefitPill("⚔️ Mutual defense")
                }
            }
            
            // Action buttons
            HStack(spacing: KingdomTheme.Spacing.small) {
                // Decline button
                Button(action: {
                    isDeclining = true
                    onDecline()
                }) {
                    HStack(spacing: 6) {
                        if isDeclining {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "xmark")
                                .font(.headline)
                        }
                        Text("Decline")
                            .font(FontStyles.labelBold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundColor(.white)
                }
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.inkMedium,
                    cornerRadius: 10,
                    shadowOffset: 2,
                    borderWidth: 2
                )
                .disabled(isAccepting || isDeclining)
                
                // Accept button
                Button(action: {
                    isAccepting = true
                    onAccept()
                }) {
                    HStack(spacing: 6) {
                        if isAccepting {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.headline)
                        }
                        Text("Accept")
                            .font(FontStyles.labelBold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundColor(.white)
                }
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.buttonSuccess,
                    cornerRadius: 10,
                    shadowOffset: 2,
                    borderWidth: 2
                )
                .disabled(isAccepting || isDeclining)
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KingdomTheme.Colors.buttonSuccess.opacity(0.5), lineWidth: 2)
        )
        .padding(.horizontal)
    }
    
    private func benefitPill(_ text: String) -> some View {
        Text(text)
            .font(FontStyles.labelTiny)
            .foregroundColor(KingdomTheme.Colors.inkMedium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(KingdomTheme.Colors.parchment)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black.opacity(0.2), lineWidth: 1)
            )
    }
}

#Preview {
    AllianceRequestCard(
        request: PendingAllianceRequest(
            id: 1,
            initiatorEmpireId: "12345",
            initiatorEmpireName: "Kingdom of Test",
            initiatorRulerName: "Lord TestRuler",
            hoursToRespond: 48,
            createdAt: "2024-01-01T00:00:00Z",
            proposalExpiresAt: "2024-01-08T00:00:00Z",
            acceptEndpoint: "/alliances/1/accept",
            declineEndpoint: "/alliances/1/decline"
        ),
        onAccept: {},
        onDecline: {}
    )
    .padding()
    .background(KingdomTheme.Colors.parchment)
}
