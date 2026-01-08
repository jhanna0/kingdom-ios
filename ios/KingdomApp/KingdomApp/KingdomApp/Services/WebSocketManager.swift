import Foundation
import Combine

/// Manages WebSocket connection for real-time features (Town Pub chat)
class WebSocketManager: NSObject, ObservableObject {
    static let shared = WebSocketManager()
    
    @Published var isConnected = false
    @Published var messages: [ChatMessage] = []
    @Published var connectionError: String?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession!
    private var currentKingdomId: String?
    private var authToken: String?
    
    private override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
    }
    
    // MARK: - Connection
    
    /// Connect to a kingdom's chat room
    func connect(kingdomId: String, authToken: String) {
        // Disconnect from previous room if any
        if isConnected {
            disconnect()
        }
        
        self.currentKingdomId = kingdomId
        self.authToken = authToken
        
        // Build URL with kingdom_id query param
        guard var urlComponents = URLComponents(string: AppConfig.webSocketURL) else {
            connectionError = "Invalid WebSocket URL"
            return
        }
        urlComponents.queryItems = [
            URLQueryItem(name: "kingdom_id", value: kingdomId)
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
        
        print("🔌 WebSocket: Connecting to kingdom \(kingdomId)...")
    }
    
    /// Disconnect from current chat room
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        currentKingdomId = nil
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.messages = []
        }
        
        print("🔌 WebSocket: Disconnected")
    }
    
    // MARK: - Sending Messages
    
    /// Send a chat message to the current kingdom
    func sendMessage(_ text: String) {
        guard isConnected, let task = webSocketTask else {
            print("⚠️ WebSocket: Cannot send - not connected")
            return
        }
        
        let payload: [String: Any] = [
            "action": "sendMessage",
            "message": text
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: data, encoding: .utf8) else {
            print("⚠️ WebSocket: Failed to encode message")
            return
        }
        
        task.send(.string(jsonString)) { error in
            if let error = error {
                print("❌ WebSocket: Send error - \(error.localizedDescription)")
            }
        }
    }
    
    /// Switch to a different kingdom's chat
    func switchKingdom(_ kingdomId: String) {
        guard isConnected, let task = webSocketTask else { return }
        
        let payload: [String: Any] = [
            "action": "subscribe",
            "kingdom_id": kingdomId
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: data, encoding: .utf8) else { return }
        
        task.send(.string(jsonString)) { [weak self] error in
            if error == nil {
                DispatchQueue.main.async {
                    self?.currentKingdomId = kingdomId
                    self?.messages = []  // Clear messages from old kingdom
                }
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
                print("❌ WebSocket: Receive error - \(error.localizedDescription)")
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
        
        switch messageType {
        case "message":
            // Chat message received
            if let sender = json["sender"] as? [String: Any],
               let messageText = json["message"] as? String,
               let timestamp = json["timestamp"] as? Int {
                
                let displayName = sender["display_name"] as? String ?? "Unknown"
                let userId = sender["user_id"] as? String ?? ""
                
                let chatMessage = ChatMessage(
                    id: UUID(),
                    senderDisplayName: displayName,
                    senderUserId: userId,
                    message: messageText,
                    timestamp: Date(timeIntervalSince1970: Double(timestamp) / 1000)
                )
                
                DispatchQueue.main.async {
                    self.messages.append(chatMessage)
                    // Keep only last 100 messages
                    if self.messages.count > 100 {
                        self.messages.removeFirst()
                    }
                }
            }
            
        case "error":
            let errorMessage = json["message"] as? String ?? "Unknown error"
            print("❌ WebSocket: Server error - \(errorMessage)")
            DispatchQueue.main.async {
                self.connectionError = errorMessage
            }
            
        case "subscribed":
            print("✅ WebSocket: Subscribed to kingdom chat")
            
        default:
            print("📨 WebSocket: Received \(messageType)")
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension WebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ WebSocket: Connected!")
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionError = nil
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("🔌 WebSocket: Closed with code \(closeCode)")
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
}

// MARK: - Chat Message Model

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let senderDisplayName: String
    let senderUserId: String
    let message: String
    let timestamp: Date
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

