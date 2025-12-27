import Foundation
import MapKit
import SwiftUI
import Combine
import CoreLocation

@MainActor
class MapViewModel: ObservableObject {
    @Published var kingdoms: [Kingdom] = []
    @Published var cameraPosition: MapCameraPosition
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var isLoading: Bool = false
    @Published var loadingStatus: String = "Waiting for location..."
    @Published var errorMessage: String?
    
    private var hasInitializedLocation = false
    
    init() {
        // Start with default location - will be replaced when user location arrives
        let center = SampleData.defaultCenter
        self.cameraPosition = .region(
            MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
            )
        )
        
        // NO FAKE DATA - wait for real location and real data
        print("📱 MapViewModel initialized - waiting for user location")
    }
    
    func updateUserLocation(_ location: CLLocationCoordinate2D) {
        userLocation = location
        print("📍 User location: \(location.latitude), \(location.longitude)")
        
        // Only initialize once
        if !hasInitializedLocation {
            hasInitializedLocation = true
            print("🎯 First location received - loading REAL town data")
            
            // Center map on user's location with appropriate zoom for town view
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: location,
                    span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
                )
            )
            
            // Load REAL towns
            loadRealTowns(around: location)
        }
    }
    
    /// Load real town data - NO FALLBACKS
    func loadRealTowns(around location: CLLocationCoordinate2D) {
        guard !isLoading else { return }
        
        isLoading = true
        loadingStatus = "Finding towns near you..."
        errorMessage = nil
        
        Task {
            print("🔄 Loading real town boundaries...")
            loadingStatus = "Querying OpenStreetMap..."
            
            let foundKingdoms = await SampleData.loadRealTowns(around: location)
            
            if foundKingdoms.isEmpty {
                loadingStatus = "No towns found"
                errorMessage = "Could not load town boundaries. Please check your internet connection and try again."
                print("❌ No real towns found!")
            } else {
                loadingStatus = "Loaded \(foundKingdoms.count) towns"
                errorMessage = nil
                kingdoms = foundKingdoms
                print("✅ Loaded \(foundKingdoms.count) REAL towns with REAL boundaries")
                
                // Adjust map to show all kingdoms
                adjustMapToShowKingdoms()
            }
            
            isLoading = false
        }
    }
    
    /// Refresh kingdoms - try again with real data
    func refreshKingdoms() {
        if let location = userLocation {
            loadRealTowns(around: location)
        } else {
            errorMessage = "Location not available. Please enable location services."
        }
    }
    
    /// Adjust the map camera to show all loaded kingdoms
    private func adjustMapToShowKingdoms() {
        guard !kingdoms.isEmpty else { return }
        
        // Calculate bounding box of all kingdoms
        var minLat = Double.greatestFiniteMagnitude
        var maxLat = -Double.greatestFiniteMagnitude
        var minLon = Double.greatestFiniteMagnitude
        var maxLon = -Double.greatestFiniteMagnitude
        
        for kingdom in kingdoms {
            for coord in kingdom.territory.boundary {
                minLat = min(minLat, coord.latitude)
                maxLat = max(maxLat, coord.latitude)
                minLon = min(minLon, coord.longitude)
                maxLon = max(maxLon, coord.longitude)
            }
        }
        
        // Add padding
        let padding = 0.02
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) + padding,
            longitudeDelta: (maxLon - minLon) + padding
        )
        
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }
}
