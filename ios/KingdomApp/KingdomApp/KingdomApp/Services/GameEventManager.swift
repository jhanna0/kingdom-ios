import Foundation
import Combine
import UIKit

/// Event types for duels (matches API's DuelEvents)
/// Real-time swing events allow opponent to see each swing as it happens
enum DuelEventType: String {
    case invitation = "duel_invitation"
    case opponentJoined = "duel_opponent_joined"
    case started = "duel_started"
    case swing = "duel_swing"  // Real-time: each swing broadcast immediately
    case turnComplete = "duel_turn_complete"  // Turn finished, bar pushed
    case ended = "duel_ended"
    case cancelled = "duel_cancelled"
    case timeout = "duel_timeout"  // Player timed out
}

/// A duel event received via WebSocket
struct DuelEvent {
    let eventType: DuelEventType
    let matchId: Int?
    let match: DuelMatch?
    let data: [String: Any]
    let timestamp: Date
}

/// Manages WebSocket connection for real-time game events (duels, trades, etc.)
/// This is separate from chat WebSocket - it's for user-specific notifications
class GameEventManager: NSObject, ObservableObject {
    static let shared = GameEventManager()
    
    // MARK: - Connection State
    @Published var isConnected = false
    @Published var connectionError: String?
    
    // MARK: - Duel Events
    /// Publisher for duel events - subscribe to receive real-time updates
    let duelEventSubject = PassthroughSubject<DuelEvent, Never>()
    
    /// Last received duel event (for SwiftUI observation)
    @Published var lastDuelEvent: DuelEvent?
    
    // MARK: - Private State
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession!
    private var authToken: String?
    private var reconnectAttempts = 0
    private var maxReconnectAttempts = 5
    private var reconnectDelay: TimeInterval = 2.0
    private var pingTimer: Timer?
    
    private override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        
        // Listen for app lifecycle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        disconnect()
    }
    
    // MARK: - Connection
    
    /// Connect to the game events WebSocket
    func connect(authToken: String) {
        // Store token for reconnects
        self.authToken = authToken
        
        // Don't reconnect if already connected
        if isConnected {
            return
        }
        
        guard var urlComponents = URLComponents(string: AppConfig.webSocketURL) else {
            connectionError = "Invalid WebSocket URL"
            return
        }
        
        // Add token as query param (the API expects this)
        urlComponents.queryItems = [
            URLQueryItem(name: "token", value: authToken)
        ]
        
        guard let url = urlComponents.url else {
            connectionError = "Failed to build WebSocket URL"
            return
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        // Create WebSocket task
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // Start listening for messages
        receiveMessage()
        
        print("🎮 Game Events WS: Connecting...")
    }
    
    /// Disconnect from WebSocket
    func disconnect() {
        stopPingTimer()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        DispatchQueue.main.async {
            self.isConnected = false
        }
        
        print("🎮 Game Events WS: Disconnected")
    }
    
    /// Reconnect with exponential backoff
    private func attemptReconnect() {
        guard reconnectAttempts < maxReconnectAttempts,
              let token = authToken else {
            return
        }
        
        reconnectAttempts += 1
        let delay = reconnectDelay * pow(2.0, Double(reconnectAttempts - 1))
        
        print("🎮 Game Events WS: Reconnecting in \(delay)s (attempt \(reconnectAttempts)/\(maxReconnectAttempts))")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.connect(authToken: token)
        }
    }
    
    // MARK: - App Lifecycle
    
    @objc private func appWillEnterForeground() {
        if let token = authToken, !isConnected {
            reconnectAttempts = 0
            connect(authToken: token)
        }
    }
    
    @objc private func appDidEnterBackground() {
        // Keep connection alive in background briefly, but stop ping
        stopPingTimer()
    }
    
    // MARK: - Ping/Pong for Connection Health
    
    private func startPingTimer() {
        stopPingTimer()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }
    
    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
    
    private func sendPing() {
        guard isConnected, let task = webSocketTask else { return }
        
        let payload = ["action": "ping"]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: data, encoding: .utf8) else { return }
        
        task.send(.string(jsonString)) { error in
            if let error = error {
                print("🎮 Game Events WS: Ping failed - \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Receiving Messages
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                
                // Continue listening
                self?.receiveMessage()
                
            case .failure(let error):
                print("❌ Game Events WS: Receive error - \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.isConnected = false
                    self?.connectionError = error.localizedDescription
                }
                // Attempt reconnect
                self?.attemptReconnect()
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        let messageType = json["type"] as? String ?? ""
        
        DispatchQueue.main.async { [weak self] in
            self?.processMessage(type: messageType, json: json)
        }
    }
    
    private func processMessage(type: String, json: [String: Any]) {
        switch type {
        case "connected":
            // Welcome message from server
            print("🎮 Game Events WS: Connected and authenticated")
            
        case "pong":
            // Ping response - connection is healthy
            break
            
        case "duel_event":
            processDuelEvent(json)
            
        case "notification":
            // Generic notification (could be trade, friend request, etc.)
            let eventType = json["event_type"] as? String ?? ""
            print("🎮 Game Events WS: Notification - \(eventType)")
            // TODO: Handle other notification types (trades, etc.)
            
        case "error":
            let errorMessage = json["message"] as? String ?? "Unknown error"
            print("❌ Game Events WS: Server error - \(errorMessage)")
            connectionError = errorMessage
            
        default:
            print("🎮 Game Events WS: Received \(type)")
        }
    }
    
    // MARK: - Duel Event Processing
    
    private func processDuelEvent(_ json: [String: Any]) {
        guard let eventTypeString = json["event_type"] as? String,
              let eventType = DuelEventType(rawValue: eventTypeString) else {
            return
        }
        
        let matchId = json["match_id"] as? Int
        let eventData = json["data"] as? [String: Any] ?? [:]
        let timestamp = Date(timeIntervalSince1970: Double(json["timestamp"] as? Int ?? 0) / 1000.0)
        
        var match: DuelMatch?
        if let matchDict = json["match"] as? [String: Any],
           let matchData = try? JSONSerialization.data(withJSONObject: matchDict) {
            match = try? JSONDecoder().decode(DuelMatch.self, from: matchData)
        }
        
        let event = DuelEvent(
            eventType: eventType,
            matchId: matchId,
            match: match,
            data: eventData,
            timestamp: timestamp
        )
        
        lastDuelEvent = event
        duelEventSubject.send(event)
    }
}

// MARK: - URLSessionWebSocketDelegate

extension GameEventManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ Game Events WS: Connected!")
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionError = nil
            self.reconnectAttempts = 0
        }
        startPingTimer()
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("🎮 Game Events WS: Closed with code \(closeCode)")
        DispatchQueue.main.async {
            self.isConnected = false
        }
        stopPingTimer()
        
        // Attempt reconnect unless it was a clean close
        if closeCode != .normalClosure {
            attemptReconnect()
        }
    }
}
