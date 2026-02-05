import SwiftUI

/// View to see all property tiers at once with brutalist styling
struct PropertyTiersView: View {
    @ObservedObject var player: Player
    let property: Property?  // Optional - can view tiers without owning property
    @Environment(\.dismiss) var dismiss
    @State private var selectedTier: Int = 1
    private let tierManager = TierManager.shared
    
    private var currentTier: Int {
        property?.tier ?? 0
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.large) {
                // Tier selector with picker
                TierSelectorCard(
                    currentTier: currentTier,
                    selectedTier: $selectedTier,
                    accentColor: KingdomTheme.Colors.buttonSuccess
                ) { tier in
                    tierContent(tier: tier)
                }
            }
            .padding()
        }
        .background(KingdomTheme.Colors.parchment.ignoresSafeArea())
        .navigationTitle("All Property Tiers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .onAppear {
            selectedTier = max(1, currentTier) // Start at tier 1 if no property
        }
    }
    
    private func tierContent(tier: Int) -> some View {
        let options = tierManager.propertyTierOptions(tier)
        
        return VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            // Show multiple options if available, otherwise fall back to legacy single view
            if options.count > 1 {
                // Multiple options header
                HStack {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(FontStyles.iconSmall)
                        .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                    Text("\(options.count) rooms available at this level")
                        .font(FontStyles.bodySmallBold)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                .padding(.bottom, 4)
                
                // Render each option
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    optionCard(tier: tier, option: option)
                    
                    // Add spacing between options, but not after the last one
                    if index < options.count - 1 {
                        Rectangle()
                            .fill(KingdomTheme.Colors.inkLight.opacity(0.3))
                            .frame(height: 1)
                            .padding(.vertical, KingdomTheme.Spacing.small)
                    }
                }
            } else if let option = options.first {
                // Single option - render with option data
                optionCard(tier: tier, option: option)
            } else {
                // Fallback to legacy rendering (no options array from backend)
                legacyTierContent(tier: tier)
            }
            
            // Status indicator - shared across all options at this tier
            tierStatusIndicator(tier: tier)
        }
    }
    
    /// Renders a single buildable option (room) card
    private func optionCard(tier: Int, option: PropertyTierOption) -> some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            // Option header with icon
            HStack(spacing: KingdomTheme.Spacing.medium) {
                Image(systemName: option.icon)
                    .font(FontStyles.iconLarge)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .brutalistBadge(
                        backgroundColor: tierColor(tier),
                        cornerRadius: 10,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.name)
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    Text(option.description)
                        .font(FontStyles.bodySmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
                
                // Status badge
                if tier <= currentTier {
                    Text("Unlocked")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.black)
                                    .offset(x: 1, y: 1)
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(KingdomTheme.Colors.inkMedium)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.black, lineWidth: 1.5)
                                    )
                            }
                        )
                }
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Benefits from option
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                sectionHeader(icon: "star.fill", title: "Benefits")
                
                ForEach(option.benefits, id: \.self) { benefit in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: tier <= currentTier ? "checkmark.circle.fill" : "lock.circle.fill")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(tier <= currentTier ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.inkLight)
                            .frame(width: 20)
                        
                        Text(benefit)
                            .font(FontStyles.bodySmall)
                            .foregroundColor(tier <= currentTier ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.inkMedium)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Cost section using option's costs
            if let actions = option.baseActionsRequired, actions > 0,
               let goldPerAction = option.goldPerAction {
                let perActionCosts = option.perActionCosts
                
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(icon: "dollarsign.circle.fill", title: "Build Cost")
                    
                    // Cost table
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Table header
                            HStack(spacing: 16) {
                                Text("Build")
                                    .frame(width: 100, alignment: .leading)
                                
                                Text("Actions")
                                    .frame(width: 60, alignment: .center)
                                
                                Text("Gold/Act")
                                    .frame(width: 70, alignment: .center)
                                
                                ForEach(perActionCosts, id: \.resource) { cost in
                                    Text("\(resourceDisplayName(cost.resource))/Act")
                                        .frame(width: 70, alignment: .center)
                                }
                            }
                            .font(FontStyles.labelBold)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            
                            Divider()
                                .overlay(Color.black.opacity(0.1))
                            
                            // Table row with values
                            HStack(spacing: 16) {
                                Text(option.name)
                                    .frame(width: 100, alignment: .leading)
                                
                                Text("\(actions)")
                                    .frame(width: 60, alignment: .center)
                                
                                Text("\(Int(goldPerAction))g")
                                    .frame(width: 70, alignment: .center)
                                
                                ForEach(perActionCosts, id: \.resource) { cost in
                                    Text("\(cost.amount)")
                                        .frame(width: 70, alignment: .center)
                                }
                            }
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                    }
                    .background(Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black, lineWidth: 2)
                    )
                    .padding(.top, 4)
                    
                    // Total summary
                    Text("Total cost is \(buildTotalSummary(actions: actions, goldPerAction: goldPerAction, perActionCosts: perActionCosts)).")
                        .font(FontStyles.bodySmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }
        }
    }
    
    /// Legacy tier content for backwards compatibility (when no options array exists)
    private func legacyTierContent(tier: Int) -> some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            // Tier header with icon
            HStack(spacing: KingdomTheme.Spacing.medium) {
                tierIcon(tier)
                    .font(FontStyles.iconLarge)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .brutalistBadge(
                        backgroundColor: tierColor(tier),
                        cornerRadius: 10,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tierName(tier))
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                Spacer()
                
                if tier <= currentTier {
                    Text("Unlocked")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.black)
                                    .offset(x: 1, y: 1)
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(KingdomTheme.Colors.inkMedium)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.black, lineWidth: 1.5)
                                    )
                            }
                        )
                }
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Benefits
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                sectionHeader(icon: "star.fill", title: "Benefits")
                
                ForEach(tierBenefits(tier), id: \.self) { benefit in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: tier <= currentTier ? "checkmark.circle.fill" : "lock.circle.fill")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(tier <= currentTier ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.inkLight)
                            .frame(width: 20)
                        
                        Text(benefit)
                            .font(FontStyles.bodySmall)
                            .foregroundColor(tier <= currentTier ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.inkMedium)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Cost section
            if let actions = tierManager.propertyTierActions(tier), actions > 0 {
                let goldPerAction = tierManager.propertyGoldPerAction(tier) ?? 0
                let perActionCosts = tierManager.propertyPerActionCosts(tier)
                
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(icon: "dollarsign.circle.fill", title: "Upgrade Cost")
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(spacing: 0) {
                            HStack(spacing: 16) {
                                Text("Upgrade")
                                    .frame(width: 100, alignment: .leading)
                                
                                Text("Actions")
                                    .frame(width: 60, alignment: .center)
                                
                                Text("Gold/Act")
                                    .frame(width: 70, alignment: .center)
                                
                                ForEach(perActionCosts, id: \.resource) { cost in
                                    Text("\(resourceDisplayName(cost.resource))/Act")
                                        .frame(width: 70, alignment: .center)
                                }
                            }
                            .font(FontStyles.labelBold)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            
                            Divider()
                                .overlay(Color.black.opacity(0.1))
                            
                            HStack(spacing: 16) {
                                Text("\(tierName(tier - 1)) → \(tierName(tier))")
                                    .frame(width: 100, alignment: .leading)
                                
                                Text("\(actions)")
                                    .frame(width: 60, alignment: .center)
                                
                                Text("\(Int(goldPerAction))g")
                                    .frame(width: 70, alignment: .center)
                                
                                ForEach(perActionCosts, id: \.resource) { cost in
                                    Text("\(cost.amount)")
                                        .frame(width: 70, alignment: .center)
                                }
                            }
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                    }
                    .background(Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black, lineWidth: 2)
                    )
                    .padding(.top, 4)
                    
                    Text("Total cost is \(buildTotalSummary(actions: actions, goldPerAction: goldPerAction, perActionCosts: perActionCosts)).")
                        .font(FontStyles.bodySmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }
        }
    }
    
    /// Status indicator shown at the bottom of tier content
    private func tierStatusIndicator(tier: Int) -> some View {
        Group {
            if tier <= currentTier {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Unlocked")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black)
                            .offset(x: 2, y: 2)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(KingdomTheme.Colors.buttonSuccess)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.black, lineWidth: 2)
                            )
                    }
                )
            } else if currentTier == 0 && tier == 1 {
                HStack(spacing: 8) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Purchase land to unlock")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black)
                            .offset(x: 2, y: 2)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(KingdomTheme.Colors.parchment)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.black, lineWidth: 2)
                            )
                    }
                )
            } else if tier > currentTier + 1 {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .medium))
                    Text(currentTier == 0 ? "Purchase land first" : "Build \(tierName(currentTier + 1)) first")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black)
                            .offset(x: 2, y: 2)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(KingdomTheme.Colors.parchmentLight)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.black, lineWidth: 2)
                            )
                    }
                )
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Available to Upgrade")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black)
                            .offset(x: 2, y: 2)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(KingdomTheme.Colors.buttonSuccess)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.black, lineWidth: 2)
                            )
                    }
                )
            }
        }
    }
    
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(FontStyles.iconSmall)
                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
            Text(title)
                .font(FontStyles.bodyMediumBold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
    }
    
    @ViewBuilder
    private func tierIcon(_ tier: Int) -> some View {
        switch tier {
        case 1: Image(systemName: "rectangle.dashed")
        case 2: Image(systemName: "house.fill")
        case 3: Image(systemName: "hammer.fill")
        case 4: Image(systemName: "building.columns.fill")
        case 5: Image(systemName: "crown.fill")
        default: Image(systemName: "questionmark")
        }
    }
    
    private func tierColor(_ tier: Int) -> Color {
        // Consistent green for all property tiers
        return KingdomTheme.Colors.buttonSuccess
    }
    
    private func tierName(_ tier: Int) -> String {
        // Fetch from backend tier manager (single source of truth)
        if tier <= 0 {
            return "None"
        }
        return tierManager.propertyTierName(tier)
    }
    
    private func tierBenefits(_ tier: Int) -> [String] {
        // Fetch from backend tier manager (single source of truth)
        return tierManager.propertyTierBenefits(tier)
    }
    
    private func resourceDisplayName(_ resource: String) -> String {
        // Get display name from TierManager, fallback to capitalized resource
        return tierManager.resourceInfo(resource)?.displayName ?? resource.capitalized
    }
    
    private func buildTotalSummary(actions: Int, goldPerAction: Double, perActionCosts: [PropertyPerActionCost]) -> String {
        var parts: [String] = []
        
        let totalGold = Int(goldPerAction) * actions
        parts.append("\(totalGold)g")
        
        for cost in perActionCosts {
            let total = cost.amount * actions
            let name = resourceDisplayName(cost.resource).lowercased()
            parts.append("\(total) \(name)")
        }
        
        return parts.joined(separator: ", ")
    }
}
