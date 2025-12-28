import SwiftUI
import CoreLocation
import MapKit

struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var locationManager = LocationManager()
    
    @State private var currentStep = 0
    @State private var username = ""
    @State private var displayName = ""
    @State private var nearbyCity: String?
    @State private var isLoadingCity = false
    @State private var useCurrentLocation = false
    @State private var selectedCity: String?
    @State private var selectedCityCoordinate: CLLocationCoordinate2D?
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if currentStep == 0 {
                    WelcomeStep(onContinue: { currentStep = 1 })
                } else if currentStep == 1 {
                    HometownStep(
                        locationManager: locationManager,
                        nearbyCity: $nearbyCity,
                        isLoadingCity: $isLoadingCity,
                        useCurrentLocation: $useCurrentLocation,
                        selectedCity: $selectedCity,
                        selectedCityCoordinate: $selectedCityCoordinate,
                        onContinue: { currentStep = 2 }
                    )
                } else if currentStep == 2 {
                    DisplayNameStep(
                        displayName: $displayName,
                        selectedCity: selectedCity ?? "your city",
                        onContinue: {
                            finishOnboarding()
                        }
                    )
                }
            }
        }
    }
    
    private func finishOnboarding() {
        Task {
            await authManager.completeOnboarding(
                displayName: displayName,
                hometownKingdomId: selectedCity // This will be the city name for now
            )
        }
    }
}

// MARK: - Step 1: Welcome

struct WelcomeStep: View {
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: KingdomTheme.Spacing.xxLarge) {
            Spacer()
            
            VStack(spacing: KingdomTheme.Spacing.large) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 80))
                    .foregroundColor(KingdomTheme.Colors.gold)
                
                Text("KINGDOM")
                    .font(.system(size: 48, weight: .bold, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.gold)
                
                Text("Build Your Empire")
                    .font(KingdomTheme.Typography.title3())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.large) {
                FeatureRow(
                    icon: "map.fill",
                    title: "Claim Real Cities",
                    description: "Visit real locations to claim and rule kingdoms"
                )
                
                FeatureRow(
                    icon: "person.3.fill",
                    title: "Build Reputation",
                    description: "Spend time in your city to gain standing"
                )
                
                FeatureRow(
                    icon: "crown.fill",
                    title: "Become a Ruler",
                    description: "Conquer kingdoms and manage your empire"
                )
            }
            .padding(.horizontal, KingdomTheme.Spacing.xxLarge)
            
            Spacer()
            
            Button(action: onContinue) {
                Text("Begin Your Journey")
                    .font(KingdomTheme.Typography.headline())
                    .fontWeight(.bold)
                    .foregroundColor(KingdomTheme.Colors.parchment)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(KingdomTheme.Colors.gold)
                    .cornerRadius(KingdomTheme.CornerRadius.large)
            }
            .padding(.horizontal, KingdomTheme.Spacing.xxLarge)
            .padding(.bottom, KingdomTheme.Spacing.xxLarge)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: KingdomTheme.Spacing.medium) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(KingdomTheme.Colors.gold)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(KingdomTheme.Typography.headline())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text(description)
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
        }
    }
}

// MARK: - Step 2: Display Name

struct DisplayNameStep: View {
    @Binding var displayName: String
    let selectedCity: String
    let onContinue: () -> Void
    
    var isValid: Bool {
        !displayName.isEmpty && displayName.count >= 2
    }
    
    var body: some View {
        VStack(spacing: KingdomTheme.Spacing.xxLarge) {
            VStack(spacing: KingdomTheme.Spacing.medium) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(KingdomTheme.Colors.gold)
                
                Text("Choose Your Name")
                    .font(KingdomTheme.Typography.title())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("What should citizens of \(selectedCity) call you?")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 60)
            .padding(.horizontal, KingdomTheme.Spacing.xxLarge)
            
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                Text("Display Name")
                    .font(KingdomTheme.Typography.headline())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                TextField("Enter your name", text: $displayName)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(KingdomTheme.Colors.parchmentLight)
                    .cornerRadius(KingdomTheme.CornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: KingdomTheme.CornerRadius.medium)
                            .stroke(KingdomTheme.Colors.border, lineWidth: 1)
                    )
                
                Text("Must be unique in \(selectedCity)")
                    .font(KingdomTheme.Typography.caption2())
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            }
            .padding(.horizontal, KingdomTheme.Spacing.xxLarge)
            
            Spacer()
            
            Button(action: onContinue) {
                Text("Establish Your Legacy")
                    .font(KingdomTheme.Typography.headline())
                    .fontWeight(.bold)
                    .foregroundColor(KingdomTheme.Colors.parchment)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValid ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkLight)
                    .cornerRadius(KingdomTheme.CornerRadius.large)
            }
            .disabled(!isValid)
            .padding(.horizontal, KingdomTheme.Spacing.xxLarge)
            .padding(.bottom, KingdomTheme.Spacing.xxLarge)
        }
    }
}

// MARK: - Step 1: Hometown Selection

struct HometownStep: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var nearbyCity: String?
    @Binding var isLoadingCity: Bool
    @Binding var useCurrentLocation: Bool
    @Binding var selectedCity: String?
    @Binding var selectedCityCoordinate: CLLocationCoordinate2D?
    let onContinue: () -> Void
    
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showLocationPrompt = false
    
    var body: some View {
        ZStack {
            // Map Background
            if let location = locationManager.currentLocation {
                Map(position: $cameraPosition) {
                    // User location marker
                    Annotation("Your Location", coordinate: location) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 60, height: 60)
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3)
                                )
                        }
                    }
                    
                    // Selected city marker
                    if let cityCoord = selectedCityCoordinate, let cityName = selectedCity {
                        Annotation(cityName, coordinate: cityCoord) {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(KingdomTheme.Colors.parchment)
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Circle()
                                                .stroke(KingdomTheme.Colors.gold, lineWidth: 3)
                                        )
                                        .shadow(radius: 4)
                                    
                                    Text("🏰")
                                        .font(.system(size: 22))
                                }
                                
                                Text(cityName)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(KingdomTheme.Colors.parchment)
                                    .cornerRadius(8)
                                    .shadow(radius: 2)
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .mapControls {
                    MapCompass()
                    MapScaleView()
                }
                .onAppear {
                    // Center on user location
                    cameraPosition = .region(MKCoordinateRegion(
                        center: location,
                        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                    ))
                    
                    // Auto-fetch nearby city
                    if nearbyCity == nil && !isLoadingCity {
                        fetchNearbyCity(coordinate: location)
                    }
                }
            } else {
                // No location permission - show prompt
                VStack(spacing: KingdomTheme.Spacing.large) {
                    Image(systemName: "location.slash.fill")
                        .font(.system(size: 60))
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                    
                    Text("Location Access Required")
                        .font(KingdomTheme.Typography.title())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("We need your location to find nearby cities and kingdoms")
                        .font(KingdomTheme.Typography.body())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        locationManager.requestPermissions()
                    }) {
                        Text("Enable Location")
                            .font(KingdomTheme.Typography.headline())
                            .fontWeight(.bold)
                            .foregroundColor(KingdomTheme.Colors.parchment)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(KingdomTheme.Colors.gold)
                            .cornerRadius(KingdomTheme.CornerRadius.large)
                    }
                    .padding(.horizontal, KingdomTheme.Spacing.xxLarge)
                }
            }
            
            // Top Header
            VStack {
                VStack(spacing: KingdomTheme.Spacing.medium) {
                    Text("Choose Your Homeland")
                        .font(KingdomTheme.Typography.title())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Where will you build your reputation?")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(KingdomTheme.Colors.parchment)
                        .shadow(radius: 8)
                )
                .padding(.horizontal)
                
                Spacer()
                
                // Bottom Card with city selection
                VStack(spacing: KingdomTheme.Spacing.large) {
                    if isLoadingCity {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: KingdomTheme.Colors.gold))
                            Text("Finding nearby cities...")
                                .font(KingdomTheme.Typography.caption())
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        .padding()
                    } else if let city = nearbyCity {
                        VStack(spacing: KingdomTheme.Spacing.medium) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(KingdomTheme.Colors.gold)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(city)
                                        .font(KingdomTheme.Typography.headline())
                                        .foregroundColor(KingdomTheme.Colors.inkDark)
                                    
                                    Text("Your current location")
                                        .font(KingdomTheme.Typography.caption())
                                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                                    .font(.title2)
                            }
                            
                            // Info bullets
                            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                                InfoBullet(text: "Build reputation by spending time here")
                                InfoBullet(text: "Must be present to perform actions")
                                InfoBullet(text: "Choose where you'll be most often")
                            }
                        }
                        .padding()
                    }
                    
                    // Continue Button
                    Button(action: onContinue) {
                        Text("Continue")
                            .font(KingdomTheme.Typography.headline())
                            .fontWeight(.bold)
                            .foregroundColor(KingdomTheme.Colors.parchment)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedCity != nil ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkLight)
                            .cornerRadius(KingdomTheme.CornerRadius.large)
                    }
                    .disabled(selectedCity == nil)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(KingdomTheme.Colors.parchment)
                        .shadow(radius: 12)
                )
                .padding(.horizontal)
            }
            .padding(.top, 60)
            .padding(.bottom, 20)
        }
        .ignoresSafeArea(edges: .all)
    }
    
    private func fetchNearbyCity(coordinate: CLLocationCoordinate2D) {
        isLoadingCity = true
        
        Task {
            // Use geocoder to get city name
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                
                await MainActor.run {
                    if let placemark = placemarks.first {
                        // Try to get city name from various fields
                        let cityName = placemark.locality ?? 
                                      placemark.subLocality ?? 
                                      placemark.administrativeArea ?? 
                                      "Unknown City"
                        
                        nearbyCity = cityName
                        selectedCity = cityName
                        selectedCityCoordinate = coordinate
                        useCurrentLocation = true
                    }
                    isLoadingCity = false
                }
            } catch {
                print("Geocoding error: \(error)")
                await MainActor.run {
                    nearbyCity = "Unknown Location"
                    selectedCity = "Unknown Location"
                    selectedCityCoordinate = coordinate
                    isLoadingCity = false
                }
            }
        }
    }
}

struct InfoBullet: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: KingdomTheme.Spacing.small) {
            Text("•")
                .font(KingdomTheme.Typography.body())
                .foregroundColor(KingdomTheme.Colors.buttonWarning)
            Text(text)
                .font(KingdomTheme.Typography.caption())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
    }
}

struct LocationOptionCard: View {
    let cityName: String
    let subtitle: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(KingdomTheme.Colors.gold)
                        Text(cityName)
                            .font(KingdomTheme.Typography.headline())
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    }
                    
                    Text(subtitle)
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                        .font(.title2)
                }
            }
            .padding(KingdomTheme.Spacing.large)
            .background(isSelected ? KingdomTheme.Colors.parchmentHighlight : KingdomTheme.Colors.parchmentLight)
            .cornerRadius(KingdomTheme.CornerRadius.large)
            .overlay(
                RoundedRectangle(cornerRadius: KingdomTheme.CornerRadius.large)
                    .stroke(
                        isSelected ? KingdomTheme.Colors.gold : KingdomTheme.Colors.border,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
    }
}

