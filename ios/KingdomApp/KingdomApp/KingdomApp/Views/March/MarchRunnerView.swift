import SwiftUI

/// The main running animation view showing the player and army marching
struct MarchRunnerView: View {
    @ObservedObject var viewModel: MarchViewModel
    
    // Animation state
    @State private var groundOffset: CGFloat = 0
    @State private var walkCycle: Bool = false
    
    // Approaching obstacle
    @State private var obstacleX: CGFloat = 1.2  // Start off-screen right (1.0 = right edge)
    @State private var showObstacle: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Sky gradient
                skyLayer
                
                // Clouds layer (contained, slow moving)
                cloudsLayer(geo: geo)
                
                // Distant hills
                hillsLayer(geo: geo)
                
                // Ground with scrolling texture
                groundLayer(geo: geo)
                
                // Approaching obstacle/event (if one is coming)
                if let nextEvent = viewModel.upcomingEventForDisplay {
                    approachingObstacle(geo: geo, event: nextEvent)
                }
                
                // Army and player
                armyLayer(geo: geo)
                
                // Buffs display (top right)
                VStack {
                    HStack {
                        Spacer()
                        MarchBuffsDisplay(viewModel: viewModel)
                            .padding(.trailing, 12)
                            .padding(.top, 8)
                    }
                    Spacer()
                }
            }
        }
        .clipped()  // Keep everything contained
        .onAppear {
            startAnimations()
        }
        .onChange(of: viewModel.wave.isRunning) { _, isRunning in
            if isRunning {
                startAnimations()
            }
        }
    }
    
    // MARK: - Sky Layer
    
    private var skyLayer: some View {
        LinearGradient(
            colors: [
                Color(red: 0.55, green: 0.7, blue: 0.85),
                Color(red: 0.75, green: 0.85, blue: 0.92)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Clouds Layer
    
    private func cloudsLayer(geo: GeometryProxy) -> some View {
        let cloudY1 = geo.size.height * 0.08
        let cloudY2 = geo.size.height * 0.15
        let cloudY3 = geo.size.height * 0.05
        
        return ZStack {
            // Slow-moving background clouds
            cloudShape(width: 80, height: 35)
                .offset(x: cos(groundOffset * 0.001) * 20 - 100, y: cloudY1)
                .opacity(0.6)
            
            cloudShape(width: 100, height: 40)
                .offset(x: cos(groundOffset * 0.0008 + 1) * 30 + 50, y: cloudY2)
                .opacity(0.5)
            
            cloudShape(width: 60, height: 25)
                .offset(x: cos(groundOffset * 0.0012 + 2) * 25 + 150, y: cloudY3)
                .opacity(0.7)
        }
    }
    
    private func cloudShape(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(Color.white.opacity(0.9))
                .frame(width: width, height: height)
            Ellipse()
                .fill(Color.white.opacity(0.9))
                .frame(width: width * 0.6, height: height * 0.7)
                .offset(x: width * 0.25, y: -height * 0.15)
            Ellipse()
                .fill(Color.white.opacity(0.9))
                .frame(width: width * 0.5, height: height * 0.6)
                .offset(x: -width * 0.2, y: height * 0.1)
        }
    }
    
    // MARK: - Hills Layer
    
    private func hillsLayer(geo: GeometryProxy) -> some View {
        VStack {
            Spacer()
            
            ZStack(alignment: .bottom) {
                // Far hills (darker, smaller)
                WaveShape(amplitude: 25, frequency: 0.4, phase: groundOffset * 0.0002)
                    .fill(Color(red: 0.45, green: 0.55, blue: 0.4).opacity(0.6))
                    .frame(height: 80)
                    .offset(y: -60)
                
                // Near hills
                WaveShape(amplitude: 35, frequency: 0.6, phase: groundOffset * 0.0003 + 0.5)
                    .fill(Color(red: 0.5, green: 0.6, blue: 0.4).opacity(0.8))
                    .frame(height: 70)
                    .offset(y: -40)
            }
            .frame(height: 120)
        }
    }
    
    // MARK: - Ground Layer
    
    private func groundLayer(geo: GeometryProxy) -> some View {
        let groundHeight: CGFloat = 120
        
        return VStack {
            Spacer()
            
            ZStack {
                // Main ground
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.55, green: 0.45, blue: 0.3),
                                Color(red: 0.5, green: 0.4, blue: 0.28)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Path/road
                Rectangle()
                    .fill(Color(red: 0.65, green: 0.55, blue: 0.4))
                    .frame(height: 50)
                    .offset(y: -25)
                
                // Scrolling ground details
                groundDetails(geo: geo)
            }
            .frame(height: groundHeight)
        }
    }
    
    private func groundDetails(geo: GeometryProxy) -> some View {
        let detailCount = 12
        let spacing = geo.size.width / CGFloat(detailCount - 1)
        let offset = groundOffset.truncatingRemainder(dividingBy: spacing)
        
        return HStack(spacing: spacing) {
            ForEach(0..<detailCount, id: \.self) { i in
                groundDetailItem(index: i)
            }
        }
        .offset(x: -offset - spacing, y: -40)
    }
    
    private func groundDetailItem(index: Int) -> some View {
        Group {
            switch index % 4 {
            case 0:
                // Rock
                Ellipse()
                    .fill(Color(red: 0.45, green: 0.4, blue: 0.35))
                    .frame(width: 14, height: 8)
            case 1:
                // Grass tuft
                HStack(spacing: 1) {
                    Rectangle().fill(Color(red: 0.35, green: 0.5, blue: 0.25)).frame(width: 2, height: 10)
                    Rectangle().fill(Color(red: 0.4, green: 0.55, blue: 0.3)).frame(width: 2, height: 14)
                    Rectangle().fill(Color(red: 0.35, green: 0.5, blue: 0.25)).frame(width: 2, height: 8)
                }
            case 2:
                // Small stone
                Circle()
                    .fill(Color(red: 0.5, green: 0.45, blue: 0.4))
                    .frame(width: 6, height: 6)
            default:
                // Dirt patch
                Ellipse()
                    .fill(Color(red: 0.45, green: 0.38, blue: 0.28))
                    .frame(width: 10, height: 5)
            }
        }
    }
    
    // MARK: - Approaching Obstacle
    
    private func approachingObstacle(geo: GeometryProxy, event: MarchEvent) -> some View {
        let progress = viewModel.obstacleApproachProgress
        let xPos = geo.size.width * (1.0 - progress * 0.7)  // Move from right toward center-right
        let yPos = geo.size.height - 115
        let scale = 0.5 + (progress * 0.5)  // Grow as it approaches
        
        return ZStack {
            if event.type == .brokenBridge {
                Rectangle()
                    .fill(Color.black.opacity(0.55))
                    .frame(width: 90, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .position(x: xPos, y: yPos + 26)
            }

            // Obstacle/event icon
            obstacleSprite(for: event.type)
                .scaleEffect(scale)
                .position(x: xPos, y: yPos)
                .opacity(progress > 0.1 ? 1 : 0)
            
            // Warning indicator when close
            if progress > 0.6 {
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.yellow)
                    Text(event.type.displayName)
                        .font(.system(size: 10, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                }
                .padding(8)
                .background(Color.black.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .position(x: xPos, y: yPos - 60)
                .transition(.opacity)
            }

            if viewModel.isAwaitingEngagement && progress >= 0.4 {
                VStack(spacing: 6) {
                    Text("TAP TO ENGAGE")
                        .font(.system(size: 12, weight: .black, design: .serif))
                        .foregroundColor(.white)
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(10)
                .background(Color.black.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.8), lineWidth: 2)
                )
                .position(x: xPos, y: yPos - 70)
                .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.handleObstacleTap()
        }
        .animation(.easeOut(duration: 0.3), value: progress)
    }
    
    private func obstacleSprite(for type: MarchEventType) -> some View {
        ZStack {
            // Shadow
            Ellipse()
                .fill(Color.black.opacity(0.3))
                .frame(width: 50, height: 15)
                .offset(y: 25)
            
            // Main sprite based on event type
            switch type {
            case .brokenBridge:
                bridgeSprite
            case .enemySquad:
                enemySquadSprite
            case .ambush:
                ambushSprite
            case .lostSoldiers:
                lostSoldiersSprite
            case .divineShrine:
                shrineSprite
            case .spyIntel:
                spySprite
            case .ancientText:
                scrollSprite
            case .tradeCaravan:
                caravanSprite
            case .wisdomStone:
                stoneSprite
            }
        }
    }
    
    private var bridgeSprite: some View {
        VStack(spacing: 0) {
            // Broken planks
            HStack(spacing: 4) {
                Rectangle()
                    .fill(Color(red: 0.5, green: 0.35, blue: 0.2))
                    .frame(width: 12, height: 30)
                    .rotationEffect(.degrees(-15))
                Rectangle()
                    .fill(Color(red: 0.45, green: 0.3, blue: 0.18))
                    .frame(width: 12, height: 25)
                    .rotationEffect(.degrees(10))
                Rectangle()
                    .fill(Color(red: 0.5, green: 0.35, blue: 0.2))
                    .frame(width: 12, height: 28)
                    .rotationEffect(.degrees(-5))
            }
            // Gap indicator
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .frame(width: 50, height: 8)
        }
    }
    
    private var enemySquadSprite: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                enemyFigure(variant: i)
            }
        }
    }
    
    private func enemyFigure(variant: Int) -> some View {
        VStack(spacing: 0) {
            // Head
            Circle()
                .fill(Color(red: 0.4, green: 0.3, blue: 0.3))
                .frame(width: 12, height: 12)
            // Body
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.6, green: 0.2, blue: 0.2))
                .frame(width: 14, height: 20)
            // Legs
            HStack(spacing: 2) {
                Rectangle().fill(Color(red: 0.35, green: 0.25, blue: 0.2)).frame(width: 4, height: 10)
                Rectangle().fill(Color(red: 0.35, green: 0.25, blue: 0.2)).frame(width: 4, height: 10)
            }
        }
        .offset(y: CGFloat(variant % 2) * 3)
    }
    
    private var ambushSprite: some View {
        ZStack {
            // Bush
            Ellipse()
                .fill(Color(red: 0.25, green: 0.4, blue: 0.2))
                .frame(width: 50, height: 35)
            // Eyes peeking
            HStack(spacing: 12) {
                Circle().fill(Color.red).frame(width: 6, height: 6)
                Circle().fill(Color.red).frame(width: 6, height: 6)
            }
            .offset(y: -5)
        }
    }
    
    private var lostSoldiersSprite: some View {
        HStack(spacing: 4) {
            ForEach(0..<2, id: \.self) { i in
                VStack(spacing: 0) {
                    Circle()
                        .fill(Color(red: 0.8, green: 0.7, blue: 0.6))
                        .frame(width: 10, height: 10)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.6))
                        .frame(width: 12, height: 16)
                }
                .opacity(0.7)
            }
            Image(systemName: "questionmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private var shrineSprite: some View {
        VStack(spacing: 0) {
            // Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.yellow.opacity(0.5), Color.clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: 30
                    )
                )
                .frame(width: 60, height: 60)
            // Altar
            Rectangle()
                .fill(Color(red: 0.6, green: 0.6, blue: 0.65))
                .frame(width: 30, height: 20)
                .offset(y: -30)
        }
    }
    
    private var spySprite: some View {
        ZStack {
            // Hooded figure
            VStack(spacing: 0) {
                // Hood
                Circle()
                    .fill(Color(red: 0.2, green: 0.2, blue: 0.25))
                    .frame(width: 16, height: 16)
                // Cloak
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.15, green: 0.15, blue: 0.2))
                    .frame(width: 20, height: 28)
            }
            // Glowing eye
            Circle()
                .fill(Color.green)
                .frame(width: 4, height: 4)
                .offset(x: 2, y: -12)
        }
    }
    
    private var scrollSprite: some View {
        ZStack {
            // Pedestal
            Rectangle()
                .fill(Color(red: 0.5, green: 0.45, blue: 0.4))
                .frame(width: 25, height: 15)
                .offset(y: 10)
            // Scroll
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.9, green: 0.85, blue: 0.7))
                .frame(width: 20, height: 25)
            // Glow
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 40, height: 40)
        }
    }
    
    private var caravanSprite: some View {
        HStack(spacing: 2) {
            // Wagon
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color(red: 0.5, green: 0.35, blue: 0.2))
                    .frame(width: 35, height: 20)
                HStack(spacing: 15) {
                    Circle().fill(Color(red: 0.3, green: 0.25, blue: 0.2)).frame(width: 10, height: 10)
                    Circle().fill(Color(red: 0.3, green: 0.25, blue: 0.2)).frame(width: 10, height: 10)
                }
            }
            // Horse shape (simplified)
            Ellipse()
                .fill(Color(red: 0.5, green: 0.4, blue: 0.3))
                .frame(width: 20, height: 15)
        }
    }
    
    private var stoneSprite: some View {
        ZStack {
            // Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.purple.opacity(0.4), Color.clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: 25
                    )
                )
                .frame(width: 50, height: 50)
            // Stone
            Ellipse()
                .fill(Color(red: 0.5, green: 0.5, blue: 0.55))
                .frame(width: 30, height: 25)
            // Runes
            Text("⚶")
                .font(.system(size: 14))
                .foregroundColor(.purple)
        }
    }
    
    // MARK: - Army Layer
    
    private func armyLayer(geo: GeometryProxy) -> some View {
        let groundY = geo.size.height - 85
        
        return ZStack {
            // Soldiers behind (further back, smaller)
            if viewModel.wave.armySize > 5 {
                soldierRow(count: min(6, viewModel.wave.armySize / 4), scale: 0.5, opacity: 0.5)
                    .offset(x: -geo.size.width * 0.35, y: groundY - 15)
            }
            
            // Soldiers middle row
            if viewModel.wave.armySize > 2 {
                soldierRow(count: min(5, viewModel.wave.armySize / 2), scale: 0.7, opacity: 0.7)
                    .offset(x: -geo.size.width * 0.30, y: groundY)
            }
            
            // Main character (hero) - prominent position
            heroCharacter
                .offset(x: -geo.size.width * 0.25, y: groundY + 5)
            
            // Soldiers front row (closest)
            soldierRow(count: min(4, viewModel.wave.armySize), scale: 0.85, opacity: 0.9)
                .offset(x: -geo.size.width * 0.38, y: groundY + 12)
        }
    }
    
    private var heroCharacter: some View {
        ZStack {
            // Shadow
            Ellipse()
                .fill(Color.black.opacity(0.35))
                .frame(width: 35, height: 12)
                .offset(y: 28)
            
            // Character
            VStack(spacing: 0) {
                // Head
                ZStack {
                    Circle()
                        .fill(Color(red: 0.9, green: 0.8, blue: 0.7))
                        .frame(width: 22, height: 22)
                    // Face
                    Circle()
                        .fill(Color.black)
                        .frame(width: 3, height: 3)
                        .offset(x: -4, y: -2)
                    Circle()
                        .fill(Color.black)
                        .frame(width: 3, height: 3)
                        .offset(x: 4, y: -2)
                }
                
                // Body with armor
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(KingdomTheme.Colors.royalBlue)
                        .frame(width: 28, height: 32)
                    
                    // Armor detail
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.4))
                            .frame(width: 18, height: 6)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 14, height: 4)
                    }
                }
                
                // Legs (animated)
                HStack(spacing: 3) {
                    Rectangle()
                        .fill(Color(red: 0.3, green: 0.25, blue: 0.2))
                        .frame(width: 6, height: 14)
                        .offset(y: walkCycle ? -2 : 2)
                    Rectangle()
                        .fill(Color(red: 0.3, green: 0.25, blue: 0.2))
                        .frame(width: 6, height: 14)
                        .offset(y: walkCycle ? 2 : -2)
                }
            }
            
            // Sword
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.gray, Color.white, Color.gray],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 4, height: 28)
                .rotationEffect(.degrees(-30))
                .offset(x: 22, y: -5)
            
            // Crown if army is large
            if viewModel.wave.armySize > 20 {
                Image(systemName: "crown.fill")
                    .font(.system(size: 12))
                    .foregroundColor(KingdomTheme.Colors.imperialGold)
                    .offset(y: -38)
            }
        }
    }
    
    private func soldierRow(count: Int, scale: CGFloat, opacity: Double) -> some View {
        HStack(spacing: 8 * scale) {
            ForEach(0..<count, id: \.self) { i in
                soldierSprite(index: i)
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .offset(y: walkCycle && i % 2 == 0 ? -2 : (walkCycle ? 2 : 0))
            }
        }
    }
    
    private func soldierSprite(index: Int) -> some View {
        VStack(spacing: 0) {
            // Head
            Circle()
                .fill(Color(red: 0.85, green: 0.75, blue: 0.65))
                .frame(width: 12, height: 12)
            // Body
            RoundedRectangle(cornerRadius: 2)
                .fill(index % 2 == 0 ? KingdomTheme.Colors.royalBlue.opacity(0.8) : Color(red: 0.4, green: 0.45, blue: 0.55))
                .frame(width: 14, height: 20)
            // Legs
            HStack(spacing: 2) {
                Rectangle().fill(Color(red: 0.3, green: 0.25, blue: 0.2)).frame(width: 4, height: 8)
                Rectangle().fill(Color(red: 0.3, green: 0.25, blue: 0.2)).frame(width: 4, height: 8)
            }
        }
    }
    
    // MARK: - Animations
    
    private func startAnimations() {
        // Ground scrolling - use timer for smoother control
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            if viewModel.wave.isRunning {
                groundOffset += 1.5
            }
        }
        
        // Walk cycle animation
        withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
            walkCycle = true
        }
    }
}

// MARK: - Wave Shape for Hills

struct WaveShape: Shape {
    var amplitude: CGFloat
    var frequency: CGFloat
    var phase: CGFloat
    
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: 0, y: rect.height))
        
        for x in stride(from: 0, through: rect.width, by: 2) {
            let relativeX = x / rect.width
            let y = amplitude * sin((relativeX * frequency * .pi * 4) + phase) + rect.height / 2
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Preview

#Preview {
    MarchRunnerView(viewModel: {
        let vm = MarchViewModel()
        vm.wave.armySize = 25
        vm.wave.isRunning = true
        return vm
    }())
    .frame(height: 400)
}
