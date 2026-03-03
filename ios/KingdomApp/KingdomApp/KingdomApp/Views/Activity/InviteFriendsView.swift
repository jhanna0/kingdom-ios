import SwiftUI
import ContactsUI
import MessageUI
import Combine

struct InviteFriendsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = InviteFriendsViewModel()
    @State private var showingShareSheet = false
    @State private var showingContactPicker = false
    @State private var showingMessageComposer = false
    @State private var selectedContacts: [ContactInfo] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                KingdomTheme.Colors.parchment
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: KingdomTheme.Spacing.large) {
                        headerSection
                        quickShareSection
                        contactsSection
                        
                        if !selectedContacts.isEmpty {
                            selectedContactsSection
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Invite Friends")
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
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: [viewModel.shareMessage])
            }
            .sheet(isPresented: $showingContactPicker) {
                ContactPickerWrapper(selectedContacts: $selectedContacts)
            }
            .sheet(isPresented: $showingMessageComposer) {
                if MFMessageComposeViewController.canSendText() {
                    MessageComposerView(
                        recipients: selectedContacts.compactMap { $0.phoneNumber },
                        body: viewModel.shareMessage
                    ) { result in
                        showingMessageComposer = false
                        if result == .sent {
                            selectedContacts.removeAll()
                        }
                    }
                }
            }
            .alert("Cannot Send Messages", isPresented: $viewModel.showMessageError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This device is not configured to send text messages.")
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 48))
                .foregroundColor(KingdomTheme.Colors.buttonPrimary)
            
            Text("Spread the Word")
                .font(FontStyles.displayMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("Invite your friends to join your Kingdom and build your empire together!")
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, KingdomTheme.Spacing.medium)
    }
    
    // MARK: - Quick Share Section
    
    private var quickShareSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            Text("Quick Share")
                .font(FontStyles.headingLarge)
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .padding(.horizontal)
            
            Button {
                showingShareSheet = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.up")
                        .font(FontStyles.iconMedium)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Share via...")
                            .font(FontStyles.bodyMediumBold)
                        Text("Messages, Socials & more")
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(FontStyles.iconSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, minHeight: 60)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            
            // Copy Link Button
            Button {
                UIPasteboard.general.string = viewModel.appStoreURL.absoluteString
                viewModel.showCopiedFeedback = true
                HapticService.shared.notification(.success)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    viewModel.showCopiedFeedback = false
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Image(systemName: "link")
                            .opacity(viewModel.showCopiedFeedback ? 0 : 1)
                        Image(systemName: "checkmark")
                            .opacity(viewModel.showCopiedFeedback ? 1 : 0)
                    }
                    .font(FontStyles.iconMedium)
                    .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Copy Invite Link")
                            .font(FontStyles.bodyMediumBold)
                        Text(viewModel.showCopiedFeedback ? "Copied to clipboard!" : "Tap to copy App Store link")
                            .font(FontStyles.labelSmall)
                            .foregroundColor(viewModel.showCopiedFeedback ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.inkMedium)
                    }
                    
                    Spacer()
                }
                .foregroundColor(viewModel.showCopiedFeedback ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.inkDark)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, minHeight: 60)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
                .animation(.easeInOut(duration: 0.2), value: viewModel.showCopiedFeedback)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Contacts Section
    
    private var contactsSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
                .padding(.horizontal)
            
            Text("Invite from Contacts")
                .font(FontStyles.headingLarge)
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .padding(.horizontal)
            
            Button {
                showingContactPicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(FontStyles.iconMedium)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Choose Contacts")
                            .font(FontStyles.bodyMediumBold)
                        Text("Select friends to invite via text message")
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(FontStyles.iconSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, minHeight: 60)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Selected Contacts Section
    
    private var selectedContactsSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
                .padding(.horizontal)
            
            HStack {
                Text("Selected")
                    .font(FontStyles.headingLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("\(selectedContacts.count)")
                    .font(FontStyles.labelBold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonPrimary, cornerRadius: 10, shadowOffset: 1, borderWidth: 1.5)
                
                Spacer()
                
                Button("Clear") {
                    selectedContacts.removeAll()
                }
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.buttonWarning)
            }
            .padding(.horizontal)
            
            FlowLayout(spacing: 8) {
                ForEach(selectedContacts) { contact in
                    ContactChip(contact: contact) {
                        selectedContacts.removeAll { $0.id == contact.id }
                    }
                }
            }
            .padding(.horizontal)
            
            Button {
                if MFMessageComposeViewController.canSendText() {
                    showingMessageComposer = true
                } else {
                    viewModel.showMessageError = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                        .font(FontStyles.iconSmall)
                    Text("Send Invites")
                        .font(FontStyles.bodyMediumBold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.buttonPrimary,
                    cornerRadius: 10,
                    shadowOffset: 3,
                    borderWidth: 2
                )
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - View Model

@MainActor
class InviteFriendsViewModel: ObservableObject {
    @Published var showCopiedFeedback = false
    @Published var showMessageError = false
    
    let appStoreURL = URL(string: "https://apps.apple.com/us/app/kingdom-territory/id6757280025")!
    
    var shareMessage: String {
        "Join my Kingdom! Build your empire, trade with friends, and conquer territories. \(appStoreURL.absoluteString)"
    }
}

// MARK: - Contact Info Model

struct ContactInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let phoneNumber: String?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ContactInfo, rhs: ContactInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Contact Chip

struct ContactChip: View {
    let contact: ContactInfo
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(contact.name)
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 16, shadowOffset: 1, borderWidth: 1)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Contact Picker Wrapper

struct ContactPickerWrapper: UIViewControllerRepresentable {
    @Binding var selectedContacts: [ContactInfo]
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(selectedContacts: $selectedContacts)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        @Binding var selectedContacts: [ContactInfo]
        
        init(selectedContacts: Binding<[ContactInfo]>) {
            _selectedContacts = selectedContacts
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            let newContacts = contacts.compactMap { contact -> ContactInfo? in
                let name = CNContactFormatter.string(from: contact, style: .fullName) ?? "Unknown"
                let phone = contact.phoneNumbers.first?.value.stringValue
                return ContactInfo(name: name, phoneNumber: phone)
            }
            
            for contact in newContacts {
                if !selectedContacts.contains(where: { $0.phoneNumber == contact.phoneNumber }) {
                    selectedContacts.append(contact)
                }
            }
        }
        
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            // Sheet dismisses automatically
        }
    }
}

// MARK: - Message Composer

struct MessageComposerView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    let completion: (MessageComposeResult) -> Void
    
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = recipients
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }
    
    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let completion: (MessageComposeResult) -> Void
        
        init(completion: @escaping (MessageComposeResult) -> Void) {
            self.completion = completion
        }
        
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true) {
                self.completion(result)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    InviteFriendsView()
}
