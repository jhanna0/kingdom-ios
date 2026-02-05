import SwiftUI

/// Popup for using books to skip cooldowns
/// Shows book info, count, and option to use or buy more
struct BookUsagePopup: View {
    let slot: String  // "personal", "building", or "crafting"
    let actionType: String?  // Optional specific action type
    let cooldownSecondsRemaining: Int
    @Binding var isShowing: Bool
    let onUseBook: () -> Void
    let onBuyBooks: () -> Void
    
    @State private var bookInfo: BookInfoResponse?
    @State private var isLoading = true
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    private var slotDisplayName: String {
        switch slot {
        case "personal": return "Training"
        case "building": return "Building"
        case "crafting": return "Crafting"
        default: return slot.capitalized
        }
    }
    
    private var cooldownText: String {
        let hours = cooldownSecondsRemaining / 3600
        let minutes = (cooldownSecondsRemaining % 3600) / 60
        
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 20) {
                // Icon with brutalist style
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 80, height: 80)
                        .offset(x: 3, y: 3)
                    
                    Circle()
                        .fill(KingdomTheme.Colors.buttonPrimary)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 3)
                        )
                    
                    Image(systemName: "book.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }
                .padding(.top, 8)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: KingdomTheme.Colors.inkMedium))
                        .padding()
                } else if let info = bookInfo {
                    // Title
                    VStack(spacing: 8) {
                        Text("Use a Book")
                            .font(FontStyles.headingLarge)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Text(info.description)
                            .font(FontStyles.bodyMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal)
                    }
                    
                    // Stats Card
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("YOUR BOOKS")
                                .font(FontStyles.labelTiny)
                                .foregroundColor(KingdomTheme.Colors.inkLight)
                            HStack(spacing: 6) {
                                Image(systemName: "book.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                                Text("\(info.books_owned)")
                                    .font(FontStyles.headingMedium)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Rectangle()
                            .fill(KingdomTheme.Colors.divider.opacity(0.3))
                            .frame(width: 1, height: 40)
                            .padding(.horizontal, 16)
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("COOLDOWN LEFT")
                                .font(FontStyles.labelTiny)
                                .foregroundColor(KingdomTheme.Colors.inkLight)
                            Text(cooldownText)
                                .font(FontStyles.headingMedium)
                                .foregroundColor(KingdomTheme.Colors.buttonWarning)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(KingdomTheme.Colors.parchment.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(KingdomTheme.Colors.border.opacity(0.5), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
                    
                    // Buttons
                    VStack(spacing: 12) {
                        if info.books_owned > 0 {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isShowing = false
                                }
                                onUseBook()
                            }) {
                                HStack {
                                    Image(systemName: "book.fill")
                                    Text(info.effect_description)  // Server-driven button text
                                }
                            }
                            .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonSuccess, fullWidth: true))
                        }
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isShowing = false
                            }
                        }) {
                            Text("Cancel")
                                .font(FontStyles.labelBold)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                } else {
                    // Error state
                    Text("Failed to load book info")
                        .font(FontStyles.bodyMedium)
                        .foregroundColor(KingdomTheme.Colors.error)
                        .padding()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isShowing = false
                        }
                    }) {
                        Text("Close")
                            .font(FontStyles.labelBold)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    .padding()
                }
            }
            .padding(.vertical, 28)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                        .fill(Color.black)
                        .offset(x: KingdomTheme.Brutalist.offsetShadow, y: KingdomTheme.Brutalist.offsetShadow)
                    
                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                        .fill(KingdomTheme.Colors.parchmentLight)
                        .overlay(
                            RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                                .stroke(Color.black, lineWidth: KingdomTheme.Brutalist.borderWidth)
                        )
                }
            )
            .shadow(
                color: KingdomTheme.Shadows.brutalistSoft.color,
                radius: KingdomTheme.Shadows.brutalistSoft.radius,
                x: KingdomTheme.Shadows.brutalistSoft.x,
                y: KingdomTheme.Shadows.brutalistSoft.y
            )
            .padding(.horizontal, 32)
            .scaleEffect(scale)
            .opacity(opacity)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .opacity(opacity)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isShowing = false
                    }
                }
        )
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                scale = 1.0
                opacity = 1.0
            }
            
            Task {
                bookInfo = await StoreService.shared.getBookInfo()
                isLoading = false
            }
        }
        .presentationBackground(.clear)
    }
}
