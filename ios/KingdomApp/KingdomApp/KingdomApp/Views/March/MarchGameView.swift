import SwiftUI

/// Main container for the March endless runner minigame
struct MarchGameView: View {
    @StateObject private var viewModel = MarchViewModel()
    @ObservedObject var player: Player
    @Environment(\.dismiss) private var dismiss
    
    init(player: Player) {
        self.player = player
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.85, green: 0.75, blue: 0.6),  // Sandy
                    Color(red: 0.7, green: 0.6, blue: 0.45)   // Darker sand
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                
                // Main game area
                ZStack {
                    switch viewModel.phase {
                    case .ready:
                        readyScreen
                        
                    case .running, .eventReady, .eventActive, .rolling, .eventResult:
                        VStack(spacing: 0) {
                            // HUD
                            MarchHUD(viewModel: viewModel)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            
                            // Runner view
                            MarchRunnerView(viewModel: viewModel)
                                .frame(maxHeight: .infinity)
                            
                            // Event overlay slides up from bottom
                            if viewModel.phase == .eventActive || viewModel.phase == .rolling || viewModel.phase == .eventResult {
                                MarchEventOverlay(viewModel: viewModel)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.phase)
                            }
                        }
                        
                    case .bossBattle, .bossRolling:
                        MarchBossBattleView(viewModel: viewModel)
                        
                    case .waveComplete:
                        waveCompleteScreen
                        
                    case .gameOver:
                        gameOverScreen
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.phase)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Inject player reference
            viewModel.player = player
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text("THE MARCH")
                .font(.system(size: 18, weight: .black, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Spacer()
            
            // High score
            VStack(alignment: .trailing, spacing: 2) {
                Text("BEST")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Text("Wave \(viewModel.highestWave)")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
    
    // MARK: - Ready Screen
    
    private var readyScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Title art
            Image(systemName: "figure.walk")
                .font(.system(size: 80, weight: .bold))
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("ENDLESS MARCH")
                .font(.system(size: 28, weight: .black, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("Lead your army through endless challenges.\nUse your skills to overcome obstacles.\nDefeat the boss at each wave's end.")
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
            
            // Start button
            Button {
                viewModel.startGame()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text("BEGIN MARCH")
                        .font(.system(size: 16, weight: .black, design: .serif))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(KingdomTheme.Colors.buttonSuccess)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black, lineWidth: 3)
                )
                .shadow(color: .black.opacity(0.3), radius: 0, x: 3, y: 3)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
    
    // MARK: - Wave Complete Screen
    
    private var waveCompleteScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Victory icon
            Image(systemName: "flag.checkered")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
            
            Text("WAVE \(viewModel.wave.waveNumber) COMPLETE!")
                .font(.system(size: 24, weight: .black, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            // Stats
            VStack(spacing: 12) {
                statRow(label: "Army Size", value: "\(viewModel.bossBattle?.playerArmySize ?? viewModel.wave.armySize)")
                statRow(label: "Distance", value: "\(viewModel.wave.distance)m")
                statRow(label: "Events Cleared", value: "\(viewModel.wave.eventsCompleted)")
            }
            .padding(20)
            .background(Color.white.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Next wave button
            Button {
                viewModel.startNextWave()
            } label: {
                HStack(spacing: 12) {
                    Text("CONTINUE TO WAVE \(viewModel.wave.waveNumber + 1)")
                        .font(.system(size: 16, weight: .black, design: .serif))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(KingdomTheme.Colors.buttonSuccess)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black, lineWidth: 3)
                )
                .shadow(color: .black.opacity(0.3), radius: 0, x: 3, y: 3)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
    
    // MARK: - Game Over Screen
    
    private var gameOverScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Defeat icon
            Image(systemName: "xmark.shield.fill")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(KingdomTheme.Colors.buttonDanger)
            
            Text("DEFEATED")
                .font(.system(size: 28, weight: .black, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            // Stats
            VStack(spacing: 12) {
                statRow(label: "Waves Survived", value: "\(viewModel.wave.waveNumber)")
                statRow(label: "Total Distance", value: "\(viewModel.wave.distance)m")
                statRow(label: "Events Cleared", value: "\(viewModel.wave.eventsCompleted)")
                
                if viewModel.wave.waveNumber >= viewModel.highestWave {
                    Text("NEW RECORD!")
                        .font(.system(size: 14, weight: .black, design: .serif))
                        .foregroundColor(KingdomTheme.Colors.imperialGold)
                        .padding(.top, 8)
                }
            }
            .padding(20)
            .background(Color.white.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Buttons
            VStack(spacing: 12) {
                Button {
                    viewModel.startGame()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 18, weight: .bold))
                        Text("TRY AGAIN")
                            .font(.system(size: 16, weight: .black, design: .serif))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(KingdomTheme.Colors.buttonPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black, lineWidth: 3)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 0, x: 3, y: 3)
                }
                
                Button {
                    dismiss()
                } label: {
                    Text("Exit")
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
    
    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
    }
}

#Preview {
    MarchGameView(player: Player(playerId: 1, name: "Test"))
}
