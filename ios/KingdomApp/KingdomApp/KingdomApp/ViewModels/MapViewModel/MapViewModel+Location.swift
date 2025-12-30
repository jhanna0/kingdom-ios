import Foundation
import MapKit
import SwiftUI
import CoreLocation

// MARK: - Location & Kingdom Detection
extension MapViewModel {
    
    func updateUserLocation(_ location: CLLocationCoordinate2D) {
        userLocation = location
        
        // Check which kingdom user is inside (local detection)
        checkKingdomLocation(location)
        
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
    
    /// Check which kingdom the user is currently inside
    func checkKingdomLocation(_ location: CLLocationCoordinate2D) {
        let previousKingdom = currentKingdomInside
        
        // Find which kingdom contains the user's location
        currentKingdomInside = kingdoms.first { kingdom in
            kingdom.contains(location)
        }
        
        // Handle entering/leaving kingdoms
        if let current = currentKingdomInside, previousKingdom?.id != current.id {
            print("🏰 Entered \(current.name)")
            
            // AUTOMATIC CHECK-IN: Load player state with kingdom_id
            // Backend will auto-check us in and return updated state
            Task {
                do {
                    let updatedState = try await apiService.loadPlayerState(
                        kingdomId: current.id
                    )
                    
                    await MainActor.run {
                        // Update player from backend response (includes check-in rewards and ALL player data)
                        player.updateFromAPIState(updatedState)
                        player.currentKingdom = current.name
                        // Backend is source of truth - no local caching
                        
                        // Store travel event from backend
                        latestTravelEvent = updatedState.travel_event
                        
                        print("✅ Auto-checked in to \(current.name)")
                    }
                    
                    // Refresh this specific kingdom's data from backend
                    await refreshKingdom(id: current.id)
                } catch {
                    print("⚠️ Failed to auto check-in: \(error.localizedDescription)")
                }
            }
        } else if previousKingdom != nil && currentKingdomInside == nil {
            print("🚪 Left \(previousKingdom!.name)")
            player.currentKingdom = nil
            // Backend is source of truth - no local caching
        }
    }
    
    /// Adjust the map camera to show all loaded kingdoms
    func adjustMapToShowKingdoms() {
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


