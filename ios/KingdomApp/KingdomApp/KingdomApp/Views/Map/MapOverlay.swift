import SwiftUI

/// Decorative overlay for the map with brutalist corner brackets
struct MapOverlay: View {
    var body: some View {
        ZStack {
            // Decorative corner brackets - brutalist style
            VStack {
                HStack {
                    BrutalistCornerBracket()
                        .frame(width: 50, height: 50)
                    Spacer()
                    BrutalistCornerBracket()
                        .frame(width: 50, height: 50)
                        .scaleEffect(x: -1, y: 1)
                }
                Spacer()
                HStack {
                    BrutalistCornerBracket()
                        .frame(width: 50, height: 50)
                        .scaleEffect(x: 1, y: -1)
                    Spacer()
                    BrutalistCornerBracket()
                        .frame(width: 50, height: 50)
                        .scaleEffect(x: -1, y: -1)
                }
            }
            .padding(16)
            .allowsHitTesting(false)
        }
    }
}

/// Brutalist corner bracket decoration
struct BrutalistCornerBracket: View {
    var body: some View {
        Canvas { context, size in
            // Outer bracket (shadow)
            let shadowPath = Path { p in
                p.move(to: CGPoint(x: 4, y: size.height * 0.6 + 3))
                p.addLine(to: CGPoint(x: 4, y: 3))
                p.addLine(to: CGPoint(x: size.width * 0.6 + 3, y: 3))
            }
            
            context.stroke(
                shadowPath,
                with: .color(Color.black.opacity(0.4)),
                style: StrokeStyle(lineWidth: 4, lineCap: .square)
            )
            
            // Main bracket
            let mainPath = Path { p in
                p.move(to: CGPoint(x: 0, y: size.height * 0.6))
                p.addLine(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: size.width * 0.6, y: 0))
            }
            
            context.stroke(
                mainPath,
                with: .color(Color.black),
                style: StrokeStyle(lineWidth: 4, lineCap: .square)
            )
            
            // Corner dot
            let dotRect = CGRect(x: -3, y: -3, width: 10, height: 10)
            context.fill(
                Path(ellipseIn: dotRect),
                with: .color(Color.black)
            )
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
        MapOverlay()
    }
}

