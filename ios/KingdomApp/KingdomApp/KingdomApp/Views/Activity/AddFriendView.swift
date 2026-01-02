import SwiftUI

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchQuery = ""
    @State private var searchResults: [UserSearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    let onAdded: () -> Void
    private let api = KingdomAPIService.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                KingdomTheme.Colors.parchment
                    .ignoresSafeArea()
                
                VStack(spacing: KingdomTheme.Spacing.medium) {
                    // Search bar with brutalist style
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        TextField("Search by username...", text: $searchQuery)
                            .font(FontStyles.bodyMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .onSubmit {
                                Task {
                                    await searchUsers()
                                }
                            }
                        
                        if !searchQuery.isEmpty {
                            Button(action: {
                                searchQuery = ""
                                searchResults = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(FontStyles.iconSmall)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                            }
                        }
                    }
                    .padding()
                    .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
                    .padding(.horizontal)
                    .padding(.top, KingdomTheme.Spacing.small)
                    
                    // Success message
                    if let message = successMessage {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(FontStyles.iconSmall)
                                .foregroundColor(.white)
                            Text(message)
                                .font(FontStyles.labelBold)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSuccess, cornerRadius: 8)
                        .padding(.horizontal)
                    }
                    
                    // Search results
                    if isSearching {
                        ProgressView()
                            .padding()
                    } else if searchResults.isEmpty && !searchQuery.isEmpty {
                        VStack(spacing: KingdomTheme.Spacing.medium) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(FontStyles.iconExtraLarge)
                                .foregroundColor(.white)
                                .frame(width: 70, height: 70)
                                .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 20)
                            
                            Text("No players found")
                                .font(FontStyles.bodyMedium)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                            
                            Text("Try searching for a different username")
                                .font(FontStyles.labelMedium)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)
                    } else if !searchResults.isEmpty {
                        ScrollView {
                            VStack(spacing: KingdomTheme.Spacing.small) {
                                ForEach(searchResults) { user in
                                    UserSearchResultCard(
                                        user: user,
                                        onAdd: {
                                            await addFriend(user)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        // Instructions
                        VStack(spacing: KingdomTheme.Spacing.large) {
                            Image(systemName: "person.badge.plus")
                                .font(FontStyles.iconExtraLarge)
                                .foregroundColor(.white)
                                .frame(width: 80, height: 80)
                                .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 20)
                            
                            Text("Add Friends")
                                .font(FontStyles.headingLarge)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Text("Search for players by username to send them a friend request")
                                .font(FontStyles.bodyMedium)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, KingdomTheme.Spacing.xxLarge)
                        }
                        .padding(.top, 60)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(KingdomTheme.Typography.headline())
                    .fontWeight(.semibold)
                    .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    private func searchUsers() async {
        guard searchQuery.count >= 2 else { return }
        
        isSearching = true
        successMessage = nil
        defer { isSearching = false }
        
        do {
            let response = try await api.friends.searchUsers(query: searchQuery)
            searchResults = response.users
            print("✅ Found \(searchResults.count) users")
        } catch {
            print("❌ Search failed: \(error)")
            errorMessage = "Failed to search users"
        }
    }
    
    private func addFriend(_ user: UserSearchResult) async {
        do {
            let response = try await api.friends.addFriend(userId: user.id)
            print("✅ \(response.message)")
            successMessage = response.message
            
            // Refresh search to update friendship status
            await searchUsers()
            
            // Notify parent
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onAdded()
            }
        } catch {
            print("❌ Failed to add friend: \(error)")
            if let apiError = error as? APIError {
                switch apiError {
                case .serverError(let message):
                    errorMessage = message
                default:
                    errorMessage = "Failed to add friend"
                }
            } else {
                errorMessage = "Failed to add friend"
            }
        }
    }
}

// MARK: - User Search Result Card

struct UserSearchResultCard: View {
    let user: UserSearchResult
    let onAdd: () async -> Void
    
    @State private var isAdding = false
    
    var body: some View {
        HStack(spacing: 12) {
            Text(String(user.displayName.prefix(1)).uppercased())
                .font(FontStyles.headingSmall)
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                HStack(spacing: 4) {
                    Text("@\(user.username)")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Text("•")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                    
                    Text("Lv\(user.level)")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            
            Spacer()
            
            // Add button based on friendship status
            if let status = user.friendshipStatus {
                if status == "accepted" {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                        Text("Friends")
                            .font(FontStyles.labelBold)
                            .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                    }
                } else if status == "pending" {
                    Text("Pending")
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            } else {
                Button(action: {
                    isAdding = true
                    Task {
                        await onAdd()
                        isAdding = false
                    }
                }) {
                    if isAdding {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(FontStyles.iconMedium)
                            .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                    }
                }
                .disabled(isAdding)
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
    }
}

// MARK: - Preview

#Preview {
    AddFriendView(onAdded: {})
}

