//
//  ServerPrompt.swift
//  KingdomApp
//
//  Server-driven prompt - backend controls everything via a URL
//

import Foundation

/// Server prompt config - backend tells us what URL to show
struct ServerPrompt: Codable, Identifiable, Equatable {
    let id: String
    let modalUrl: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case modalUrl = "modal_url"
    }
    
    var isEmpty: Bool { id.isEmpty || modalUrl.isEmpty }
    
    /// Full URL - prepends base URL if relative path
    var fullURL: URL? {
        if modalUrl.hasPrefix("http") {
            return URL(string: modalUrl)
        } else {
            return URL(string: AppConfig.apiBaseURL + modalUrl)
        }
    }
    
    static func == (lhs: ServerPrompt, rhs: ServerPrompt) -> Bool {
        lhs.id == rhs.id
    }
}

/// API response for checking prompts
struct ServerPromptCheckResponse: Codable {
    let success: Bool
    let prompt: ServerPrompt?
}
