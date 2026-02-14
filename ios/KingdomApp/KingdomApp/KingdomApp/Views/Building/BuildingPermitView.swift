import SwiftUI

/// View for purchasing building permits in foreign kingdoms.
/// Visitors pay gold for temporary access to buildings.
struct BuildingPermitView: View {
    let building: BuildingMetadata
    let kingdom: Kingdom
    let onDismiss: () -> Void
    let onPurchased: () -> Void
    
    @State private var isLoading = false
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    private var permit: BuildingPermitInfo? {
        building.permit
    }
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchmentDark
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                ScrollView {
                    VStack(spacing: 24) {
                        buildingInfo
                        permitDetails
                        buyButton
                    }
                    .padding(KingdomTheme.Spacing.large)
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "ticket.fill")
                        .font(FontStyles.iconMedium)
                        .foregroundColor(KingdomTheme.Colors.gold)
                    
                    Text("BUILDING PERMIT")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    Text("Cancel")
                        .font(FontStyles.headingSmall)
                        .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                }
            }
            .padding(.horizontal, KingdomTheme.Spacing.large)
            .padding(.vertical, KingdomTheme.Spacing.medium)
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 3)
        }
        .background(KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Building Info
    
    private var buildingInfo: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: building.colorHex) ?? KingdomTheme.Colors.buttonPrimary)
                    .frame(width: 80, height: 80)
                    .overlay(Circle().stroke(Color.black, lineWidth: 3))
                    .shadow(color: .black.opacity(0.3), radius: 0, x: 3, y: 3)
                
                Image(systemName: building.icon)
                    .font(FontStyles.resultLarge)
                    .foregroundColor(.white)
            }
            
            Text(building.displayName)
                .font(FontStyles.displaySmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("in \(kingdom.name)")
                .font(FontStyles.headingSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .padding(.top, KingdomTheme.Spacing.medium)
    }
    
    // MARK: - Permit Details
    
    private var permitDetails: some View {
        VStack(spacing: 16) {
            // Why permit is needed
            VStack(alignment: .leading, spacing: 8) {
                Text("Visitor Access")
                    .font(FontStyles.headingSmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("You're visiting \(kingdom.name). A permit allows temporary access to use this building.")
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // Permit cost and duration
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(KingdomTheme.Colors.gold)
                    Text("\(permit?.permitCost ?? 10)g")
                        .font(FontStyles.statMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    Text("Cost")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                VStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 24))
                        .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                    Text("\(permit?.permitDurationMinutes ?? 10)m")
                        .font(FontStyles.statMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    Text("Duration")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                VStack(spacing: 4) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 24))
                        .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                    Text("L\(permit?.hometownBuildingLevel ?? 0)")
                        .font(FontStyles.statMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    Text("Your Limit")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            .padding(.vertical, 8)
            
            Divider()
            
            // Treasury note
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Text("Gold goes to \(kingdom.name)'s treasury")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
            }
            
            if let success = successMessage {
                Text(success)
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment)
    }
    
    // MARK: - Buy Button
    
    private var buyButton: some View {
        Button {
            purchasePermit()
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "ticket.fill")
                    Text("Buy Permit for \(permit?.permitCost ?? 10)g")
                }
            }
            .font(FontStyles.bodyMediumBold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(KingdomTheme.Colors.gold)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
        }
        .disabled(isPurchasing)
        .opacity(isPurchasing ? 0.7 : 1)
    }
    
    // MARK: - Actions
    
    private func purchasePermit() {
        isPurchasing = true
        errorMessage = nil
        
        Task {
            do {
                let request = try APIClient.shared.request(
                    endpoint: "/permits/buy",
                    method: "POST",
                    body: [
                        "kingdom_id": kingdom.id,
                        "building_type": building.type
                    ]
                )
                
                let response: BuyPermitResponse = try await APIClient.shared.execute(request)
                
                await MainActor.run {
                    isPurchasing = false
                    if response.success {
                        successMessage = response.message
                        // Brief delay then callback
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            onPurchased()
                        }
                    } else {
                        errorMessage = response.message
                    }
                }
            } catch let error as APIError {
                await MainActor.run {
                    isPurchasing = false
                    errorMessage = error.localizedDescription
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Response Model

struct BuyPermitResponse: Codable {
    let success: Bool
    let message: String
    let permit_expires_at: String?
    let permit_minutes_remaining: Int?
    let gold_spent: Int?
    let player_gold: Int?
    let treasury_gold: Int?
}

#Preview {
    Text("Permit Preview")
}
