import SwiftUI

// MARK: - Content Sections

extension ActionsView {
    
    // MARK: - Action Status Content
    
    @ViewBuilder
    func actionStatusContent(status: AllActionStatus) -> some View {
        // Backend pre-filters slots by player location - we just render what we receive
        Group {
            // Alliance Requests Section (Ruler Only - Critical Priority)
            allianceRequestsSection(status: status)
            
            // DYNAMIC: Render all slots from backend (already filtered by location)
            ForEach(status.sortedSlots) { slot in
                dynamicSlotSection(slot: slot, status: status)
            }
        }
    }
    
    // MARK: - Alliance Requests Section
    
    @ViewBuilder
    func allianceRequestsSection(status: AllActionStatus) -> some View {
        if let requests = status.pendingAllianceRequests, !requests.isEmpty {
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                // Section header
                VStack(alignment: .leading, spacing: 4) {
                    Rectangle()
                        .fill(KingdomTheme.Colors.buttonSuccess)
                        .frame(height: 3)
                        .padding(.horizontal)
                    
                    HStack {
                        Image(systemName: "person.2.fill")
                            .font(.headline)
                            .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                        
                        Text("Alliance Proposals")
                            .font(FontStyles.headingLarge)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Spacer()
                        
                        // Badge showing count
                        Text("\(requests.count)")
                            .font(FontStyles.labelBold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .brutalistBadge(
                                backgroundColor: KingdomTheme.Colors.buttonSuccess,
                                cornerRadius: 8,
                                shadowOffset: 1,
                                borderWidth: 1.5
                            )
                    }
                    .padding(.horizontal)
                    .padding(.top, KingdomTheme.Spacing.medium)
                    
                    Text("Respond to alliance requests from other rulers")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .padding(.horizontal)
                }
                
                // Alliance request cards
                ForEach(requests) { request in
                    AllianceRequestCard(
                        request: request,
                        onAccept: { acceptAllianceRequest(request) },
                        onDecline: { declineAllianceRequest(request) }
                    )
                }
            }
        }
    }
}
