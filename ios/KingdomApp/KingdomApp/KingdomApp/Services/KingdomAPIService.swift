import Foundation
import CoreLocation
import Combine

/// Kingdom API Service - Facade for all API operations
/// Delegates to specialized API classes for cleaner organization
///
/// Usage:
///   - `KingdomAPIService.shared.player` for player state operations
///   - `KingdomAPIService.shared.kingdom` for kingdom operations
///   - `KingdomAPIService.shared.city` for city boundary operations
///   - `KingdomAPIService.shared.contract` for contract operations
class KingdomAPIService: ObservableObject {
    // MARK: - Singleton
    static let shared = KingdomAPIService()
    
    // MARK: - API Clients
    let player = PlayerAPI()
    let kingdom = KingdomAPI()
    let city = CityAPI()
    let contract = ContractAPI()
    
    // MARK: - Shared Client
    private let client = APIClient.shared
    
    // MARK: - Published State (forwarded from APIClient)
    @Published var isConnected: Bool = false
    @Published var lastError: String?
    
    var isAuthenticated: Bool {
        return client.isAuthenticated
    }
    
    var authToken: String? {
        get { client.authToken }
        set { client.authToken = newValue }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Forward state from APIClient
        client.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: &$isConnected)
        
        client.$lastError
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastError)
        
        // Test connection on init
        Task {
            await testConnection()
        }
    }
    
    // MARK: - Health Check
    
    func testConnection() async -> Bool {
        return await client.testConnection()
    }
    
    // MARK: - Auth
    
    func setAuthToken(_ token: String) {
        client.setAuthToken(token)
    }
    
    func clearAuth() {
        client.clearAuth()
    }
    
    // MARK: - Convenience Methods
    
    /// Fetch cities and convert to Kingdom objects
    func fetchCities(lat: Double, lon: Double, radiusKm: Double = 30.0) async throws -> [Kingdom] {
        return try await city.fetchCitiesAsKingdoms(lat: lat, lon: lon, radiusKm: radiusKm)
    }
    
    /// Sync player state
    func syncPlayer(_ player: Player) async throws {
        let response = try await self.player.syncState(player.toAPIState())
        
        await MainActor.run {
            player.updateFromAPIState(response.player_state)
        }
    }
    
    /// Load player state from server
    func loadPlayerState() async throws -> APIPlayerState {
        return try await player.loadState()
    }
    
    /// Check in to a kingdom
    func checkIn(kingdomId: String, location: CLLocationCoordinate2D) async throws -> CheckInResponse {
        return try await kingdom.checkIn(kingdomId: kingdomId, location: location)
    }
}

// MARK: - Legacy Compatibility

extension KingdomAPIService {
    /// Legacy player state models (now in PlayerModels.swift)
    typealias APIPlayerState = Services.API.Models.APIPlayerState
    typealias SyncResponse = PlayerSyncResponse
}

// Re-export models for backwards compatibility
enum Services {
    enum API {
        enum Models {
            typealias APIPlayerState = KingdomApp.APIPlayerState
        }
    }
}
