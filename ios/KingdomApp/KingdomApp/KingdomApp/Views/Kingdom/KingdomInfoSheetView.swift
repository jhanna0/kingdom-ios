import SwiftUI

// Sheet wrapper for KingdomInfoCard with proper dismiss handling
struct KingdomInfoSheetView: View {
    let kingdom: Kingdom
    @ObservedObject var player: Player
    @ObservedObject var viewModel: MapViewModel
    let isPlayerInside: Bool
    let onViewKingdom: () -> Void
    let onViewAllKingdoms: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var showClaimError = false
    @State private var claimErrorMessage = ""
    @State private var isClaiming = false
    @State private var weather: WeatherData?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.xLarge) {
                // Header with medieval styling
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "building.columns.fill")
                        .font(FontStyles.iconExtraLarge)
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .brutalistBadge(
                            backgroundColor: Color(
                                red: kingdom.color.strokeRGBA.red,
                                green: kingdom.color.strokeRGBA.green,
                                blue: kingdom.color.strokeRGBA.blue
                            ),
                            cornerRadius: 12,
                            shadowOffset: 3,
                            borderWidth: 2
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kingdom.name)
                            .font(FontStyles.displaySmall)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        if kingdom.isUnclaimed {
                            Text("No ruler")
                                .font(FontStyles.bodySmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        } else {
                            HStack(spacing: 4) {
                                Text("Ruled by \(kingdom.rulerName)")
                                    .font(FontStyles.bodySmall)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    if kingdom.isUnclaimed {
                        Text("Unclaimed")
                            .font(FontStyles.labelSmall)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.error, cornerRadius: 6)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Kingdom color divider with brutalist style
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 3)
                    .padding(.horizontal)
                
                // Ruler Actions (moved to top, after header)
                if isPlayerInside && kingdom.rulerId == player.playerId {
                    VStack(spacing: KingdomTheme.Spacing.medium) {
                        Button(action: onViewKingdom) {
                            HStack(spacing: KingdomTheme.Spacing.medium) {
                                Image(systemName: "crown.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 54, height: 54)
                                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.imperialGold, cornerRadius: 14, shadowOffset: 3, borderWidth: 2.5)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Manage Your Kingdom")
                                        .font(FontStyles.bodyLargeBold)
                                        .foregroundColor(KingdomTheme.Colors.inkDark)
                                    Text("Buildings, taxes & decrees")
                                        .font(FontStyles.labelMedium)
                                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(FontStyles.iconMedium)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                            }
                            .padding(KingdomTheme.Spacing.medium)
                        }
                        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                        
                        Button(action: onViewAllKingdoms) {
                            HStack(spacing: KingdomTheme.Spacing.medium) {
                                Image(systemName: "map.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 54, height: 54)
                                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonPrimary, cornerRadius: 14, shadowOffset: 3, borderWidth: 2.5)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("View All Kingdoms")
                                        .font(FontStyles.bodyLargeBold)
                                        .foregroundColor(KingdomTheme.Colors.inkDark)
                                    Text("Explore your empire")
                                        .font(FontStyles.labelMedium)
                                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(FontStyles.iconMedium)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                            }
                            .padding(KingdomTheme.Spacing.medium)
                        }
                        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                    }
                    .padding(.horizontal)
                } else if kingdom.canClaim {
                    // Backend says we can claim!
                    Button(action: {
                        isClaiming = true
                        Task {
                            do {
                                try await viewModel.claimKingdom()
                                // Dismiss sheet after short delay to let celebration popup show
                                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                                dismiss()
                            } catch {
                                isClaiming = false
                                claimErrorMessage = error.localizedDescription
                                showClaimError = true
                                print("❌ Failed to claim: \(error.localizedDescription)")
                            }
                        }
                    }) {
                        HStack(spacing: KingdomTheme.Spacing.medium) {
                            if isClaiming {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(1.2)
                            } else {
                                Image(systemName: "crown.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            Text(isClaiming ? "Claiming Your Kingdom..." : "Claim This Kingdom")
                                .font(FontStyles.headingMedium)
                                .fontWeight(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KingdomTheme.Spacing.large)
                        .foregroundColor(.white)
                    }
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.error, cornerRadius: 12, shadowOffset: 4, borderWidth: 3)
                    .disabled(isClaiming)
                    .padding(.horizontal)
                    .alert("Claim Failed", isPresented: $showClaimError) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text(claimErrorMessage)
                    }
                } else if isPlayerInside {
                    // Already present but someone else rules it
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        Text("You are here")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(KingdomTheme.Spacing.small)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 8)
                    .padding(.horizontal)
                } else {
                    // Not inside this kingdom
                    HStack(spacing: 6) {
                        Image(systemName: "location.circle")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                        Text("You must travel here first")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                    }
                    .padding(KingdomTheme.Spacing.small)
                    .padding(.horizontal)
                }
                
                // Population Stats
                VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                    Text("Population")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .padding(.horizontal)
                    
                    HStack(spacing: KingdomTheme.Spacing.medium) {
                        VStack(spacing: 8) {
                            Image(systemName: "person.3.fill")
                                .font(FontStyles.iconMedium)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .brutalistBadge(backgroundColor: KingdomTheme.Colors.royalBlue, cornerRadius: 10)
                            
                            Text("\(kingdom.checkedInPlayers)")
                                .font(FontStyles.headingLarge)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Text("Present Now")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
                        
                        VStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(FontStyles.iconMedium)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSuccess, cornerRadius: 10)
                            
                            Text("\(kingdom.weeklyUniqueCheckIns)")
                                .font(FontStyles.headingLarge)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Text("This Week")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
                    }
                    .padding(.horizontal)
                }
                
                // Kingdom Laws - Tax & Fees (visible to all citizens)
                if !kingdom.isUnclaimed {
                    kingdomLawsCard
                }
                
                // Kingdom Buildings & Bonuses (visible to all citizens)
                if !kingdom.isUnclaimed {
                    kingdomBuildingsCard
                }
                
                // WEATHER CARD
                SimpleWeatherCard(weather: weather)
                    .padding(.horizontal)
                
                // Player Activity Feed
                PlayerActivityFeedCard(kingdomId: kingdom.id)
                    .padding(.horizontal)
                
                // Military Strength / Intelligence
                MilitaryStrengthCard(
                    strength: viewModel.militaryStrengthCache[kingdom.id],
                    kingdom: kingdom,
                    player: player,
                    onGatherIntel: {
                        Task {
                            do {
                                _ = try await viewModel.gatherIntelligence(kingdomId: kingdom.id)
                            } catch {
                                print("❌ Failed to gather intelligence: \(error)")
                            }
                        }
                    }
                )
                .padding(.horizontal)
                .task {
                    // Load military strength when sheet opens
                    print("🎯 KingdomInfoSheet loading strength for: \(kingdom.id)")
                    if viewModel.militaryStrengthCache[kingdom.id] == nil {
                        print("🎯 Cache miss, fetching...")
                        await viewModel.fetchMilitaryStrength(kingdomId: kingdom.id)
                    } else {
                        print("🎯 Cache hit!")
                    }
                }
                
                // Active Contract Section
                if let contract = kingdom.activeContract {
                    VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .font(FontStyles.iconSmall)
                                .foregroundColor(KingdomTheme.Colors.buttonWarning)
                            Text("Active Contract")
                                .font(FontStyles.bodyMediumBold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            Spacer()
                            if contract.isComplete {
                                Text("Complete")
                                    .font(FontStyles.labelSmall)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSuccess, cornerRadius: 6, shadowOffset: 1, borderWidth: 1.5)
                            } else {
                                Text("In Progress")
                                    .font(FontStyles.labelSmall)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonWarning, cornerRadius: 6, shadowOffset: 1, borderWidth: 1.5)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "building.2.fill")
                                    .font(FontStyles.iconMini)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                                Text("\(contract.buildingType) Level \(contract.buildingLevel)")
                                    .font(FontStyles.labelMedium)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                            }
                            
                            HStack(spacing: 8) {
                                Label("\(contract.contributorCount) contributors", systemImage: "person.2.fill")
                                    .font(FontStyles.labelTiny)
                                    .foregroundColor(KingdomTheme.Colors.inkLight)
                                
                                Label("\(contract.rewardPool) pool", systemImage: "g.circle.fill")
                                    .font(FontStyles.labelTiny)
                                    .foregroundColor(KingdomTheme.Colors.goldLight)
                            }
                            
                            // Progress bar
                            if !contract.isComplete {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text("Progress")
                                            .font(FontStyles.labelTiny)
                                            .foregroundColor(KingdomTheme.Colors.inkLight)
                                        Spacer()
                                        Text(String(format: "%.0f%%", contract.progress * 100))
                                            .font(FontStyles.labelTiny)
                                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                                    }
                                    
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            Rectangle()
                                                .fill(KingdomTheme.Colors.inkDark.opacity(0.1))
                                                .frame(height: 6)
                                                .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                                            
                                            Rectangle()
                                                .fill(KingdomTheme.Colors.buttonWarning)
                                                .frame(width: geometry.size.width * contract.progress, height: 6)
                                        }
                                    }
                                    .frame(height: 6)
                                }
                            }
                        }
                    }
                    .padding(KingdomTheme.Spacing.medium)
                    .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
                    .padding(.horizontal)
                }
                
                // Action buttons - Medieval war council style (backend controls visibility)
                if kingdom.canDeclareWar || kingdom.canFormAlliance {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 2)
                        .padding(.horizontal)
                    
                    VStack(spacing: KingdomTheme.Spacing.small) {
                        if kingdom.canDeclareWar {
                            Button(action: {
                                // TODO: Implement declare war
                                print("Declare war on \(kingdom.name)")
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "flame.fill")
                                        .font(FontStyles.iconSmall)
                                        .foregroundColor(.white)
                                    Text("Declare War")
                                        .font(FontStyles.bodyMediumBold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(KingdomTheme.Spacing.medium)
                                .foregroundColor(.white)
                            }
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonDanger, cornerRadius: 10)
                        }
                        
                        if kingdom.canFormAlliance {
                            Button(action: {
                                // TODO: Implement form alliance
                                print("Form alliance with \(kingdom.name)")
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "hand.raised.fill")
                                        .font(FontStyles.iconSmall)
                                        .foregroundColor(.white)
                                    Text("Form Alliance")
                                        .font(FontStyles.bodyMediumBold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(KingdomTheme.Spacing.medium)
                                .foregroundColor(.white)
                            }
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 10)
                        }
                        
                        Button(action: {
                            // TODO: Implement stage coup
                            print("Stage coup in \(kingdom.name)")
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "bolt.fill")
                                    .font(FontStyles.iconSmall)
                                    .foregroundColor(.white)
                                Text("Stage Coup")
                                    .font(FontStyles.bodyMediumBold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(KingdomTheme.Spacing.medium)
                            .foregroundColor(.white)
                        }
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonPrimary, cornerRadius: 10)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
            .padding(.top)
        }
        .background(KingdomTheme.Colors.parchment)
        .task {
            // Load weather
            do {
                let response = try await KingdomAPIService.shared.weather.getKingdomWeather(kingdomId: kingdom.id)
                weather = response.weather
                print("✅ Weather loaded: \(weather?.display_description ?? "none")")
            } catch {
                print("⚠️ Weather error: \(error)")
            }
        }
    }
    
    // MARK: - Kingdom Laws Card
    
    private var kingdomLawsCard: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: "scroll.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("Kingdom Laws")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            HStack(spacing: KingdomTheme.Spacing.medium) {
                // Tax Rate
                VStack(spacing: 6) {
                    Image(systemName: "percent")
                        .font(FontStyles.iconSmall)
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.imperialGold, cornerRadius: 8, shadowOffset: 2, borderWidth: 2)
                    
                    Text("\(kingdom.taxRate)%")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Tax Rate")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, KingdomTheme.Spacing.small)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
                
                // Travel Fee
                VStack(spacing: 6) {
                    Image(systemName: "figure.walk.arrival")
                        .font(FontStyles.iconSmall)
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonPrimary, cornerRadius: 8, shadowOffset: 2, borderWidth: 2)
                    
                    Text("\(kingdom.travelFee)g")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Entry Fee")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, KingdomTheme.Spacing.small)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
            }
            
            // Explanation text
            Text("Tax is collected from mining & crafting. Entry fee is charged when traveling here.")
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkLight)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .padding(.horizontal)
    }
    
    // MARK: - Kingdom Buildings Card (FULLY DYNAMIC from backend)
    
    private var kingdomBuildingsCard: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: "building.2.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("Kingdom Buildings")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // DYNAMIC: Get ALL buildings from backend metadata
            let sortedBuildings = kingdom.buildingMetadata.values.sorted { a, b in
                // Built first, then alphabetical
                if a.level > 0 && b.level <= 0 { return true }
                if a.level <= 0 && b.level > 0 { return false }
                return a.displayName < b.displayName
            }
            
            if sortedBuildings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "hammer")
                        .font(.system(size: 28))
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                    
                    Text("Loading buildings...")
                        .font(FontStyles.bodyMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(sortedBuildings, id: \.type) { building in
                        let isBuilt = building.level > 0
                        let color = Color(hex: building.colorHex) ?? KingdomTheme.Colors.inkMedium
                        
                        HStack(spacing: 10) {
                            Image(systemName: building.icon)
                                .font(FontStyles.iconSmall)
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .brutalistBadge(
                                    backgroundColor: isBuilt ? color : KingdomTheme.Colors.inkLight,
                                    cornerRadius: 8,
                                    shadowOffset: 2,
                                    borderWidth: 2
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(building.displayName)
                                        .font(FontStyles.bodySmall)
                                        .foregroundColor(isBuilt ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.inkMedium)
                                    
                                    if isBuilt {
                                        Text("Lv.\(building.level)")
                                            .font(FontStyles.labelTiny)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(color)
                                            .cornerRadius(4)
                                    } else {
                                        Text("Not Built")
                                            .font(FontStyles.labelTiny)
                                            .foregroundColor(KingdomTheme.Colors.inkLight)
                                            .italic()
                                    }
                                }
                                
                                // Description from backend
                                Text(building.description)
                                    .font(FontStyles.labelTiny)
                                    .foregroundColor(isBuilt ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.inkLight)
                            }
                            
                            Spacer()
                        }
                        .padding(10)
                        .background(isBuilt ? KingdomTheme.Colors.parchment : KingdomTheme.Colors.parchmentLight)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black, lineWidth: 1.5)
                        )
                    }
                }
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .padding(.horizontal)
    }
}

