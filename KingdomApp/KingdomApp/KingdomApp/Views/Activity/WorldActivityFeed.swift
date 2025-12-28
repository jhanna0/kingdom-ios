import SwiftUI

// MARK: - Citizens Preview (Compact for KingdomInfoCard)

struct CitizensPreview: View {
    let kingdomName: String
    @ObservedObject var worldSimulator: WorldSimulator
    
    var citizens: [Citizen] {
        worldSimulator.getCitizens(in: kingdomName)
    }
    
    var onlineCitizens: [Citizen] {
        worldSimulator.getOnlineCitizens(in: kingdomName)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("👥 Citizens")
                    .font(KingdomTheme.Typography.subheadline())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("\(onlineCitizens.count)/\(citizens.count)")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            
            if citizens.isEmpty {
                Text("No citizens yet - claim this kingdom to attract settlers!")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                    .italic()
            } else {
                // Show first 3 citizens
                ForEach(citizens.prefix(3)) { citizen in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(citizen.isOnline ? Color.green : Color.gray.opacity(0.4))
                            .frame(width: 6, height: 6)
                        Text(citizen.name)
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        Spacer()
                        Text("⚔️\(citizen.attackPower) 🛡️\(citizen.defensePower)")
                            .font(.system(size: 10))
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                    }
                }
                
                if citizens.count > 3 {
                    Text("+ \(citizens.count - 3) more citizens")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
            }
        }
        .padding(KingdomTheme.Spacing.small)
        .background(KingdomTheme.Colors.parchmentMuted)
        .cornerRadius(KingdomTheme.CornerRadius.small)
    }
}

// MARK: - Kingdom Citizens View (Full)
// Shows the NPCs in your kingdom and what they're doing

struct KingdomCitizensView: View {
    let kingdomName: String
    @ObservedObject var worldSimulator: WorldSimulator
    
    var citizens: [Citizen] {
        worldSimulator.getCitizens(in: kingdomName)
    }
    
    var onlineCitizens: [Citizen] {
        worldSimulator.getOnlineCitizens(in: kingdomName)
    }
    
    var activityLog: [ActivityLog] {
        worldSimulator.getActivityFor(kingdom: kingdomName)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("👥 Citizens")
                    .font(KingdomTheme.Typography.headline())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("\(onlineCitizens.count)/\(citizens.count) online")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            
            if citizens.isEmpty {
                Text("No citizens yet")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                    .italic()
                    .padding(.vertical, 8)
            } else {
                // Citizen list
                ForEach(citizens.prefix(8)) { citizen in
                    CitizenRow(citizen: citizen)
                }
                
                if citizens.count > 8 {
                    Text("+ \(citizens.count - 8) more citizens")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
            }
            
            // Recent activity
            if !activityLog.isEmpty {
                Divider()
                
                Text("📜 Recent Activity")
                    .font(KingdomTheme.Typography.subheadline())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                ForEach(activityLog.prefix(5)) { log in
                    HStack(spacing: 8) {
                        Text(log.icon)
                            .font(.caption)
                        Text(log.message)
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        Spacer()
                        Text(log.timeAgo)
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                    }
                }
            }
        }
        .padding()
        .background(KingdomTheme.Colors.parchmentHighlight)
        .cornerRadius(12)
    }
}

// MARK: - Citizen Row

struct CitizenRow: View {
    let citizen: Citizen
    
    var body: some View {
        HStack(spacing: 8) {
            // Online indicator
            Circle()
                .fill(citizen.isOnline ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 8, height: 8)
            
            // Name
            Text(citizen.name)
                .font(KingdomTheme.Typography.caption())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Spacer()
            
            // Activity
            Text(citizen.currentActivity.rawValue)
                .font(KingdomTheme.Typography.caption())
                .foregroundColor(KingdomTheme.Colors.inkLight)
            
            // Stats
            HStack(spacing: 4) {
                Text("⚔️\(citizen.attackPower)")
                    .font(.caption2)
                Text("🛡️\(citizen.defensePower)")
                    .font(.caption2)
            }
            .foregroundColor(KingdomTheme.Colors.inkLight)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Activity Badge (for HUD)

struct ActivityBadge: View {
    @ObservedObject var worldSimulator: WorldSimulator
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text("👥")
                    .font(.caption)
                Text("\(worldSimulator.recentActivity.count)")
                    .font(KingdomTheme.Typography.caption())
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(KingdomTheme.Colors.parchmentRich)
            )
            .overlay(
                Capsule()
                    .stroke(KingdomTheme.Colors.goldWarm, lineWidth: 1)
            )
            .foregroundColor(KingdomTheme.Colors.inkDark)
        }
    }
}

// MARK: - Full Activity Feed Sheet

struct WorldActivityFeed: View {
    @ObservedObject var worldSimulator: WorldSimulator
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                KingdomTheme.Colors.parchment
                    .ignoresSafeArea()
                
                if worldSimulator.recentActivity.isEmpty {
                    VStack(spacing: 16) {
                        Text("📜")
                            .font(.system(size: 60))
                        Text("No recent activity")
                            .font(KingdomTheme.Typography.headline())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        Text("Your citizens' activities will appear here")
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(worldSimulator.recentActivity) { log in
                                ActivityRow(log: log)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("📜 Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(KingdomTheme.Colors.gold)
                }
            }
        }
    }
}

struct ActivityRow: View {
    let log: ActivityLog
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(log.icon)
                .font(.title3)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(log.message)
                    .font(KingdomTheme.Typography.subheadline())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                HStack {
                    Text(log.timeAgo)
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                    
                    Text("•")
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                    
                    Text(log.kingdomName)
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.goldWarm)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(KingdomTheme.Colors.parchmentHighlight)
        )
    }
}
