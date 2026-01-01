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
    
    /// Fake location for testing (Apple Park, Cupertino, CA)
    static var fakeLocation = CLLocationCoordinate2D(
        latitude: 37.3349,  // Apple Park
        longitude: -122.0090
    )
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Check current authorization status
        authorizationStatus = locationManager.authorizationStatus
        
        // If using fake location, set it immediately
        if Self.useFakeLocation {
            print("🧪 Using FAKE location: Apple Park, Cupertino, CA (\(Self.fakeLocation.latitude), \(Self.fakeLocation.longitude))")
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

