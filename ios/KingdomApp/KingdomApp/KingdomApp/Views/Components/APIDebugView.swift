import SwiftUI
import CoreLocation

/// Debug view for testing API connectivity and endpoints
struct APIDebugView: View {
    @StateObject private var api = KingdomAPIService()
    @State private var statusMessage: String = "Not tested"
    @State private var showingDetails = false
    
    var body: some View {
        NavigationView {
            List {
                // Connection Status
                Section("Connection Status") {
                    HStack {
                        Circle()
                            .fill(api.isConnected ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                        
                        Text(api.isConnected ? "Connected" : "Disconnected")
                            .foregroundColor(api.isConnected ? .green : .red)
                        
                        Spacer()
                        
                        Button("Test") {
                            Task {
                                await api.testConnection()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    if let error = api.lastError {
                        Text("Error: \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Test Actions
                Section("Test Actions") {
                    Button("Create Test Player") {
                        Task {
                            do {
                                let player = try await api.createPlayer(
                                    id: UUID().uuidString,
                                    name: "Test Player \(Int.random(in: 1...999))",
                                    gold: 100,
                                    level: 1
                                )
                                statusMessage = "✅ Created player: \(player.name)"
                            } catch {
                                statusMessage = "❌ Error: \(error.localizedDescription)"
                            }
                        }
                    }
                    
                    Button("List All Players") {
                        Task {
                            do {
                                let players = try await api.listPlayers()
                                statusMessage = "✅ Found \(players.count) players"
                                print("Players:", players)
                            } catch {
                                statusMessage = "❌ Error: \(error.localizedDescription)"
                            }
                        }
                    }
                    
                    Button("Create Test Kingdom") {
                        Task {
                            do {
                                let kingdom = try await api.createKingdom(
                                    id: UUID().uuidString,
                                    name: "Test Kingdom",
                                    rulerId: "test-ruler",
                                    location: .init(latitude: 37.7749, longitude: -122.4194)
                                )
                                statusMessage = "✅ Created kingdom: \(kingdom.name)"
                            } catch {
                                statusMessage = "❌ Error: \(error.localizedDescription)"
                            }
                        }
                    }
                    
                    Button("List All Kingdoms") {
                        Task {
                            do {
                                let kingdoms = try await api.listKingdoms()
                                statusMessage = "✅ Found \(kingdoms.count) kingdoms"
                                print("Kingdoms:", kingdoms)
                            } catch {
                                statusMessage = "❌ Error: \(error.localizedDescription)"
                            }
                        }
                    }
                }
                
                // Status Message
                Section("Last Result") {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // API Info
                Section("API Info") {
                    Button("View API Docs in Browser") {
                        if let url = URL(string: "http://192.168.1.13:8000/docs") {
                            UIApplication.shared.open(url)
                        }
                    }
                    
                    Text("Base URL: http://192.168.1.13:8000")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("API Debug")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    APIDebugView()
}

