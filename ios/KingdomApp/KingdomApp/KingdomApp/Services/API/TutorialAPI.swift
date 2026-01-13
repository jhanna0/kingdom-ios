import Foundation

// MARK: - Tutorial API

class TutorialAPI {
    private let client = APIClient.shared
    
    /// Get all tutorial sections
    func getTutorial() async throws -> TutorialResponse {
        let request = client.request(endpoint: "/tutorial", method: "GET")
        return try await client.execute(request)
    }
    
    /// Get a specific tutorial section
    func getSection(id: String) async throws -> TutorialSection {
        let request = client.request(endpoint: "/tutorial/section/\(id)", method: "GET")
        return try await client.execute(request)
    }
}

// MARK: - Tutorial Models

struct TutorialResponse: Codable {
    let version: String
    let sections: [TutorialSection]
}

struct TutorialSection: Codable, Identifiable {
    let id: String
    let title: String
    let icon: String
    let content: String
    let order: Int
}
