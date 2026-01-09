import SwiftUI

/// Town Pub - Real-time chat for kingdom citizens
struct TownPubView: View {
    let kingdomId: String
    let kingdomName: String
    
    @StateObject private var webSocket = WebSocketManager.shared
    @EnvironmentObject var authManager: AuthManager
    
    @State private var messageText = ""
    @State private var isConnecting = true
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Connection status bar
            connectionStatusBar
            
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if webSocket.messages.isEmpty && webSocket.isConnected {
                            emptyStateView
                        } else {
                            ForEach(webSocket.messages) { message in
                                ChatBubble(
                                    message: message,
                                    isOwnMessage: isOwnMessage(message)
                                )
                                .id(message.id)
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: webSocket.messages.count) { _ in
                    // Scroll to bottom on new message
                    if let lastMessage = webSocket.messages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input bar
            messageInputBar
        }
        .background(KingdomTheme.Colors.parchment)
        .navigationTitle("Town Pub")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .onAppear {
            connectToChat()
        }
        .onDisappear {
            webSocket.disconnect()
        }
    }
    
    // MARK: - Connection Status Bar
    
    private var connectionStatusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(webSocket.isConnected ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            
            if webSocket.isConnected {
                Text("\(kingdomName) Pub")
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            } else if let error = webSocket.connectionError {
                Text(error)
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
                    .lineLimit(1)
            } else {
                Text("Connecting...")
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            }
            
            Spacer()
            
            if !webSocket.isConnected {
                Button {
                    connectToChat()
                } label: {
                    Text("Retry")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.royalBlue)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(KingdomTheme.Colors.parchmentLight)
        .overlay(
            Rectangle()
                .fill(KingdomTheme.Colors.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(KingdomTheme.Colors.inkLight)
            
            Text("The pub is quiet...")
                .font(FontStyles.headingMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            Text("Be the first to start a conversation!")
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkLight)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 60)
    }
    
    // MARK: - Message Input Bar
    
    private var messageInputBar: some View {
        HStack(spacing: 12) {
            TextField("Say something...", text: $messageText)
                .textFieldStyle(.plain)
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .padding(12)
                .background(KingdomTheme.Colors.parchmentLight)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(KingdomTheme.Colors.border, lineWidth: 2)
                )
                .focused($isInputFocused)
                .submitLabel(.send)
                .onSubmit {
                    sendMessage()
                }
                .tint(KingdomTheme.Colors.inkMedium)
            
            Button {
                sendMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        messageText.isEmpty || !webSocket.isConnected
                            ? KingdomTheme.Colors.disabled
                            : KingdomTheme.Colors.royalBlue
                    )
                    .cornerRadius(22)
            }
            .disabled(messageText.isEmpty || !webSocket.isConnected)
        }
        .padding()
        .background(KingdomTheme.Colors.parchmentDark)
        .overlay(
            Rectangle()
                .fill(KingdomTheme.Colors.border)
                .frame(height: 2),
            alignment: .top
        )
    }
    
    // MARK: - Actions
    
    private func connectToChat() {
        guard let token = authManager.authToken else {
            webSocket.connectionError = "Not authenticated"
            return
        }
        webSocket.connect(kingdomId: kingdomId, authToken: token)
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        webSocket.sendMessage(text)
        messageText = ""
    }
    
    private func isOwnMessage(_ message: ChatMessage) -> Bool {
        // Compare with current user's display name
        guard let currentUser = authManager.currentUser else { return false }
        return message.senderDisplayName == currentUser.display_name
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage
    let isOwnMessage: Bool
    
    var body: some View {
        HStack {
            if isOwnMessage { Spacer(minLength: 60) }
            
            VStack(alignment: isOwnMessage ? .trailing : .leading, spacing: 4) {
                if !isOwnMessage {
                    Text(message.senderDisplayName)
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.royalBlue)
                        .fontWeight(.semibold)
                }
                
                Text(message.message)
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(isOwnMessage ? .white : KingdomTheme.Colors.inkMedium)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isOwnMessage
                            ? KingdomTheme.Colors.royalBlue
                            : KingdomTheme.Colors.parchmentLight
                    )
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                isOwnMessage ? Color.clear : KingdomTheme.Colors.border,
                                lineWidth: 1.5
                            )
                    )
                
                Text(message.formattedTime)
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            }
            
            if !isOwnMessage { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TownPubView(kingdomId: "test-123", kingdomName: "Test Kingdom")
            .environmentObject(AuthManager())
    }
}

