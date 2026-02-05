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
    @State private var hasInitializedStep = false
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if currentStep == 0 {
                    WelcomeStep(onContinue: {
                        DebugLogger.shared.log("onboarding_step", message: "Step 0 -> 1 (Welcome -> Hometown)")
                        currentStep = 1
                    })
                } else if currentStep == 1 {
                    HometownStep(
                        locationManager: locationManager,
                        nearbyCity: $nearbyCity,
                        isLoadingCity: $isLoadingCity,
                        useCurrentLocation: $useCurrentLocation,
                        selectedCity: $selectedCity,
                        selectedCityOsmId: $selectedCityOsmId,
                        selectedCityCoordinate: $selectedCityCoordinate,
                        onBack: { currentStep = 0 },
                        onContinue: {
                            DebugLogger.shared.log("onboarding_step", message: "Step 1 -> 2 (Hometown -> DisplayName)", extra: [
                                "selectedCity": selectedCity ?? "nil",
                                "selectedCityOsmId": selectedCityOsmId ?? "nil"
                            ])
                            currentStep = 2
                        }
                    )
                } else if currentStep == 2 {
                    DisplayNameStep(
                        displayName: $displayName,
                        selectedCity: selectedCity ?? "your city",
                        hometownId: selectedCityOsmId ?? authManager.currentUser?.hometown_kingdom_id,
                        onBack: { currentStep = 1 },
                        onContinue: { currentStep = 3 }
                    )
                    .environmentObject(authManager)
                } else if currentStep == 3 {
                    BalanceStep(
                        onBack: { currentStep = 2 },
                        onContinue: {
                            authManager.finishOnboarding()
                        }
                    )
                }
            }
        }
        .onAppear {
            DebugLogger.shared.log("onboarding_appear", message: "OnboardingView appeared")
            
            // Only initialize once - resume at the correct step based on what's missing
            guard !hasInitializedStep else { return }
            hasInitializedStep = true
            
            if let user = authManager.currentUser {
                // Check what's missing and resume at appropriate step
                let hasHometown = user.hometown_kingdom_id != nil && !(user.hometown_kingdom_id?.isEmpty ?? true)
                let trimmedName = user.display_name.trimmingCharacters(in: .whitespacesAndNewlines)
                let hasValidName = !trimmedName.isEmpty && trimmedName != "User"
                
                DebugLogger.shared.log("onboarding_init", message: "Checking user state", extra: [
                    "hasHometown": hasHometown,
                    "hasValidName": hasValidName,
                    "displayName": trimmedName
                ])
                
                // Pre-fill display name when available (reduces friction for partial onboarding)
                if hasValidName {
                    displayName = trimmedName
                }
                
                if hasHometown && !hasValidName {
                    // Has hometown but needs display name - skip to step 2
                    // Pre-fill with current display name if it's not "User"
                    if trimmedName != "User" {
                        displayName = user.display_name
                    }
                    selectedCityOsmId = user.hometown_kingdom_id
                    currentStep = 2
                    DebugLogger.shared.log("onboarding_skip", message: "Skipping to step 2 (display name)")
                } else if !hasHometown {
                    // Needs hometown - start at step 1 (skip welcome for returning users)
                    currentStep = 1
                    DebugLogger.shared.log("onboarding_skip", message: "Skipping to step 1 (hometown)")
                }
                // If both are missing, stay at step 0 (welcome)
            } else {
                DebugLogger.shared.log("onboarding_init", message: "No current user found")
            }
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

// MARK: - Step 3: Live Balance

struct BalanceStep: View {
    let onBack: () -> Void
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: KingdomTheme.Spacing.xxLarge) {
            // Back button
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                Spacer()
            }
            .padding(.horizontal, KingdomTheme.Spacing.large)
            .padding(.top, KingdomTheme.Spacing.medium)
            
            // Header with brutalist icon
            VStack(spacing: KingdomTheme.Spacing.large) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                    .frame(width: 100, height: 100)
                    .brutalistBadge(
                        backgroundColor: KingdomTheme.Colors.inkMedium,
                        cornerRadius: 20,
                        shadowOffset: 4,
                        borderWidth: 3
                    )
                
                Text("Live Balance")
                    .font(FontStyles.displayMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("This game has many moving parts. We constantly monitor and tune it for fairness.")
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, KingdomTheme.Spacing.large)
            
            // Info Card
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                Text("What to expect")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 2)
                
                VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                    InfoBullet(text: "Exact rewards and perks are still being refined and may change")
                    InfoBullet(text: "Rewards and drop rates may change over time")
                    InfoBullet(text: "Overpowered strategies may be adjusted")
                    InfoBullet(text: "Updates focus on stability and a fair economy")
                }
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
                    Text("Enter the Kingdom")
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

// MARK: - Step 2: Display Name

struct DisplayNameStep: View {
    @EnvironmentObject var authManager: AuthManager
    @Binding var displayName: String
    let selectedCity: String
    let hometownId: String?
    let onBack: () -> Void
    let onContinue: () -> Void
    
    @State private var validationResult: UsernameValidator.ValidationResult = .valid
    @State private var isSaving = false
    
    var isValid: Bool {
        validationResult.isValid && !displayName.isEmpty && !isSaving
    }
    
    var body: some View {
        VStack(spacing: KingdomTheme.Spacing.xxLarge) {
            // Back button
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                Spacer()
            }
            .padding(.horizontal, KingdomTheme.Spacing.large)
            .padding(.top, KingdomTheme.Spacing.medium)
            
            // Header
            VStack(spacing: KingdomTheme.Spacing.large) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                    .frame(width: 100, height: 100)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 20, shadowOffset: 4, borderWidth: 3)
                
                Text("Choose Your Name")
                    .font(FontStyles.displayMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("What should citizens of \(selectedCity) call you?")
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .multilineTextAlignment(.center)
            }
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
                        .submitLabel(.done)
                        .disabled(isSaving)
                }
                .background(Color.white)
                .cornerRadius(KingdomTheme.Brutalist.cornerRadiusSmall)
                .overlay(
                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusSmall)
                        .stroke(authManager.onboardingError != nil ? Color.red : Color.black, lineWidth: 2)
                )
                .onChange(of: displayName) { _, newValue in
                    if newValue.count > 20 { displayName = String(newValue.prefix(20)) }
                    validationResult = UsernameValidator.validate(displayName)
                    authManager.onboardingError = nil
                }
                
                // Error message
                if let error = authManager.onboardingError {
                    Text(error)
                        .font(FontStyles.labelSmall)
                        .foregroundColor(.red)
                }
                
                // Requirements
                VStack(alignment: .leading, spacing: 4) {
                    Text("• 3-20 characters")
                    Text("• Letters and numbers only")
                }
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .padding(.top, 4)
                
                Text("Must be unique across all kingdoms")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            }
            .padding(KingdomTheme.Spacing.large)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 20)
            .padding(.horizontal, KingdomTheme.Spacing.large)
            
            Spacer()
            
            // Continue Button
            Button {
                displayName = UsernameValidator.sanitize(displayName)
                isSaving = true
                Task {
                    let success = await authManager.completeOnboarding(displayName: displayName, hometownKingdomId: hometownId)
                    isSaving = false
                    if success { onContinue() }
                }
            } label: {
                HStack {
                    if isSaving {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Establish Your Legacy").font(FontStyles.bodyLargeBold)
                        Image(systemName: "arrow.right").font(FontStyles.iconSmall)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, KingdomTheme.Spacing.large)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium).fill(Color.black).offset(x: 4, y: 4)
                        RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                            .fill(isValid ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.disabled)
                            .overlay(RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium).stroke(Color.black, lineWidth: 3))
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
    let onBack: () -> Void
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
                                    .font(FontStyles.labelBold)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(KingdomTheme.Colors.parchment)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(KingdomTheme.Colors.inkMedium, lineWidth: 2)
                                    )
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
                    Image(systemName: locationManager.isLocationDenied ? "location.slash.fill" : "location.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white)
                        .frame(width: 100, height: 100)
                        .brutalistBadge(
                            backgroundColor: locationManager.isLocationDenied ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.buttonWarning,
                            cornerRadius: 20,
                            shadowOffset: 4,
                            borderWidth: 3
                        )
                    
                    VStack(spacing: KingdomTheme.Spacing.medium) {
                        Text("Location Access Required")
                            .font(FontStyles.displayMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        if locationManager.isLocationDenied {
                            Text("Location access is required to find nearby cities and kingdoms. You can enable it in Settings.")
                                .font(FontStyles.bodyMedium)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("We need your location to find nearby cities and kingdoms")
                                .font(FontStyles.bodyMedium)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Privacy notice
                        BulletPoint(icon: "lock.shield.fill", text: "Your precise location is never stored")
                    }
                    .padding(.horizontal, KingdomTheme.Spacing.large)
                    
                    Button(action: {
                        locationManager.requestPermissions()
                    }) {
                        HStack {
                            Text(locationManager.isLocationDenied ? "Open Settings" : "Continue")
                                .font(FontStyles.bodyLargeBold)
                            Image(systemName: locationManager.isLocationDenied ? "gear" : "location.fill")
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
                // Back button
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                            .padding(KingdomTheme.Spacing.small)
                            .background(KingdomTheme.Colors.parchment.opacity(0.9))
                            .cornerRadius(8)
                    }
                    Spacer()
                }
                .padding(.horizontal, KingdomTheme.Spacing.medium)
                .padding(.bottom, KingdomTheme.Spacing.small)
                
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
                            // City header
                            HStack(spacing: KingdomTheme.Spacing.medium) {
                                Image(systemName: "building.columns.fill")
                                    .font(FontStyles.iconExtraLarge)
                                    .foregroundColor(.white)
                                    .frame(width: 48, height: 48)
                                    .brutalistBadge(
                                        backgroundColor: KingdomTheme.Colors.inkMedium,
                                        cornerRadius: 12,
                                        shadowOffset: 3,
                                        borderWidth: 2
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(city)
                                        .font(FontStyles.headingLarge)
                                        .foregroundColor(KingdomTheme.Colors.inkDark)
                                    
                                    Text("Your homeland")
                                        .font(FontStyles.bodySmall)
                                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                                }
                                
                                Spacer()
                            }
                            
                            Rectangle()
                                .fill(KingdomTheme.Colors.inkMedium.opacity(0.3))
                                .frame(height: 1)
                            
                            // Info bullets
                            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                                BulletPoint(icon: "mappin.circle.fill", text: "Choose the place you'll be most often")
                                BulletPoint(icon: "lock.shield.fill", text: "Your location is NEVER stored- only the city")
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
        DebugLogger.shared.log("hometown_fetch_start", message: "Fetching nearby city", extra: [
            "lat": coordinate.latitude,
            "lon": coordinate.longitude
        ])
        
        isLoadingCity = true
        
        Task {
            // Call API to get city with OSM ID
            do {
                let apiClient = APIClient.shared
                let request = apiClient.request(
                    endpoint: "/cities/current?lat=\(coordinate.latitude)&lon=\(coordinate.longitude)"
                )
                
                let cityResponse: CityBoundaryResponse = try await apiClient.execute(request)
                
                DebugLogger.shared.log("hometown_fetch_success", message: "City found: \(cityResponse.name)", extra: [
                    "osm_id": cityResponse.osm_id
                ])
                
                await MainActor.run {
                    nearbyCity = cityResponse.name
                    selectedCity = cityResponse.name
                    selectedCityOsmId = cityResponse.osm_id  // Store OSM ID!
                    selectedCityCoordinate = coordinate
                    useCurrentLocation = true
                    isLoadingCity = false
                }
            } catch {
                DebugLogger.shared.log("hometown_fetch_error", message: "City lookup failed: \(error.localizedDescription)")
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

struct BulletPoint: View {
    let icon: String
    let text: String
    
    var body: some View {
        Label {
            Text(text)
                .font(FontStyles.bodySmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        } icon: {
            Image(systemName: icon)
                .font(FontStyles.iconTiny)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
    }
}

struct InfoBullet: View {
    let text: String
    
    var body: some View {
        BulletPoint(icon: "checkmark.circle.fill", text: text)
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
                    HStack(spacing: KingdomTheme.Spacing.small) {
                        Image(systemName: "mappin.circle.fill")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        Text(cityName)
                            .font(FontStyles.headingMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    }
                    
                    Text(subtitle)
                        .font(FontStyles.bodySmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(FontStyles.iconMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            .padding(KingdomTheme.Spacing.large)
            .background(isSelected ? KingdomTheme.Colors.parchmentHighlight : KingdomTheme.Colors.parchmentLight)
            .cornerRadius(KingdomTheme.Brutalist.cornerRadiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                    .stroke(
                        isSelected ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.border,
                        lineWidth: isSelected ? 3 : 2
                    )
            )
        }
    }
}

