import SwiftUI

// MARK: - Score Game

struct ScoreGameView: View {
    let onComplete: (Int) -> Void
    
    @State private var loaves: [LoafToScore] = []
    @State private var currentPath: [CGPoint] = []
    @State private var activeLoafIndex: Int? = nil
    let requiredLengthPerLoaf: CGFloat = 150
    
    struct LoafToScore: Identifiable {
        let id = UUID()
        var frame: CGRect = .zero
        var paths: [[CGPoint]] = []
        var totalLength: CGFloat = 0
        var isComplete: Bool = false
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Draw patterns on each loaf")
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 28)
                .padding(.horizontal, 20)
            
            // Progress indicator
            VStack(spacing: 4) {
                HStack {
                    Text("Loaves Scored")
                    Spacer()
                    Text("\(loaves.filter({ $0.isComplete }).count)/4")
                        .font(FontStyles.labelBold)
                }
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .padding(.horizontal, 20)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3))
                        RoundedRectangle(cornerRadius: 8)
                            .fill(KingdomTheme.Colors.buttonSuccess)
                            .frame(width: geo.size.width * (CGFloat(loaves.filter({ $0.isComplete }).count) / 4.0))
                    }
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                }
                .frame(height: 20)
                .padding(.horizontal, 20)
            }
            
            // Scoring area
            GeometryReader { geo in
                let loafWidth: CGFloat = (geo.size.width - 80) / 2
                let loafHeight: CGFloat = (geo.size.height - 80) / 2
                
                ZStack {
                    // Baking tray
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.3, green: 0.3, blue: 0.35))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black, lineWidth: 3))
                    
                    // Parchment
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.92, green: 0.88, blue: 0.80))
                        .padding(15)
                    
                    // 2x2 grid of loaves
                    VStack(spacing: 20) {
                        HStack(spacing: 20) {
                            loafView(index: 0, width: loafWidth, height: loafHeight)
                            loafView(index: 1, width: loafWidth, height: loafHeight)
                        }
                        HStack(spacing: 20) {
                            loafView(index: 2, width: loafWidth, height: loafHeight)
                            loafView(index: 3, width: loafWidth, height: loafHeight)
                        }
                    }
                    .padding(30)
                    
                    // Current path being drawn
                    if currentPath.count >= 2 {
                        Path { path in
                            path.move(to: currentPath[0])
                            for point in currentPath.dropFirst() {
                                path.addLine(to: point)
                            }
                        }
                        .stroke(Color.red.opacity(0.8), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    }
                    
                    // All completed paths
                    ForEach(loaves.indices, id: \.self) { loafIndex in
                        ForEach(loaves[loafIndex].paths.indices, id: \.self) { pathIndex in
                            let pathPoints = loaves[loafIndex].paths[pathIndex]
                            if pathPoints.count >= 2 {
                                // Dark stroke (shadow)
                                Path { path in
                                    path.move(to: pathPoints[0])
                                    for point in pathPoints.dropFirst() {
                                        path.addLine(to: point)
                                    }
                                }
                                .stroke(
                                    Color(red: 0.55, green: 0.40, blue: 0.25),
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                                )
                                
                                // Light inner stroke
                                Path { path in
                                    path.move(to: pathPoints[0])
                                    for point in pathPoints.dropFirst() {
                                        path.addLine(to: point)
                                    }
                                }
                                .stroke(
                                    Color(red: 0.80, green: 0.68, blue: 0.50),
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                                )
                            }
                        }
                    }
                }
                .coordinateSpace(name: "scoringArea")
                .gesture(
                    DragGesture(minimumDistance: 1, coordinateSpace: .named("scoringArea"))
                        .onChanged { value in
                            handleDrag(value.location)
                        }
                        .onEnded { _ in
                            finishPath()
                        }
                )
                .onAppear {
                    setupLoaves(in: geo.size)
                }
                .onChange(of: geo.size) { newSize in
                    setupLoaves(in: newSize)
                }
            }
            .padding(.horizontal, 20)
            
            Text("Draw slashes on each loaf to score them!")
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .padding(.bottom, 20)
        }
    }
    
    @ViewBuilder
    private func loafView(index: Int, width: CGFloat, height: CGFloat) -> some View {
        let loaf = loaves.indices.contains(index) ? loaves[index] : nil
        let isComplete = loaf?.isComplete ?? false
        
        ZStack {
            // Shadow
            Ellipse()
                .fill(Color.black.opacity(0.15))
                .frame(width: width * 0.9, height: height * 0.3)
                .offset(y: height * 0.35)
            
            // Loaf shape
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: isComplete ? [
                            Color(red: 0.82, green: 0.70, blue: 0.50),
                            Color(red: 0.72, green: 0.60, blue: 0.40)
                        ] : [
                            Color(red: 0.95, green: 0.90, blue: 0.78),
                            Color(red: 0.88, green: 0.80, blue: 0.65)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: width * 0.85, height: height * 0.7)
                .overlay(
                    Ellipse()
                        .stroke(Color(red: 0.78, green: 0.68, blue: 0.52), lineWidth: 2)
                )
            
            // Checkmark when complete
            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
            }
        }
        .frame(width: width, height: height)
        .background(
            GeometryReader { loafGeo in
                Color.clear.onAppear {
                    updateLoafFrame(index: index, geo: loafGeo)
                }
            }
        )
    }
    
    private func setupLoaves(in size: CGSize) {
        if loaves.isEmpty {
            loaves = (0..<4).map { _ in LoafToScore() }
        }
    }
    
    private func updateLoafFrame(index: Int, geo: GeometryProxy) {
        guard loaves.indices.contains(index) else { return }
        let frame = geo.frame(in: .named("scoringArea"))
        DispatchQueue.main.async {
            if loaves.indices.contains(index) {
                loaves[index].frame = frame
            }
        }
    }
    
    private func findLoafIndex(at point: CGPoint) -> Int? {
        for (index, loaf) in loaves.enumerated() {
            if !loaf.isComplete && loaf.frame.insetBy(dx: -10, dy: -10).contains(point) {
                return index
            }
        }
        return nil
    }
    
    private func handleDrag(_ location: CGPoint) {
        // If we haven't started on a loaf yet, find one
        if activeLoafIndex == nil {
            activeLoafIndex = findLoafIndex(at: location)
        }
        
        // Only continue if we're on a valid loaf
        guard let loafIndex = activeLoafIndex,
              loaves.indices.contains(loafIndex),
              !loaves[loafIndex].isComplete else {
            return
        }
        
        // Add point to current path
        currentPath.append(location)
        
        // Haptic feedback every few points
        if currentPath.count % 5 == 0 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.3)
        }
    }
    
    private func finishPath() {
        defer {
            currentPath = []
            activeLoafIndex = nil
        }
        
        guard let loafIndex = activeLoafIndex,
              loaves.indices.contains(loafIndex),
              currentPath.count >= 3 else {
            return
        }
        
        // Calculate path length
        var pathLength: CGFloat = 0
        for i in 1..<currentPath.count {
            let prev = currentPath[i-1]
            let curr = currentPath[i]
            pathLength += hypot(curr.x - prev.x, curr.y - prev.y)
        }
        
        guard pathLength > 15 else { return }
        
        // Add path to loaf
        loaves[loafIndex].paths.append(currentPath)
        loaves[loafIndex].totalLength += pathLength
        
        // Check if loaf is complete
        if loaves[loafIndex].totalLength >= requiredLengthPerLoaf {
            loaves[loafIndex].isComplete = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            
            // Check if all loaves done
            if loaves.allSatisfy({ $0.isComplete }) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onComplete(90 + Int.random(in: 0...10))
                }
            }
        } else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}

#Preview {
    ScoreGameView(onComplete: { _ in })
}
