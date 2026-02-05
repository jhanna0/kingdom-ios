import SwiftUI

// MARK: - Shape Game

struct ShapeGameView: View {
    let onComplete: (Int) -> Void
    
    @State private var doughPoints: [DoughPoint] = []
    @State private var roundness: CGFloat = 0.3
    @State private var shapeProgress: CGFloat = 0
    @State private var isTouching = false
    @State private var touchPosition: CGPoint = .zero
    @State private var rotationAngle: CGFloat = 0
    @State private var lastAngle: CGFloat = 0
    @State private var totalRotation: CGFloat = 0
    @State private var tensionLines: [TensionLine] = []
    
    let targetRotation: CGFloat = 4000 // Multiple full rotations
    
    var body: some View {
        VStack(spacing: 0) {
            // INSTRUCTION
            Text("Rotate around the dough to shape it round!")
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            
            // PROGRESS BAR
            VStack(spacing: 4) {
                HStack {
                    Text("Roundness")
                    Spacer()
                    Text("\(Int(shapeProgress * 100))%")
                        .font(FontStyles.labelBold)
                }
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3))
                        RoundedRectangle(cornerRadius: 8)
                            .fill(KingdomTheme.Colors.buttonSuccess)
                            .frame(width: geo.size.width * shapeProgress)
                    }
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                }
                .frame(height: 20)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            
            // GAME AREA
            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                
                ZStack {
                    // Work surface
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(red: 0.82, green: 0.72, blue: 0.58), Color(red: 0.72, green: 0.62, blue: 0.48)],
                                center: .center, startRadius: 0, endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .overlay(Circle().stroke(Color.black, lineWidth: 3))
                        .position(center)
                    
                    // Guide circle
                    Circle()
                        .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 3, dash: [10, 10]))
                        .frame(width: 180, height: 180)
                        .position(center)
                    
                    // Rotation arrow hint
                    if shapeProgress < 0.2 {
                        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.4))
                            .position(center)
                    }
                    
                    // Dough
                    morphingDough(center: center)
                        .position(center)
                    
                    // Touch indicator (hands)
                    if isTouching {
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 50, height: 50)
                            .position(touchPosition)
                        
                        // Opposite hand
                        let oppositeX = 2 * center.x - touchPosition.x
                        let oppositeY = 2 * center.y - touchPosition.y
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 50, height: 50)
                            .position(x: oppositeX, y: oppositeY)
                    }
                    
                    // Tension lines
                    ForEach(tensionLines) { line in
                        Capsule()
                            .fill(Color(red: 0.85, green: 0.75, blue: 0.62).opacity(line.opacity))
                            .frame(width: line.length, height: 2)
                            .rotationEffect(.degrees(line.angle))
                            .position(center)
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            handleShapeDrag(value: value, center: center)
                        }
                        .onEnded { _ in
                            isTouching = false
                        }
                )
            }
            .frame(maxHeight: 450)
            
            Text("Create surface tension for a perfect rise")
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .padding(.vertical, 16)
        }
    }
    
    @ViewBuilder
    private func morphingDough(center: CGPoint) -> some View {
        let blobAmount = 1.0 - roundness
        
        Canvas { context, size in
            var path = Path()
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let baseRadius: CGFloat = 60
            
            for i in 0..<72 {
                let angle = CGFloat(i) * .pi * 2 / 72
                let wobble1 = sin(angle * 3 + rotationAngle * 0.02) * 20 * blobAmount
                let wobble2 = sin(angle * 5 + rotationAngle * 0.03) * 10 * blobAmount
                let wobble3 = sin(angle * 7) * 5 * blobAmount
                let r = baseRadius + wobble1 + wobble2 + wobble3
                
                let x = center.x + cos(angle) * r
                let y = center.y + sin(angle) * r * 0.85
                
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubpath()
            
            context.fill(
                path,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.95, green: 0.88, blue: 0.76),
                        Color(red: 0.88, green: 0.78, blue: 0.65)
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                )
            )
            
            context.stroke(path, with: .color(Color(red: 0.75, green: 0.65, blue: 0.50)), lineWidth: 2)
        }
        .frame(width: 160, height: 140)
        .scaleEffect(isTouching ? 1.03 : 1.0)
    }
    
    private func handleShapeDrag(value: DragGesture.Value, center: CGPoint) {
        isTouching = true
        touchPosition = value.location
        
        let dx = value.location.x - center.x
        let dy = value.location.y - center.y
        let currentAngle = atan2(dy, dx)
        
        var delta = currentAngle - lastAngle
        lastAngle = currentAngle
        
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        
        let rotationAmount = abs(delta * 180 / .pi)
        totalRotation += rotationAmount
        rotationAngle += delta * 50
        
        shapeProgress = min(1.0, totalRotation / targetRotation)
        roundness = 0.3 + shapeProgress * 0.7
        
        // Add tension lines as it gets rounder
        if shapeProgress > 0.5 && Int(totalRotation) % 100 == 0 {
            addTensionLine()
        }
        
        if Int(totalRotation) % 50 == 0 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        if shapeProgress >= 1.0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onComplete(95)
            }
        }
    }
    
    private func addTensionLine() {
        let line = TensionLine(
            id: UUID(),
            length: CGFloat.random(in: 25...45),
            angle: Double.random(in: 0...360),
            opacity: 0.6
        )
        tensionLines.append(line)
        
        if tensionLines.count > 8 {
            tensionLines.removeFirst()
        }
    }
}

// MARK: - Supporting Types

struct DoughPoint: Identifiable {
    let id = UUID()
    var position: CGPoint
    var radius: CGFloat
}

struct TensionLine: Identifiable {
    let id: UUID
    var length: CGFloat
    var angle: Double
    var opacity: Double
}

#Preview {
    ShapeGameView(onComplete: { _ in })
}
