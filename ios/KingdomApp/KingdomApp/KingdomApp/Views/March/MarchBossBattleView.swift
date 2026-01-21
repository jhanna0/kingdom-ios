import SwiftUI

/// View for the boss battle at the end of each wave
struct MarchBossBattleView: View {
    @ObservedObject var viewModel: MarchViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Spacer()
            
            // Battle arena
            battleArena
            
            Spacer()
            
            statsSection
            
            // Tug of war bar
            if let battle = viewModel.bossBattle {
                tugOfWarSection(battle: battle)
            }
            
            // Action button
            tapHint
            actionButtons
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.3, green: 0.25, blue: 0.2),
                    Color(red: 0.2, green: 0.15, blue: 0.1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 8) {
            Text("WAVE \(viewModel.wave.waveNumber) BOSS")
                .font(.system(size: 14, weight: .bold, design: .serif))
                .foregroundColor(KingdomTheme.Colors.imperialGold)
            
            Text("ENEMY STRONGHOLD")
                .font(.system(size: 24, weight: .black, design: .serif))
                .foregroundColor(.white)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Battle Arena
    
    private var battleArena: some View {
        HStack(spacing: 40) {
            // Player side
            VStack(spacing: 12) {
                // Army icon
                ZStack {
                    Circle()
                        .fill(KingdomTheme.Colors.royalBlue.opacity(0.3))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.royalBlue)
                }
                
                Text("YOUR ARMY")
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("\(viewModel.bossBattle?.playerArmySize ?? viewModel.wave.armySize)")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                
                Text("soldiers")
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            // VS
            VStack(spacing: 8) {
                Text("VS")
                    .font(.system(size: 20, weight: .black, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.imperialGold)
                
                if viewModel.isBossRolling {
                    ProgressView()
                        .tint(.white)
                }
            }
            
            // Enemy side
            VStack(spacing: 12) {
                // Army icon
                ZStack {
                    Circle()
                        .fill(KingdomTheme.Colors.buttonDanger.opacity(0.3))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "figure.stand")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.buttonDanger)
                }
                
                Text("ENEMY ARMY")
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("\(viewModel.bossBattle?.enemyArmySize ?? viewModel.wave.enemyArmySize)")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                
                Text("soldiers")
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
    
    // MARK: - Stats Row
    
    private var statsSection: some View {
        VStack(spacing: 10) {
            statRow(title: "PLAYER", attack: viewModel.bossPlayerAttack, defense: viewModel.bossPlayerDefense, leadership: viewModel.bossPlayerLeadership)
            statRow(title: "ARMY", attack: viewModel.bossArmyAttack, defense: viewModel.bossArmyDefense, leadership: viewModel.bossArmyLeadership)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
    
    private func statRow(title: String, attack: Int, defense: Int, leadership: Int) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .serif))
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                statChip(label: "ATK", value: "\(attack)", icon: "bolt.fill", color: KingdomTheme.Colors.buttonDanger)
                statChip(label: "DEF", value: "\(defense)", icon: "shield.fill", color: KingdomTheme.Colors.buttonWarning)
                statChip(label: "LEAD", value: "\(leadership)", icon: "flag.fill", color: KingdomTheme.Colors.buttonSuccess)
            }
        }
    }
    
    private func statChip(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 26, height: 26)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 8, weight: .bold, design: .serif))
                    .foregroundColor(.white.opacity(0.7))
                Text(value)
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
    
    // MARK: - Tug of War
    
    private func tugOfWarSection(battle: MarchBossBattleState) -> some View {
        VStack(spacing: 12) {
            // Round counter
            HStack {
                Text("ROUND \(battle.roundNumber)")
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Text("\(Int(battle.controlBar))%")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            // Tug of war bar
            BossTugOfWarBar(
                value: battle.controlBar,
                isComplete: battle.isComplete,
                playerWon: battle.playerWon
            )
            
            // Labels
            HStack {
                Text("DEFEAT")
                    .font(.system(size: 10, weight: .bold, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
                
                Spacer()
                
                Text("VICTORY")
                    .font(.system(size: 10, weight: .bold, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
            }
        }
        .padding(20)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 24)
    }
    
    // MARK: - Action Button
    
    private var actionButtons: some View {
        Group {
            if let battle = viewModel.bossBattle, battle.isComplete {
                // Battle complete - show result
                if battle.playerWon {
                    Text("VICTORY!")
                        .font(.system(size: 20, weight: .black, design: .serif))
                        .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                } else {
                    Text("DEFEATED")
                        .font(.system(size: 20, weight: .black, design: .serif))
                        .foregroundColor(KingdomTheme.Colors.buttonDanger)
                }
            } else {
                HStack(spacing: 10) {
                    ForEach(MarchBossAction.allCases, id: \.self) { action in
                        Button {
                            Task {
                                await viewModel.performBossAction(action)
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: action.icon)
                                    .font(.system(size: 18, weight: .bold))
                                Text(action.title)
                                    .font(.system(size: 12, weight: .black, design: .serif))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(action.color)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.black, lineWidth: 2)
                            )
                        }
                        .disabled(viewModel.isBossRolling)
                    }
                }
            }
        }
    }

    private var tapHint: some View {
        Group {
            if let battle = viewModel.bossBattle, !battle.isComplete {
                Text(viewModel.isBossRolling ? viewModel.bossActionMessage : "CHOOSE YOUR TACTIC EACH ROUND")
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 12)
            }
        }
    }
}

// MARK: - Boss Tug of War Bar

struct BossTugOfWarBar: View {
    let value: Double  // 0-100, where 100 = player victory
    let isComplete: Bool
    let playerWon: Bool
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height: CGFloat = 36
            let progress = min(1.0, max(0.0, value / 100.0))
            let playerWidth = width * progress
            
            ZStack(alignment: .leading) {
                // Background (enemy side) - animated stripes
                RoundedRectangle(cornerRadius: 10)
                    .fill(KingdomTheme.Colors.buttonDanger.opacity(0.4))
                    .overlay(
                        AnimatedStripes()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    )
                
                // Player progress
                RoundedRectangle(cornerRadius: 10)
                    .fill(KingdomTheme.Colors.royalBlue.opacity(0.8))
                    .frame(width: playerWidth)
                    .overlay(
                        AnimatedStripes()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    )
                
                // Center marker (50% line)
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 2, height: height - 8)
                    .position(x: width / 2, y: height / 2)
                
                // Current position marker
                if !isComplete {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white)
                        .frame(width: 6, height: height - 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color.black, lineWidth: 1)
                        )
                        .position(x: max(8, min(width - 8, playerWidth)), y: height / 2)
                }
                
                // Labels
                HStack {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.leading, 10)
                    
                    Spacer()
                    
                    // Percentage
                    Text(isComplete ? (playerWon ? "VICTORY" : "DEFEAT") : "\(Int(progress * 100))% vs \(Int((1 - progress) * 100))%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "figure.stand")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.trailing, 10)
                }
                
                // Border
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.5), lineWidth: 2)
            }
            .frame(height: height)
        }
        .frame(height: 36)
    }
}

#Preview {
    MarchBossBattleView(viewModel: {
        let vm = MarchViewModel()
        vm.bossBattle = MarchBossBattleState(
            playerArmySize: 45,
            enemyArmySize: 35,
            controlBar: 60
        )
        return vm
    }())
}
