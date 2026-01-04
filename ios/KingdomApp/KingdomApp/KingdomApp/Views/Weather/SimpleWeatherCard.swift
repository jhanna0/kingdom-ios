import SwiftUI

// BRUTALIST WEATHER CARD

struct SimpleWeatherCard: View {
    let weather: WeatherData?
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            // Header
            HStack {
                Image(systemName: "cloud.sun.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("Weather")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            if let weather = weather {
                HStack(spacing: KingdomTheme.Spacing.medium) {
                    // Weather icon in brutalist badge
                    Image(systemName: getIcon(weather.condition))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .brutalistBadge(
                            backgroundColor: getColor(weather.condition),
                            cornerRadius: 14,
                            shadowOffset: 3,
                            borderWidth: 2.5
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(weather.display_description)
                            .font(FontStyles.bodyLargeBold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Text("\(Int(weather.temperature_f))°F")
                            .font(FontStyles.bodyMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
                
                Text(weather.flavor_text)
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .italic()
            } else {
                Text("No weather data")
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    func getIcon(_ condition: String) -> String {
        switch condition {
        case "clear": return "sun.max.fill"
        case "rain": return "cloud.rain.fill"
        case "snow": return "snowflake"
        case "thunderstorm": return "cloud.bolt.fill"
        case "fog": return "cloud.fog.fill"
        case "clouds": return "cloud.fill"
        default: return "sun.max.fill"
        }
    }
    
    func getColor(_ condition: String) -> Color {
        switch condition {
        case "clear": return Color(red: 1.0, green: 0.84, blue: 0.0)
        case "rain": return Color(red: 0.29, green: 0.56, blue: 0.89)
        case "snow": return Color(red: 0.68, green: 0.85, blue: 0.90)
        case "thunderstorm": return Color(red: 0.45, green: 0.28, blue: 0.54)
        case "fog": return Color(red: 0.69, green: 0.69, blue: 0.69)
        case "clouds": return Color(red: 0.60, green: 0.60, blue: 0.60)
        default: return KingdomTheme.Colors.buttonWarning
        }
    }
}

