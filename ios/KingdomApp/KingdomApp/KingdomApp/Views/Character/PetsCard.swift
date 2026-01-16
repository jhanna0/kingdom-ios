import SwiftUI

// MARK: - Color Mapping Helper

private func mapColorName(_ colorName: String) -> Color {
    switch colorName.lowercased() {
    case "goldlight", "gold": return KingdomTheme.Colors.goldLight
    case "gray": return .gray
    case "blue": return .blue
    case "brown": return .brown
    case "green": return .green
    case "red": return .red
    case "purple": return .purple
    case "orange": return .orange
    case "cyan": return .cyan
    case "yellow": return .yellow
    default: return KingdomTheme.Colors.inkMedium
    }
}

// MARK: - Pets Card View

/// Shows pets owned by a player - used in CharacterSheet and PlayerProfile
struct PetsCard: View {
    let pets: [Player.PlayerPet]
    var title: String = "Pets"
    var showEmpty: Bool = false
    
    @State private var selectedPet: Player.PlayerPet? = nil
    
    var body: some View {
        // Only show if player has pets or showEmpty is true
        if !pets.isEmpty || showEmpty {
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                HStack {
                    Image(systemName: "pawprint.fill")
                        .font(FontStyles.iconMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Text(title)
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Spacer()
                    
                    // Total pet count badge
                    let totalPets = pets.reduce(0) { $0 + $1.quantity }
                    if totalPets > 0 {
                        Text("\(totalPets)")
                            .font(FontStyles.labelBold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .brutalistBadge(
                                backgroundColor: KingdomTheme.Colors.royalBlue,
                                cornerRadius: 10,
                                shadowOffset: 1,
                                borderWidth: 1.5
                            )
                    }
                }
                
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 2)
                
                if pets.isEmpty {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: "pawprint.circle")
                            .font(.system(size: 36))
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                        
                        Text("No pets yet")
                            .font(FontStyles.bodyMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        Text("Complete activities to find companions!")
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    // Pets grid
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
                    
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(pets) { pet in
                            PetGridItem(pet: pet)
                                .onTapGesture {
                                    selectedPet = pet
                                }
                        }
                    }
                }
            }
            .padding()
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
            .alert(item: $selectedPet) { pet in
                Alert(
                    title: Text(pet.displayName),
                    message: Text("\(pet.description)\n\nSource: \(pet.source ?? "Unknown")"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

// MARK: - Pet Grid Item

struct PetGridItem: View {
    let pet: Player.PlayerPet
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                // Pet icon
                Image(systemName: pet.icon)
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .brutalistBadge(
                        backgroundColor: mapColorName(pet.colorName),
                        cornerRadius: 10,
                        shadowOffset: 2,
                        borderWidth: 2
                    )
                
                // Quantity badge (only show if > 1)
                if pet.quantity > 1 {
                    Text("x\(pet.quantity)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .brutalistBadge(
                            backgroundColor: .black,
                            cornerRadius: 8,
                            shadowOffset: 1,
                            borderWidth: 1.5
                        )
                        .offset(x: 6, y: -6)
                }
            }
            
            Text(pet.displayName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10)
    }
}

// MARK: - Public Profile Pets Card

/// Version for showing another player's pets (from PlayerPublicProfile)
struct ProfilePetsCard: View {
    let pets: [PetData]
    var title: String = "Pets"
    var showEmpty: Bool = false
    
    @State private var selectedPet: PetData? = nil
    
    var body: some View {
        if !pets.isEmpty || showEmpty {
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                HStack {
                    Image(systemName: "pawprint.fill")
                        .font(FontStyles.iconMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Text(title)
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Spacer()
                    
                    // Total pet count badge
                    let totalPets = pets.reduce(0) { $0 + $1.quantity }
                    if totalPets > 0 {
                        Text("\(totalPets)")
                            .font(FontStyles.labelBold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .brutalistBadge(
                                backgroundColor: KingdomTheme.Colors.royalBlue,
                                cornerRadius: 10,
                                shadowOffset: 1,
                                borderWidth: 1.5
                            )
                    }
                }
                
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 2)
                
                if pets.isEmpty {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: "pawprint.circle")
                            .font(.system(size: 36))
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                        
                        Text("No pets yet")
                            .font(FontStyles.bodyMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    // Pets grid
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
                    
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(pets) { pet in
                            ProfilePetGridItem(pet: pet)
                                .onTapGesture {
                                    selectedPet = pet
                                }
                        }
                    }
                }
            }
            .padding()
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
            .alert(item: $selectedPet) { pet in
                Alert(
                    title: Text(pet.display_name),
                    message: Text("\(pet.description)\n\nSource: \(pet.source ?? "Unknown")"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

// MARK: - Profile Pet Grid Item

struct ProfilePetGridItem: View {
    let pet: PetData
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                // Pet icon
                Image(systemName: pet.icon)
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .brutalistBadge(
                        backgroundColor: mapColorName(pet.color),
                        cornerRadius: 10,
                        shadowOffset: 2,
                        borderWidth: 2
                    )
                
                // Quantity badge (only show if > 1)
                if pet.quantity > 1 {
                    Text("x\(pet.quantity)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .brutalistBadge(
                            backgroundColor: .black,
                            cornerRadius: 8,
                            shadowOffset: 1,
                            borderWidth: 1.5
                        )
                        .offset(x: 6, y: -6)
                }
            }
            
            Text(pet.display_name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        PetsCard(
            pets: [
                Player.PlayerPet(
                    id: "pet_fish",
                    quantity: 3,
                    displayName: "Pet Fish",
                    icon: "fish.circle.fill",
                    colorName: "cyan",
                    description: "A rare companion fish caught while fishing!",
                    source: "Rare drop from Catfish and Legendary Carp"
                )
            ]
        )
        
        PetsCard(pets: [], showEmpty: true)
    }
    .padding()
    .background(KingdomTheme.Colors.parchment)
}
