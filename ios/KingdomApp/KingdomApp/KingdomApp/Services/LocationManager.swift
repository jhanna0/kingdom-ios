import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocationCoordinate2D?
    
    // MARK: - Debug/Testing Features
    /// Set to true to use fake location instead of real GPS
    static var useFakeLocation = false
    
    /// Test city locations for development
    /// NOTE: Not all locations may have kingdom data in the database yet.
    /// If you get "No city found" errors, try a different city or use a location
    /// where you've previously played the game.
    static let testCities = [
        "nyc": CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),        // New York City
        "sf": CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4134),       // San Francisco (Tenderloin)
        "la": CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),       // Los Angeles
        "santabarbara": CLLocationCoordinate2D(latitude: 34.4208, longitude: -119.6982), // Santa Barbara
        "boston": CLLocationCoordinate2D(latitude: 42.3601, longitude: -71.0589),    // Boston
        "chicago": CLLocationCoordinate2D(latitude: 41.8781, longitude: -87.6298),   // Chicago
        "miami": CLLocationCoordinate2D(latitude: 25.7617, longitude: -80.1918),     // Miami
        "seattle": CLLocationCoordinate2D(latitude: 47.6062, longitude: -122.3321),  // Seattle
        "austin": CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431),    // Austin
        "denver": CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),   // Denver
        "portland": CLLocationCoordinate2D(latitude: 45.5152, longitude: -122.6784), // Portland
        "galena": CLLocationCoordinate2D(latitude: 42.4167, longitude: -90.4292),    // Galena, IL (small town near Chicago)
        
        // Massachusetts small towns
        "springfield": CLLocationCoordinate2D(latitude: 42.1015, longitude: -72.5898),     // Springfield, MA (western Mass)
        "northampton": CLLocationCoordinate2D(latitude: 42.3251, longitude: -72.6412),     // Northampton, MA (college town)
        "amherst": CLLocationCoordinate2D(latitude: 42.3732, longitude: -72.5199),         // Amherst, MA (UMass)
        "salem": CLLocationCoordinate2D(latitude: 42.5195, longitude: -70.8967),           // Salem, MA (historic coastal)
        "concord": CLLocationCoordinate2D(latitude: 42.4604, longitude: -71.3489),         // Concord, MA (historic)
        "provincetown": CLLocationCoordinate2D(latitude: 42.0533, longitude: -70.1862),    // Provincetown, MA (Cape Cod tip)
        "greatbarrington": CLLocationCoordinate2D(latitude: 42.1959, longitude: -73.3621), // Great Barrington, MA (Berkshires)
        "stockbridge": CLLocationCoordinate2D(latitude: 42.3084, longitude: -73.3218),     // Stockbridge, MA (Berkshires)
        "lenox": CLLocationCoordinate2D(latitude: 42.3565, longitude: -73.2845),           // Lenox, MA (Berkshires)
        "williamstown": CLLocationCoordinate2D(latitude: 42.7126, longitude: -73.2037),    // Williamstown, MA (northwestern)
        "cambridge": CLLocationCoordinate2D(latitude: 42.3736, longitude: -71.1097),       // Cambridge, MA (Harvard/MIT)
        "somerville": CLLocationCoordinate2D(latitude: 42.3876, longitude: -71.0995),      // Somerville, MA (near Boston)
        "worcester": CLLocationCoordinate2D(latitude: 42.2626, longitude: -71.8023),       // Worcester, MA (central Mass)
        "newburyport": CLLocationCoordinate2D(latitude: 42.8126, longitude: -70.8773),     // Newburyport, MA (north shore)
        "plymouth": CLLocationCoordinate2D(latitude: 41.9584, longitude: -70.6673),        // Plymouth, MA (historic coastal)
        "beirut": CLLocationCoordinate2D(latitude: 33.8938, longitude: 35.5018)             // Beirut, Lebanon
    ]
    
    /// Fake location for testing (defaults to SF)
    static var fakeLocation = testCities["sf"]!
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Check current authorization status
        authorizationStatus = locationManager.authorizationStatus
        
        // If using fake location, set it immediately
        if Self.useFakeLocation {
            // Find which city this is for better logging
            let cityName = Self.testCities.first(where: { $0.value.latitude == Self.fakeLocation.latitude && $0.value.longitude == Self.fakeLocation.longitude })?.key ?? "custom"
            print("🧪 Using FAKE location: \(cityName.uppercased()) (\(Self.fakeLocation.latitude), \(Self.fakeLocation.longitude))")
            print("ℹ️  If you get 'No city found' errors, try a different test city from LocationManager.testCities")
            currentLocation = Self.fakeLocation
            authorizationStatus = .authorizedWhenInUse
        } else {
            // If already authorized, start updating location
            if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
                locationManager.startUpdatingLocation()
            } else if authorizationStatus == .notDetermined {
                // Request location permissions on init
                requestPermissions()
            }
        }
    }
    
    func requestPermissions() {
        locationManager.requestWhenInUseAuthorization()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            print("Location access denied")
        case .notDetermined:
            requestPermissions()
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Skip real location updates if using fake location
        if Self.useFakeLocation {
            return
        }
        
        guard let location = locations.last else { return }
        
        // Update current location
        currentLocation = location.coordinate
        
        // For onboarding, we want to get an accurate location, so keep updating for a bit
        // In production, you might want to stop after getting accurate enough location
        if let currentLoc = currentLocation, 
           location.horizontalAccuracy <= 100 { // Stop when we have decent accuracy
            locationManager.stopUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}

