import SwiftUI
import CoreLocation

/// Debug view for testing API connectivity and endpoints
struct APIDebugView: View {
    @ObservedObject private var api = KingdomAPIService.shared
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
                    
                    HStack {
                        Text("Authenticated:")
                        Spacer()
                        Text(api.isAuthenticated ? "Yes" : "No")
                            .foregroundColor(api.isAuthenticated ? .green : .orange)
                    }
                }
                
                // Test Actions
                Section("Test Actions") {
                    Button("Load Player State") {
                        Task {
                            do {
                                let state = try await api.player.loadState()
                                statusMessage = "✅ Loaded player: \(state.display_name) (Lvl \(state.level), \(state.gold)g)"
                            } catch {
                                statusMessage = "❌ Error: \(error.localizedDescription)"
                            }
                        }
                    }
                    
                    Button("List Kingdoms") {
                        Task {
                            do {
                                let kingdoms = try await api.kingdom.listKingdoms()
                                statusMessage = "✅ Found \(kingdoms.count) kingdoms"
                                print("Kingdoms:", kingdoms)
                            } catch {
                                statusMessage = "❌ Error: \(error.localizedDescription)"
                            }
                        }
                    }
                    
                    Button("Get My Kingdoms") {
                        Task {
                            do {
                                let kingdoms = try await api.kingdom.getMyKingdoms()
                                statusMessage = "✅ Ruling \(kingdoms.count) kingdoms"
                            } catch {
                                statusMessage = "❌ Error: \(error.localizedDescription)"
                            }
                        }
                    }
                    
                    Button("Fetch Nearby Cities") {
                        Task {
                            do {
                                let cities = try await api.city.fetchCities(
                                    lat: 37.7749,
                                    lon: -122.4194,
                                    radiusKm: 30
                                )
                                statusMessage = "✅ Found \(cities.count) cities"
                            } catch {
                                statusMessage = "❌ Error: \(error.localizedDescription)"
                            }
                        }
                    }
                    
                    Button("Get Leaderboard") {
                        Task {
                            do {
                                let leaderboard = try await api.kingdom.getLeaderboard()
                                statusMessage = "✅ Leaderboard: \(leaderboard.leaderboard.count) entries"
                            } catch {
                                statusMessage = "❌ Error: \(error.localizedDescription)"
                            }
                        }
                    }
                }
                
                Section("Simulators") {
                    NavigationLink("Battle Simulator") {
                        BattleSimulatorView()
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
                        if let url = URL(string: "\(AppConfig.apiBaseURL)/docs") {
                            UIApplication.shared.open(url)
                        }
                    }
                    
                    Text("Base URL: \(AppConfig.apiBaseURL)")
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

