import SwiftUI

// MARK: - Score Game

struct ScoreGameView: View {
    let onComplete: (Int) -> Void
    
    @State private var loafHasDrawing: [Bool] = [false, false, false, false]
    
    private var completedCount: Int {
        loafHasDrawing.filter { $0 }.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Score each loaf with slashes")
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            
            // Progress
            VStack(spacing: 4) {
                HStack {
                    Text("Loaves Scored")
                    Spacer()
                    Text("\(completedCount)/4")
                        .font(FontStyles.labelBold)
                }
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3))
                        RoundedRectangle(cornerRadius: 8)
                            .fill(KingdomTheme.Colors.buttonSuccess)
                            .frame(width: geo.size.width * (CGFloat(completedCount) / 4.0))
                    }
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                }
                .frame(height: 20)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            
            // Scoring area - 2x2 grid
            GeometryReader { geo in
                let loafWidth = (geo.size.width - 60) / 2
                let loafHeight = (geo.size.height - 60) / 2
                
                ZStack {
                    // Baking tray
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.3, green: 0.3, blue: 0.35))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black, lineWidth: 3))
                    
                    // Parchment
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.92, green: 0.88, blue: 0.80))
                        .padding(12)
                    
                    // 2x2 loaves
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            ScorableLoaf(hasDrawing: $loafHasDrawing[0], width: loafWidth, height: loafHeight, onComplete: checkCompletion)
                            ScorableLoaf(hasDrawing: $loafHasDrawing[1], width: loafWidth, height: loafHeight, onComplete: checkCompletion)
                        }
                        HStack(spacing: 16) {
                            ScorableLoaf(hasDrawing: $loafHasDrawing[2], width: loafWidth, height: loafHeight, onComplete: checkCompletion)
                            ScorableLoaf(hasDrawing: $loafHasDrawing[3], width: loafWidth, height: loafHeight, onComplete: checkCompletion)
                        }
                    }
                    .padding(24)
                }
            }
            .frame(maxHeight: 450)
            .padding(.horizontal, 20)
            
            Text("Score each loaf however you like")
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .padding(.vertical, 16)
        }
    }
    
    private func checkCompletion() {
        if completedCount >= 4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onComplete(90 + Int.random(in: 0...10))
            }
        }
    }
}

// MARK: - Individual Scorable Loaf

struct ScorableLoaf: View {
    @Binding var hasDrawing: Bool
    let width: CGFloat
    let height: CGFloat
    let onComplete: () -> Void
    
    @State private var paths: [[CGPoint]] = []
    @State private var currentPath: [CGPoint] = []
    
    var body: some View {
        Canvas { context, size in
            // Draw all saved paths
            for pathPoints in paths {
                if pathPoints.count >= 2 {
                    var path = Path()
                    path.move(to: pathPoints[0])
                    for point in pathPoints.dropFirst() {
                        path.addLine(to: point)
                    }
                    // Dark outer stroke
                    context.stroke(path, with: .color(Color(red: 0.5, green: 0.35, blue: 0.2)), lineWidth: 5)
                    // Light inner stroke
                    context.stroke(path, with: .color(Color(red: 0.75, green: 0.6, blue: 0.4)), lineWidth: 2)
                }
            }
            
            // Draw current path
            if currentPath.count >= 2 {
                var path = Path()
                path.move(to: currentPath[0])
                for point in currentPath.dropFirst() {
                    path.addLine(to: point)
                }
                context.stroke(path, with: .color(Color(red: 0.6, green: 0.3, blue: 0.15).opacity(0.8)), lineWidth: 4)
            }
        }
        .frame(width: width, height: height)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.88, blue: 0.75),
                            Color(red: 0.88, green: 0.78, blue: 0.62)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(red: 0.7, green: 0.58, blue: 0.42), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.2), radius: 4, y: 3)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    currentPath.append(value.location)
                    if currentPath.count % 4 == 0 {
                        HapticService.shared.lightImpact()
                    }
                }
                .onEnded { _ in
                    if currentPath.count >= 3 {
                        paths.append(currentPath)
                        if !hasDrawing {
                            hasDrawing = true
                            HapticService.shared.mediumImpact()
                            onComplete()
                        }
                    }
                    currentPath = []
                }
        )
    }
}

#Preview {
    ScoreGameView(onComplete: { _ in })
}
