import SwiftUI

// MARK: - Animated Stripes

struct AnimatedStripes: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let stripeWidth: CGFloat = 8
                let stripeSpacing: CGFloat = 16
                let phase = (time.truncatingRemainder(dividingBy: 1.0)) * stripeSpacing
                
                // Start stripes before the visible area to cover the diagonal
                let startOffset = -size.height
                let endOffset = size.width + size.height
                let totalRange = endOffset - startOffset
                let stripeCount = Int(ceil(totalRange / stripeSpacing)) + 2
                
                for i in 0..<stripeCount {
                    let offset = startOffset + CGFloat(i) * stripeSpacing - phase
                    
                    var path = Path()
                    path.move(to: CGPoint(x: offset, y: 0))
                    path.addLine(to: CGPoint(x: offset + size.height, y: size.height))
                    path.addLine(to: CGPoint(x: offset + size.height + stripeWidth, y: size.height))
                    path.addLine(to: CGPoint(x: offset + stripeWidth, y: 0))
                    path.closeSubpath()
                    
                    context.fill(path, with: .color(.white.opacity(0.15)))
                }
            }
        }
    }
}

