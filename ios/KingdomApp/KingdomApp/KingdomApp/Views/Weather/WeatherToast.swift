import SwiftUI

/// Weather toast - white text with icon, top right under HUD
struct WeatherToast: View {
    let weather: WeatherData
    let onDismiss: () -> Void
    
    @State private var opacity: Double = 1.0
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: weatherIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            
            Text("\(weather.display_description) · \(Int(weather.temperature_f))°")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
        }
        .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 1)
        .opacity(opacity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                withAnimation(.easeOut(duration: 1.0)) {
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onDismiss()
                }
            }
        }
    }
    
    private var weatherIcon: String {
        switch weather.condition {
        case "clear": return "sun.max.fill"
        case "rain": return "cloud.rain.fill"
        case "snow": return "snowflake"
        case "thunderstorm": return "cloud.bolt.fill"
        case "fog": return "cloud.fog.fill"
        case "clouds": return "cloud.fill"
        default: return "sun.max.fill"
        }
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        
        VStack {
            HStack {
                Spacer()
                WeatherToast(
                    weather: WeatherData(
                        condition: "clear",
                        temperature: 22.0,
                        temperature_f: 72.0,
                        display_description: "Clear skies",
                        flavor_text: "A beautiful day"
                    ),
                    onDismiss: {}
                )
                .padding(.trailing, 16)
            }
            .padding(.top, 160)
            
            Spacer()
        }
    }
}
