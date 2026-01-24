import SwiftUI

/// HUD displaying army size, wave number, distance, and HP
struct MarchHUD: View {
    @ObservedObject var viewModel: MarchViewModel
    
    var body: some View {
        HStack(spacing: 10) {
            // Wave number
            hudChip(
                label: "WAVE",
                value: "\(viewModel.wave.waveNumber)",
                icon: "flag.fill",
                color: KingdomTheme.Colors.royalPurple
            )
            
            // Army size
            hudChip(
                label: "ARMY",
                value: "\(viewModel.wave.armySize)",
                icon: "person.3.fill",
                color: KingdomTheme.Colors.royalBlue
            )
            
            // HP
            hpChip
            
            // Distance / Progress
            progressChip
        }
    }
    
    private func hudChip(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Text(value)
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var hpChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(hpColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 1) {
                Text("HP")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                // HP bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.black.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(hpColor)
                            .frame(width: geo.size.width * CGFloat(viewModel.wave.playerHP) / 100.0)
                    }
                }
                .frame(width: 40, height: 8)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var hpColor: Color {
        let hp = viewModel.wave.playerHP
        if hp > 60 { return KingdomTheme.Colors.buttonSuccess }
        if hp > 30 { return KingdomTheme.Colors.buttonWarning }
        return KingdomTheme.Colors.buttonDanger
    }
    
    private var progressChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "location.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(KingdomTheme.Colors.imperialGold)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 1) {
                Text("BOSS")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.black.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(KingdomTheme.Colors.imperialGold)
                            .frame(width: geo.size.width * viewModel.wave.progress)
                    }
                }
                .frame(width: 40, height: 8)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Buffs Display

struct MarchBuffsDisplay: View {
    @ObservedObject var viewModel: MarchViewModel
    
    var body: some View {
        HStack(spacing: 8) {
            if viewModel.hasShieldBuff {
                buffIcon(icon: "shield.checkered", color: KingdomTheme.Colors.royalBlue, label: "Shield")
            }
            if viewModel.hasInspireBuff {
                buffIcon(icon: "sparkles", color: KingdomTheme.Colors.imperialGold, label: "Inspire")
            }
        }
    }
    
    private func buffIcon(icon: String, color: Color, label: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(color)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
            
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
    }
}

#Preview {
    VStack {
        MarchHUD(viewModel: MarchViewModel())
            .padding()
        
        MarchBuffsDisplay(viewModel: MarchViewModel())
            .padding()
    }
    .background(Color.gray.opacity(0.2))
}
