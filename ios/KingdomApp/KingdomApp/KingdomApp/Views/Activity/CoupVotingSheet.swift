import SwiftUI

struct CoupVotingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let coupData: CoupNotificationData
    let onVote: (String) -> Void
    
    @State private var selectedSide: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 60))
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                            
                            Text("Coup in \(coupData.kingdomName)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("\(coupData.initiatorName) is attempting to seize power!")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top)
                        
                        // Time Remaining
                        VStack(spacing: 4) {
                            Text("Time Remaining")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text(coupData.timeRemainingFormatted)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        
                        // Initiator Stats
                        if let stats = coupData.initiatorStats {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "person.fill")
                                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                                    Text("Meet Your New Ruler")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                
                                VStack(spacing: 8) {
                                    StatRow(label: "Level", value: "\(stats.level)", icon: "star.fill", color: .blue)
                                    StatRow(label: "Kingdom Rep", value: "\(stats.kingdomReputation)", icon: "heart.fill", color: .purple)
                                    StatRow(label: "Global Rep", value: "\(stats.reputation)", icon: "globe", color: .cyan)
                                    
                                    Divider().background(Color.gray.opacity(0.3))
                                    
                                    StatRow(label: "Attack", value: "\(stats.attackPower)", icon: "sword.fill", color: .red)
                                    StatRow(label: "Defense", value: "\(stats.defensePower)", icon: "shield.fill", color: .blue)
                                    StatRow(label: "Leadership", value: "\(stats.leadership)", icon: "crown.fill", color: KingdomTheme.Colors.inkMedium)
                                    StatRow(label: "Building", value: "\(stats.buildingSkill)", icon: "hammer.fill", color: .orange)
                                    StatRow(label: "Intelligence", value: "\(stats.intelligence)", icon: "brain.head.profile", color: .green)
                                    
                                    Divider().background(Color.gray.opacity(0.3))
                                    
                                    StatRow(label: "Contracts Done", value: "\(stats.contractsCompleted)", icon: "checkmark.circle.fill", color: .green)
                                    StatRow(label: "Work Done", value: "\(stats.totalWorkContributed)", icon: "hammer.circle.fill", color: .orange)
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                        
                        // Current Forces
                        HStack(spacing: 40) {
                            ForceDisplay(
                                icon: "sword.fill",
                                count: coupData.attackerCount,
                                label: "Attackers",
                                color: .red
                            )
                            
                            ForceDisplay(
                                icon: "shield.fill",
                                count: coupData.defenderCount,
                                label: "Defenders",
                                color: .blue
                            )
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        
                        // User's current side (if already joined)
                        if let userSide = coupData.userSide {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("You joined the \(userSide)")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(12)
                        }
                        
                        // Voting Options (if can join)
                        if coupData.canJoin {
                            VStack(spacing: 16) {
                                Text("Choose Your Side")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                // Attackers Button
                                SideButton(
                                    title: "Join Attackers",
                                    subtitle: "Help overthrow the ruler",
                                    icon: "sword.fill",
                                    color: .red,
                                    isSelected: selectedSide == "attackers"
                                ) {
                                    selectedSide = "attackers"
                                }
                                
                                // Defenders Button
                                SideButton(
                                    title: "Join Defenders",
                                    subtitle: "Protect the current ruler",
                                    icon: "shield.fill",
                                    color: .blue,
                                    isSelected: selectedSide == "defenders"
                                ) {
                                    selectedSide = "defenders"
                                }
                            }
                            .padding(.top)
                        }
                        
                        // Info Box
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Coup Mechanics")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                InfoRow(text: "Attackers need 25% advantage to win")
                                InfoRow(text: "Failed attackers lose everything")
                                InfoRow(text: "Successful attackers seize power")
                                InfoRow(text: "Defenders receive rewards if they win")
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding()
                }
            }
            .navigationTitle("Coup Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if coupData.canJoin && selectedSide != nil {
                        Button("Confirm") {
                            if let side = selectedSide {
                                onVote(side)
                                dismiss()
                            }
                        }
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .fontWeight(.bold)
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ForceDisplay: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

struct SideButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                }
            }
            .padding()
            .background(isSelected ? color.opacity(0.2) : Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct InfoRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.gray)
            Text(text)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Preview

#Preview {
    CoupVotingSheet(
        coupData: CoupNotificationData(
            id: 1,
            kingdomId: "test",
            kingdomName: "Test Kingdom",
            initiatorName: "John Doe",
            initiatorStats: InitiatorStats(
                reputation: 500,
                kingdomReputation: 350,
                attackPower: 15,
                defensePower: 12,
                leadership: 8,
                buildingSkill: 10,
                intelligence: 6,
                contractsCompleted: 25,
                totalWorkContributed: 150,
                level: 12
            ),
            timeRemainingSeconds: 3600,
            attackerCount: 5,
            defenderCount: 3,
            userSide: nil,
            canJoin: true,
            attackerVictory: nil,
            userWon: nil
        ),
        onVote: { _ in }
    )
}

