import Foundation
import Combine

/// Manages WebSocket connection for real-time hunt updates
/// Extends the base WebSocket system for hunt-specific events
class HuntWebSocketManager: NSObject, ObservableObject {
    static let shared = HuntWebSocketManager()
    
    @Published var isConnected = false
    @Published var currentHunt: HuntSession?
    @Published var lastPhaseResult: PhaseResultData?
    @Published var connectionError: String?
    
    // Events
    @Published var playerJoined: HuntParticipant?
    @Published var playerLeft: Int? // player_id
    @Published var playerReady: (playerId: Int, ready: Bool)?
    @Published var huntStarted = false
    @Published var phaseCompleted: HuntPhase?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession!
    private var currentHuntId: String?
    private var authToken: String?
    
    private override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
    }
    
    // MARK: - Connection
    
    /// Connect to a hunt session
    func connect(huntId: String, authToken: String) {
        // Disconnect from previous session if any
        if isConnected {
            disconnect()
        }
        
        self.currentHuntId = huntId
        self.authToken = authToken
        
        // Build URL with hunt_id query param
        guard var urlComponents = URLComponents(string: AppConfig.webSocketURL) else {
            connectionError = "Invalid WebSocket URL"
            return
        }
        urlComponents.queryItems = [
            URLQueryItem(name: "hunt_id", value: huntId)
        ]
        
        guard let url = urlComponents.url else {
            connectionError = "Failed to build WebSocket URL"
            return
        }
        
        // Create request with auth header
        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        // Create WebSocket task
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // Start listening for messages
        receiveMessage()
        
        print("🏹 Hunt WS: Connecting to hunt \(huntId)...")
    }
    
    /// Disconnect from current hunt session
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        currentHuntId = nil
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.currentHunt = nil
            self.lastPhaseResult = nil
        }
        
        print("🏹 Hunt WS: Disconnected")
    }
    
    // MARK: - Sending Messages
    
    /// Send a hunt action to the server
    func sendAction(_ action: String, data: [String: Any] = [:]) {
        guard isConnected, let task = webSocketTask else {
            print("⚠️ Hunt WS: Cannot send - not connected")
            return
        }
        
        var payload: [String: Any] = [
            "action": action,
            "hunt_id": currentHuntId ?? ""
        ]
        
        // Merge additional data
        for (key, value) in data {
            payload[key] = value
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("⚠️ Hunt WS: Failed to encode message")
            return
        }
        
        task.send(.string(jsonString)) { error in
            if let error = error {
                print("❌ Hunt WS: Send error - \(error.localizedDescription)")
            }
        }
    }
    
    /// Notify server that player is ready
    func sendReady(_ ready: Bool) {
        sendAction("ready", data: ["ready": ready])
    }
    
    /// Request to start the hunt (leader only)
    func sendStart() {
        sendAction("start")
    }
    
    /// Request to execute next phase
    func sendExecutePhase(_ phase: HuntPhase) {
        sendAction("execute_phase", data: ["phase": phase.rawValue])
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
                print("❌ Hunt WS: Receive error - \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.isConnected = false
                    self?.connectionError = error.localizedDescription
                }
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
        case "hunt_update":
            // Full hunt state update
            if let huntData = json["hunt"] as? [String: Any],
               let jsonData = try? JSONSerialization.data(withJSONObject: huntData),
               let hunt = try? JSONDecoder().decode(HuntSession.self, from: jsonData) {
                currentHunt = hunt
            }
            
        case "player_joined":
            if let playerData = json["player"] as? [String: Any],
               let jsonData = try? JSONSerialization.data(withJSONObject: playerData),
               let player = try? JSONDecoder().decode(HuntParticipant.self, from: jsonData) {
                playerJoined = player
            }
            
        case "player_left":
            if let playerId = json["player_id"] as? Int {
                playerLeft = playerId
            }
            
        case "player_ready":
            if let playerId = json["player_id"] as? Int,
               let ready = json["ready"] as? Bool {
                playerReady = (playerId, ready)
            }
            
        case "hunt_started":
            huntStarted = true
            if let huntData = json["hunt"] as? [String: Any],
               let jsonData = try? JSONSerialization.data(withJSONObject: huntData),
               let hunt = try? JSONDecoder().decode(HuntSession.self, from: jsonData) {
                currentHunt = hunt
            }
            
        case "phase_result":
            if let resultData = json["result"] as? [String: Any],
               let jsonData = try? JSONSerialization.data(withJSONObject: resultData),
               let result = try? JSONDecoder().decode(PhaseResultData.self, from: jsonData) {
                lastPhaseResult = result
            }
            if let phaseStr = json["phase"] as? String,
               let phase = HuntPhase(rawValue: phaseStr) {
                phaseCompleted = phase
            }
            
        case "hunt_complete":
            if let huntData = json["hunt"] as? [String: Any],
               let jsonData = try? JSONSerialization.data(withJSONObject: huntData),
               let hunt = try? JSONDecoder().decode(HuntSession.self, from: jsonData) {
                currentHunt = hunt
            }
            
        case "error":
            let errorMessage = json["message"] as? String ?? "Unknown error"
            print("❌ Hunt WS: Server error - \(errorMessage)")
            connectionError = errorMessage
            
        default:
            print("📨 Hunt WS: Received \(type)")
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension HuntWebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ Hunt WS: Connected!")
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionError = nil
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("🏹 Hunt WS: Closed with code \(closeCode)")
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
}

