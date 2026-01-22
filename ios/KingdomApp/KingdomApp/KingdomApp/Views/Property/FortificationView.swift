import SwiftUI

/// View for managing property fortification through gear sacrifice
struct FortificationView: View {
    @ObservedObject var player: Player
    let property: Property
    
    @State private var fortifyOptions: PropertyAPI.FortifyOptionsResponse?
    @State private var isLoading = true
    @State private var selectedItem: PropertyAPI.FortifyOptionItem?
    @State private var showConfirmation = false
    @State private var isSacrificing = false
    @State private var lastResult: PropertyAPI.FortifyResponse?
    @State private var showResult = false
    @State private var errorMessage: String?
    
    private let propertyAPI = PropertyAPI()
    
    // Fortification color - defensive blue/steel
    private let fortificationColor = KingdomTheme.Colors.royalBlue
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: KingdomTheme.Spacing.large) {
                    fortificationPercentageCard
                    sacrificeCard
                    howItWorksCard
                }
                .padding()
            }
            .parchmentBackground()
            .navigationTitle(fortifyOptions?.explanation.title ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .parchmentNavigationBar()
            .task {
                await loadFortifyOptions()
            }
            
            // Custom Popups
            if showConfirmation, let item = selectedItem, let explanation = fortifyOptions?.explanation {
                FortifyConfirmationPopup(
                    item: item,
                    explanation: explanation,
                    isShowing: $showConfirmation,
                    onConfirm: {
                        Task { await sacrificeItem(item) }
                    }
                )
                .transition(.opacity)
            }
            
            if showResult, let result = lastResult {
                FortifyResultPopup(
                    result: result,
                    title: fortifyOptions?.explanation.ui.result_title ?? "Fortification Increased!",
                    isShowing: $showResult
                )
                .transition(.opacity)
            }
        }
        .alert(fortifyOptions?.explanation.ui.generic_error_title ?? "", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(fortifyOptions?.explanation.ui.generic_error_ok_label ?? "", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    // MARK: - Card 1: Fortification Percentage
    
    private var fortificationPercentageCard: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(fortificationColor)
                
                Text(fortifyOptions?.explanation.title ?? "Fortification")
                    .font(KingdomTheme.Typography.title3())
                    .fontWeight(.bold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer(minLength: 0)
                
                Text("\(fortifyOptions?.current_fortification ?? property.fortificationPercent)%")
                    .font(KingdomTheme.Typography.headline())
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .brutalistBadge(
                        backgroundColor: fortificationColor,
                        cornerRadius: 8,
                        shadowOffset: 2,
                        borderWidth: 2
                    )
            }
            
            Rectangle()
                .fill(fortificationColor)
                .frame(height: 2)
            
            // Keep this bar layout as-is (per request)
            fortificationBar
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Card 2: Sacrifice Equipment
    
    private var sacrificeCard: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            if let explanation = fortifyOptions?.explanation {
                cardHeader(
                    title: explanation.ui.convert_card_title,
                    icon: explanation.ui.convert_card_icon,
                    accent: KingdomTheme.Colors.color(fromThemeName: explanation.ui.convert_card_accent_color)
                )
            }
            
            if isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(KingdomTheme.Colors.loadingTint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else if let options = fortifyOptions {
                if !options.fortification_unlocked {
                    Text(options.explanation.ui.locked_message)
                        .font(KingdomTheme.Typography.body())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .fixedSize(horizontal: false, vertical: true)
                } else if options.eligible_items.isEmpty {
                    Text(options.explanation.ui.empty_title)
                        .font(KingdomTheme.Typography.headline())
                        .fontWeight(.semibold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(options.explanation.ui.empty_message)
                        .font(KingdomTheme.Typography.body())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(options.explanation.ui.choose_item_message)
                        .font(KingdomTheme.Typography.body())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    ForEach(options.eligible_items) { item in
                        sacrificeItemRow(item: item)
                    }
                }
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12))
                            .foregroundColor(KingdomTheme.Colors.buttonDanger)
                        Text("\(options.explanation.ui.weapons_label): \(options.weapon_count)")
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 12))
                            .foregroundColor(KingdomTheme.Colors.royalBlue)
                        Text("\(options.explanation.ui.armor_label): \(options.armor_count)")
                    }
                }
                .font(KingdomTheme.Typography.caption())
                .foregroundColor(KingdomTheme.Colors.inkLight)
                .padding(.top, 4)
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Card 3: How It Works
    
    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            if let explanation = fortifyOptions?.explanation {
                cardHeader(title: explanation.tldr.title, icon: explanation.tldr.icon, accent: fortificationColor)
            } else {
                // No hardcoded fallback copy; show nothing until loaded
            }
            
            if isLoading {
                ProgressView()
                    .tint(KingdomTheme.Colors.loadingTint)
            } else if let explanation = fortifyOptions?.explanation {
                let tldr = explanation.tldr
                numberedPoints(tldr.points, color: fortificationColor)
                
                let gainRanges = explanation.gain_ranges
                simpleSectionTitle(gainRanges.title)
                
                VStack(spacing: 0) {
                    ForEach(Array(gainRanges.tiers.enumerated()), id: \.offset) { index, tier in
                        HStack {
                            Text("Tier \(tier.tier)")
                                .font(KingdomTheme.Typography.subheadline())
                                .fontWeight(.semibold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Spacer()
                            
                            Text("+\(tier.min)–\(tier.max)%")
                                .font(KingdomTheme.Typography.subheadline())
                                .fontWeight(.bold)
                                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                        }
                        .padding(.vertical, 8)
                        
                        if index < (gainRanges.tiers.count - 1) {
                            Rectangle()
                                .fill(KingdomTheme.Colors.divider.opacity(0.35))
                                .frame(height: 1)
                        }
                    }
                }
                .padding(KingdomTheme.Spacing.medium)
                .parchmentCard(
                    backgroundColor: KingdomTheme.Colors.parchment,
                    borderColor: KingdomTheme.Colors.border,
                    borderWidth: KingdomTheme.BorderWidth.thin,
                    cornerRadius: KingdomTheme.CornerRadius.large,
                    hasShadow: false
                )
                
                simpleSectionTitle("Tips & Info")
                let tips = [
                    explanation.decay.isEmpty ? nil : explanation.decay,
                    explanation.rules.isEmpty ? nil : explanation.rules,
                    explanation.t5_bonus?.text,
                    explanation.tip.isEmpty ? nil : explanation.tip
                ].compactMap { $0 }
                
                numberedPoints(tips, color: KingdomTheme.Colors.buttonDanger)
            } else {
                EmptyView()
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Shared helpers (Theme-only)
    
    private func cardHeader(title: String, icon: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(accent)
                Text(title)
                    .font(KingdomTheme.Typography.title3())
                    .fontWeight(.bold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            
            Rectangle()
                .fill(accent)
                .frame(height: 2)
        }
    }
    
    private func sectionHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(KingdomTheme.Typography.headline())
                .fontWeight(.bold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
        .padding(.top, 8)
    }
    
    private func simpleSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(KingdomTheme.Typography.headline())
            .fontWeight(.bold)
            .foregroundColor(KingdomTheme.Colors.inkDark)
            .padding(.top, 12)
    }
    
    private func numberedPoints(_ points: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(color)
                                .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                        )
                    
                    Text(point)
                        .font(KingdomTheme.Typography.body())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
    
    private func infoRow(icon: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            Text(text)
                .font(KingdomTheme.Typography.subheadline())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func renderTemplate(_ template: String, vars: [String: String]) -> String {
        var out = template
        for (k, v) in vars {
            out = out.replacingOccurrences(of: "{\(k)}", with: v)
        }
        return out
    }
    
    // MARK: - Fortification Bar
    
    private var fortificationBar: some View {
        let currentPercent = fortifyOptions?.current_fortification ?? property.fortificationPercent
        let basePercent = fortifyOptions?.base_fortification ?? property.fortificationBasePercent
        
        return VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(KingdomTheme.Colors.parchmentDark)
                        .frame(height: 24)
                    
                    // Base fortification (T5 only) - darker shade
                    if basePercent > 0 {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(fortificationColor.opacity(0.4))
                            .frame(width: geometry.size.width * CGFloat(basePercent) / 100.0, height: 24)
                    }
                    
                    // Current fortification
                    RoundedRectangle(cornerRadius: 6)
                        .fill(fortificationColor)
                        .frame(width: geometry.size.width * CGFloat(currentPercent) / 100.0, height: 24)
                    
                    // Border
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.black, lineWidth: 2)
                        .frame(height: 24)
                }
            }
            .frame(height: 24)
            
            // Scale markers
            HStack {
                Text("0%")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                Spacer()
                if basePercent > 0 {
                    Text("\(basePercent)% base")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                    Spacer()
                }
                Text("100%")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            }
        }
    }
    // MARK: - Sacrifice Item Row
    
    private func sacrificeItemRow(item: PropertyAPI.FortifyOptionItem) -> some View {
        let itemColor = item.type == "weapon" ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.royalBlue
        let iconName = item.type == "weapon" ? "bolt.fill" : "shield.fill"
        
        return HStack(spacing: 12) {
            // Item icon
            Image(systemName: iconName)
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .brutalistBadge(
                    backgroundColor: itemColor,
                    cornerRadius: 8,
                    shadowOffset: 2,
                    borderWidth: 2
                )
            
            VStack(alignment: .leading, spacing: 4) {
                // Top row: Name
                Text(item.display_name)
                    .font(KingdomTheme.Typography.body())
                    .fontWeight(.semibold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .lineLimit(1)
                
                // Bottom row: Badges
                HStack(spacing: 8) {
                    // Combined Tier & Gain Badge
                    HStack(spacing: 6) {
                        Text("T\(item.tier)")
                            .font(KingdomTheme.Typography.caption2())
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 3).fill(itemColor))
                        
                        Text(item.gainRange)
                            .font(KingdomTheme.Typography.caption())
                            .fontWeight(.bold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .brutalistBadge(
                        backgroundColor: KingdomTheme.Colors.parchmentLight,
                        cornerRadius: 6,
                        shadowOffset: 1,
                        borderWidth: 1.5
                    )
                    
                    // Count Badge
                    if item.count > 1 {
                        Text("x\(item.count)")
                            .font(KingdomTheme.Typography.caption())
                            .fontWeight(.bold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .brutalistBadge(
                                backgroundColor: KingdomTheme.Colors.parchmentLight,
                                cornerRadius: 6,
                                shadowOffset: 1,
                                borderWidth: 1.5
                            )
                    }
                }
            }
            
            Spacer(minLength: 4)
            
            // Convert button
            Button {
                selectedItem = item
                showConfirmation = true
            } label: {
                Text(fortifyOptions?.explanation.ui.primary_action_label ?? "Convert")
                    .font(KingdomTheme.Typography.caption())
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .brutalistBadge(
                backgroundColor: KingdomTheme.Colors.buttonDanger,
                cornerRadius: 6,
                shadowOffset: 2,
                borderWidth: 2
            )
            .disabled(isSacrificing)
            .opacity(isSacrificing ? 0.6 : 1.0)
        }
        .padding(12)
        .parchmentCard(
            backgroundColor: KingdomTheme.Colors.parchment,
            cornerRadius: 10,
            hasShadow: false
        )
    }
    
    // MARK: - API
    
    private func loadFortifyOptions() async {
        do {
            let response = try await propertyAPI.getFortifyOptions(propertyId: property.id)
            await MainActor.run {
                fortifyOptions = response
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to load fortification options"
            }
        }
    }
    
    private func sacrificeItem(_ item: PropertyAPI.FortifyOptionItem) async {
        await MainActor.run {
            isSacrificing = true
            selectedItem = nil
        }
        
        do {
            let response = try await propertyAPI.fortifyProperty(propertyId: property.id, itemId: item.id)
            await MainActor.run {
                lastResult = response
                isSacrificing = false
                showResult = true
            }
            // Reload options to update the list
            await loadFortifyOptions()
        } catch {
            await MainActor.run {
                isSacrificing = false
                errorMessage = "Failed to sacrifice item"
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FortificationView(
            player: Player(),
            property: Property(
                id: "test",
                kingdomId: "k1",
                kingdomName: "Test Kingdom",
                ownerId: "1",
                ownerName: "Test",
                tier: 3,
                location: "north",
                purchasedAt: Date(),
                lastUpgraded: nil,
                fortificationUnlocked: true,
                fortificationPercent: 35,
                fortificationBasePercent: 0
            )
        )
    }
}
