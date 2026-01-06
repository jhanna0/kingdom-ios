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
    @State private var selectedCityOsmId: String?  // OSM ID for hometown kingdom
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
                        selectedCityOsmId: $selectedCityOsmId,
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
                hometownKingdomId: selectedCityOsmId // Now passing the OSM ID
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
            
            // Logo with brutalist badge
            VStack(spacing: KingdomTheme.Spacing.large) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.white)
                    .frame(width: 120, height: 120)
                    .brutalistBadge(
                        backgroundColor: KingdomTheme.Colors.inkMedium,
                        cornerRadius: 24,
                        shadowOffset: 6,
                        borderWidth: 4
                    )
                
                Text("KINGDOM")
                    .font(FontStyles.displayLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("Build Your Empire")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
            
            // Features Card
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
            .padding(KingdomTheme.Spacing.large)
            .brutalistCard(
                backgroundColor: KingdomTheme.Colors.parchmentLight,
                cornerRadius: 20
            )
            .padding(.horizontal, KingdomTheme.Spacing.large)
            
            Spacer()
            
            // Continue Button
            Button(action: onContinue) {
                HStack {
                    Text("Begin Your Journey")
                        .font(FontStyles.bodyLargeBold)
                    Image(systemName: "arrow.right")
                        .font(FontStyles.iconSmall)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, KingdomTheme.Spacing.large)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                            .fill(Color.black)
                            .offset(x: 4, y: 4)
                        RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                            .fill(KingdomTheme.Colors.inkMedium)
                            .overlay(
                                RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                                    .stroke(Color.black, lineWidth: 3)
                            )
                    }
                )
            }
            .padding(.horizontal, KingdomTheme.Spacing.large)
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
            // Icon with brutalist badge
            Image(systemName: icon)
                .font(FontStyles.iconSmall)
                .foregroundColor(.white)
                .frame(width: 42, height: 42)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.inkMedium,
                    cornerRadius: 8
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(FontStyles.headingSmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text(description)
                    .font(FontStyles.bodySmall)
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
    
    @State private var validationResult: UsernameValidator.ValidationResult = .valid
    @State private var showValidation = false
    
    var validationHints: [ValidationHint] {
        UsernameValidator.getValidationHints(for: displayName)
    }
    
    var isValid: Bool {
        validationResult.isValid && !displayName.isEmpty
    }
    
    var body: some View {
        VStack(spacing: KingdomTheme.Spacing.xxLarge) {
            // Header with brutalist icon
            VStack(spacing: KingdomTheme.Spacing.large) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                    .frame(width: 100, height: 100)
                    .brutalistBadge(
                        backgroundColor: KingdomTheme.Colors.inkMedium,
                        cornerRadius: 20,
                        shadowOffset: 4,
                        borderWidth: 3
                    )
                
                Text("Choose Your Name")
                    .font(FontStyles.displayMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("What should citizens of \(selectedCity) call you?")
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 60)
            .padding(.horizontal, KingdomTheme.Spacing.large)
            
            // Input Card
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                Text("Display Name")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                ZStack(alignment: .leading) {
                    if displayName.isEmpty {
                        Text("Enter your name")
                            .font(FontStyles.bodyLarge)
                            .foregroundColor(KingdomTheme.Colors.inkMedium.opacity(0.5))
                            .padding(.leading, KingdomTheme.Spacing.medium)
                    }
                    
                    TextField("", text: $displayName)
                        .font(FontStyles.bodyLarge)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .textFieldStyle(.plain)
                        .padding(KingdomTheme.Spacing.medium)
                }
                .background(Color.white)
                .cornerRadius(KingdomTheme.Brutalist.cornerRadiusSmall)
                .overlay(
                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusSmall)
                        .stroke(
                            showValidation && !validationResult.isValid ? 
                                Color.red : Color.black, 
                            lineWidth: showValidation && !validationResult.isValid ? 3 : 2
                        )
                )
                .onChange(of: displayName) { oldValue, newValue in
                    showValidation = !newValue.isEmpty
                    validationResult = UsernameValidator.validate(newValue)
                }
                
                // Validation hints
                if showValidation && !displayName.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(validationHints) { hint in
                            HStack(spacing: 8) {
                                Image(systemName: hint.isValid ? "checkmark.circle.fill" : "circle")
                                    .font(FontStyles.iconMini)
                                    .foregroundColor(hint.isValid ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.inkLight)
                                
                                Text(hint.text)
                                    .font(FontStyles.labelSmall)
                                    .foregroundColor(hint.isValid ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.inkLight)
                            }
                        }
                        
                        if !validationResult.isValid && !validationResult.errorMessage.isEmpty {
                            Text(validationResult.errorMessage)
                                .font(FontStyles.labelSmall)
                                .foregroundColor(.red)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.top, 4)
                }
                
                Text("Must be unique across all kingdoms")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                    .padding(.top, 4)
            }
            .padding(KingdomTheme.Spacing.large)
            .brutalistCard(
                backgroundColor: KingdomTheme.Colors.parchmentLight,
                cornerRadius: 20
            )
            .padding(.horizontal, KingdomTheme.Spacing.large)
            
            Spacer()
            
            // Continue Button
            Button(action: {
                // Sanitize before sending
                displayName = UsernameValidator.sanitize(displayName)
                onContinue()
            }) {
                HStack {
                    Text("Establish Your Legacy")
                        .font(FontStyles.bodyLargeBold)
                    Image(systemName: "arrow.right")
                        .font(FontStyles.iconSmall)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, KingdomTheme.Spacing.large)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                            .fill(Color.black)
                            .offset(x: 4, y: 4)
                        RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                            .fill(isValid ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.disabled)
                            .overlay(
                                RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                                    .stroke(Color.black, lineWidth: 3)
                            )
                    }
                )
            }
            .disabled(!isValid)
            .padding(.horizontal, KingdomTheme.Spacing.large)
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
    @Binding var selectedCityOsmId: String?
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
                                                .stroke(KingdomTheme.Colors.inkMedium, lineWidth: 3)
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
                VStack(spacing: KingdomTheme.Spacing.xxLarge) {
                    Image(systemName: "location.slash.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white)
                        .frame(width: 100, height: 100)
                        .brutalistBadge(
                            backgroundColor: KingdomTheme.Colors.buttonWarning,
                            cornerRadius: 20,
                            shadowOffset: 4,
                            borderWidth: 3
                        )
                    
                    VStack(spacing: KingdomTheme.Spacing.medium) {
                        Text("Location Access Required")
                            .font(FontStyles.displayMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Text("We need your location to find nearby cities and kingdoms")
                            .font(FontStyles.bodyMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, KingdomTheme.Spacing.large)
                    
                    Button(action: {
                        locationManager.requestPermissions()
                    }) {
                        HStack {
                            Text("Enable Location")
                                .font(FontStyles.bodyLargeBold)
                            Image(systemName: "location.fill")
                                .font(FontStyles.iconSmall)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KingdomTheme.Spacing.large)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                                    .fill(Color.black)
                                    .offset(x: 4, y: 4)
                                RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                                    .fill(KingdomTheme.Colors.inkMedium)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                                            .stroke(Color.black, lineWidth: 3)
                                    )
                            }
                        )
                    }
                    .padding(.horizontal, KingdomTheme.Spacing.large)
                }
            }
            
            // Top Header
            VStack {
                HStack(spacing: KingdomTheme.Spacing.medium) {
                    Image(systemName: "map.fill")
                        .font(FontStyles.iconMedium)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .brutalistBadge(
                            backgroundColor: KingdomTheme.Colors.inkMedium,
                            cornerRadius: 10
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Choose Your Homeland")
                            .font(FontStyles.headingLarge)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Text("Where will you build your reputation?")
                            .font(FontStyles.bodySmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    
                    Spacer()
                }
                .padding(KingdomTheme.Spacing.large)
                .brutalistCard(
                    backgroundColor: KingdomTheme.Colors.parchment,
                    cornerRadius: 16
                )
                .padding(.horizontal, KingdomTheme.Spacing.medium)
                
                Spacer()
                
                // Bottom Card with city selection
                VStack(spacing: KingdomTheme.Spacing.large) {
                    if isLoadingCity {
                        HStack(spacing: KingdomTheme.Spacing.medium) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: KingdomTheme.Colors.inkMedium))
                            Text("Finding nearby cities...")
                                .font(FontStyles.bodyMedium)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        .padding(KingdomTheme.Spacing.large)
                    } else if let city = nearbyCity {
                        VStack(spacing: KingdomTheme.Spacing.medium) {
                            HStack(spacing: KingdomTheme.Spacing.medium) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(FontStyles.iconMedium)
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .brutalistBadge(
                                        backgroundColor: KingdomTheme.Colors.inkMedium,
                                        cornerRadius: 10
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(city)
                                        .font(FontStyles.headingMedium)
                                        .foregroundColor(KingdomTheme.Colors.inkDark)
                                    
                                    Text("Your current location")
                                        .font(FontStyles.labelMedium)
                                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                                    .font(FontStyles.iconMedium)
                            }
                            
                            Rectangle()
                                .fill(Color.black)
                                .frame(height: 2)
                            
                            // Info bullets
                            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                                InfoBullet(text: "Build reputation by spending time here")
                                InfoBullet(text: "Must be present to perform actions")
                                InfoBullet(text: "Choose where you'll be most often")
                            }
                        }
                        .padding(KingdomTheme.Spacing.large)
                    }
                    
                    // Continue Button
                    Button(action: onContinue) {
                        HStack {
                            Text("Continue")
                                .font(FontStyles.bodyLargeBold)
                            Image(systemName: "arrow.right")
                                .font(FontStyles.iconSmall)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KingdomTheme.Spacing.large)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                                    .fill(Color.black)
                                    .offset(x: 4, y: 4)
                                RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                                    .fill(selectedCity != nil ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.disabled)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                                            .stroke(Color.black, lineWidth: 3)
                                    )
                            }
                        )
                    }
                    .disabled(selectedCity == nil)
                    .padding(.horizontal, KingdomTheme.Spacing.medium)
                }
                .padding(KingdomTheme.Spacing.large)
                .brutalistCard(
                    backgroundColor: KingdomTheme.Colors.parchment,
                    cornerRadius: 20
                )
                .padding(.horizontal, KingdomTheme.Spacing.medium)
            }
            .padding(.top, 60)
            .padding(.bottom, 20)
        }
        .ignoresSafeArea(edges: .all)
    }
    
    private func fetchNearbyCity(coordinate: CLLocationCoordinate2D) {
        isLoadingCity = true
        
        Task {
            // Call API to get city with OSM ID
            do {
                let apiClient = APIClient.shared
                let request = apiClient.request(
                    endpoint: "/cities/current?lat=\(coordinate.latitude)&lon=\(coordinate.longitude)"
                )
                
                let cityResponse: CityBoundaryResponse = try await apiClient.execute(request)
                
                await MainActor.run {
                    nearbyCity = cityResponse.name
                    selectedCity = cityResponse.name
                    selectedCityOsmId = cityResponse.osm_id  // Store OSM ID!
                    selectedCityCoordinate = coordinate
                    useCurrentLocation = true
                    isLoadingCity = false
                }
            } catch {
                print("City lookup error: \(error)")
                await MainActor.run {
                    nearbyCity = "Unknown Location"
                    selectedCity = "Unknown Location"
                    selectedCityOsmId = nil
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
            Image(systemName: "checkmark.circle.fill")
                .font(FontStyles.iconMini)
                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
            Text(text)
                .font(FontStyles.labelMedium)
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
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
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
                        isSelected ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.border,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
    }
}

