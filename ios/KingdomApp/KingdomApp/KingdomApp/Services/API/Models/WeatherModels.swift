import Foundation

// SIMPLE WEATHER - Just what we need!

struct WeatherResponse: Codable {
    let success: Bool
    let weather: WeatherData?
}

struct WeatherData: Codable {
    let condition: String
    let temperature: Double
    let temperature_f: Double
    let display_description: String
    let flavor_text: String
}

