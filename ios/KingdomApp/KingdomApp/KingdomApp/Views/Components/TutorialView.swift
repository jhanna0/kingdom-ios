import SwiftUI

/// Tutorial / Help Book View
/// Displays wiki-style sections fetched from the backend
/// Includes embedded Battle Simulator for visualizing combat mechanics
struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sections: [TutorialSection] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var notificationsEnabled = true
    
    private let tutorialAPI = TutorialAPI()
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        if isLoading {
                            loadingView
                        } else if let error = error {
                            errorView(error)
                        } else {
                            tutorialContent(proxy: proxy)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .parchmentBackground()
            .navigationTitle("Help Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                }
            }
            .parchmentNavigationBar()
        }
        .task {
            await loadTutorial()
            await checkNotificationPermission()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(KingdomTheme.Colors.buttonPrimary)
            Text("Loading help content...")
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(FontStyles.resultLarge)
                .foregroundColor(KingdomTheme.Colors.buttonWarning)
            
            Text("Unable to load help content")
                .font(FontStyles.headingMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text(message)
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task { await loadTutorial() }
            }
            .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonPrimary))
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
    }
    
    // MARK: - Tutorial Content
    
    private func tutorialContent(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 12) {
            // Header
            headerSection
            
            // Table of Contents
            tableOfContents(proxy: proxy)
            
            // Sections (demos embedded inside cards)
            ForEach(sections) { section in
                sectionCard(section)
                    .id(section.id)
            }
            
            // Feedback Section
            feedbackCard
                .id("feedback")
            
            Spacer(minLength: 40)
        }
    }
    
    // MARK: - Table of Contents
    
    private func tableOfContents(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 32, height: 32)
                        .offset(x: 2, y: 2)
                    Circle()
                        .fill(KingdomTheme.Colors.goldLight)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 2)
                        )
                    Image(systemName: "list.bullet")
                        .font(FontStyles.iconTiny)
                        .foregroundColor(.white)
                }
                
                Text("Table of Contents")
                    .font(FontStyles.headingSmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            .padding(12)
            
            Rectangle()
                .fill(Color.black.opacity(0.15))
                .frame(height: 1)
                .padding(.horizontal, 12)
            
            // TOC Items
            VStack(alignment: .leading, spacing: 0) {
                ForEach(sections) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(section.id, anchor: .top)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: section.icon)
                                .font(.system(size: 12))
                                .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                                .frame(width: 20)
                            
                            Text(section.title)
                                .font(FontStyles.labelMedium)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(KingdomTheme.Colors.inkLight)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    Rectangle()
                        .fill(Color.black.opacity(0.08))
                        .frame(height: 1)
                        .padding(.leading, 42)
                }
                
                // Send Feedback link
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("feedback", anchor: .top)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 12))
                            .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                            .frame(width: 20)
                        
                        Text("Send Feedback")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .offset(x: 3, y: 3)
                RoundedRectangle(cornerRadius: 12)
                    .fill(KingdomTheme.Colors.parchmentLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black, lineWidth: 2)
                    )
            }
        )
    }
    
    // MARK: - Notification Enable Button (inline in card)
    
    private var notificationEnableButton: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 12))
                Text("Enable Notifications")
                    .font(FontStyles.labelSmall)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonSuccess, fullWidth: true))
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.closed.fill")
                .font(FontStyles.resultLarge)
                .foregroundColor(KingdomTheme.Colors.goldLight)
            
            Text("Kingdom Guide")
                .font(FontStyles.displaySmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("Everything you need to know about conquering the realm")
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Section Card
    
    private func sectionCard(_ section: TutorialSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 32, height: 32)
                        .offset(x: 2, y: 2)
                    Circle()
                        .fill(KingdomTheme.Colors.buttonPrimary)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 2)
                        )
                    Image(systemName: section.icon)
                        .font(FontStyles.iconTiny)
                        .foregroundColor(.white)
                }
                
                // Title
                Text(section.title)
                    .font(FontStyles.headingSmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            .padding(12)
            
            Rectangle()
                .fill(Color.black.opacity(0.15))
                .frame(height: 1)
                .padding(.horizontal, 12)
            
            // Content - always visible
            markdownContent(section.content)
                .padding(12)
            
            // Embed territory demo inside Coups card
            if section.id == "coups" {
                coupTerritoryDemo
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
            
            // Embed battle simulator inside Battle System card
            if section.id == "battles" {
                battleSimulatorInline
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
            
            // Embed notification button inside Notifications card
            if section.id == "notifications" && !notificationsEnabled {
                notificationEnableButton
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .offset(x: 3, y: 3)
                RoundedRectangle(cornerRadius: 12)
                    .fill(KingdomTheme.Colors.parchmentLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black, lineWidth: 2)
                    )
            }
        )
    }
    
    // MARK: - Feedback Card
    
    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 32, height: 32)
                        .offset(x: 2, y: 2)
                    Circle()
                        .fill(KingdomTheme.Colors.buttonPrimary)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 2)
                        )
                    Image(systemName: "envelope.fill")
                        .font(FontStyles.iconTiny)
                        .foregroundColor(.white)
                }
                
                Text("Send Feedback")
                    .font(FontStyles.headingSmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            .padding(12)
            
            Rectangle()
                .fill(Color.black.opacity(0.15))
                .frame(height: 1)
                .padding(.horizontal, 12)
            
            // Content
            VStack(alignment: .leading, spacing: 12) {
                Text("Questions, bugs, feedback, suggestions? Let us know!")
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                NavigationLink {
                    FeedbackView()
                } label: {
                    HStack {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 12))
                        Text("Send Feedback")
                            .font(FontStyles.labelSmall)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonPrimary, fullWidth: true))
            }
            .padding(12)
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .offset(x: 3, y: 3)
                RoundedRectangle(cornerRadius: 12)
                    .fill(KingdomTheme.Colors.parchmentLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black, lineWidth: 2)
                    )
            }
        )
    }
    
    // MARK: - Coup Territory Demo
    
    private var coupTerritoryDemo: some View {
        VStack(spacing: 8) {
            tutorialTugOfWarBar(name: "The Market", value: 35.0, captured: false)
            tutorialTugOfWarBar(name: "The Armory", value: 72.0, captured: false)
            tutorialTugOfWarBar(name: "Throne Room", value: 0.0, captured: true, capturedBy: "attackers")
            
            Text("First to capture 2 of 3 wins")
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .padding(.top, 2)
        }
    }
    
    // Simple tug of war bar for tutorial demo
    private func tutorialTugOfWarBar(name: String, value: Double, captured: Bool, capturedBy: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Territory name
            HStack {
                Text(name.uppercased())
                    .font(FontStyles.labelBadge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                Spacer()
                if captured, let winner = capturedBy {
                    Text("CAPTURED")
                        .font(FontStyles.labelBadge)
                        .foregroundColor(winner == "attackers" ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.royalBlue)
                }
            }
            
            // The bar
            GeometryReader { geo in
                let width = geo.size.width
                let progress = min(1.0, max(0.0, value / 100.0))
                let coupersWidth = width * (1 - progress)
                let coupersPct = Int((1 - progress) * 100)
                let crownPct = Int(progress * 100)
                
                ZStack(alignment: .leading) {
                    // Crown side (blue) - background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(KingdomTheme.Colors.royalBlue.opacity(0.7))
                    
                    // Coupers side (red) - from left
                    RoundedRectangle(cornerRadius: 6)
                        .fill(KingdomTheme.Colors.buttonDanger.opacity(0.7))
                        .frame(width: coupersWidth)
                    
                    // Labels
                    HStack {
                        Text("COUP \(coupersPct)%")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.leading, 6)
                        
                        Spacer()
                        
                        Text("CROWN \(crownPct)%")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.trailing, 6)
                    }
                    
                    // Border
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.black, lineWidth: 1.5)
                }
            }
            .frame(height: 24)
        }
    }
    
    // MARK: - Battle Simulator Inline (Compact)
    
    @State private var simBar: Double = 50.0
    @State private var simSideASize: Int = 10000
    @State private var simSideBSize: Int = 300
    @State private var simSideAStats: Int = 3
    @State private var simSideBStats: Int = 5
    @State private var simRound: Int = 0
    @State private var simWinner: String? = nil
    
    private var battleSimulatorInline: some View {
        VStack(spacing: 12) {
            // Tug of war bar
            tutorialBattleBar(value: simBar)
            
            // Side A (left) vs Side B (right) stats - with controls
            HStack(spacing: 8) {
                // Side A - The Mob
                VStack(spacing: 6) {
                    Text("SIDE A")
                        .font(FontStyles.labelBadge)
                        .foregroundColor(KingdomTheme.Colors.buttonDanger)
                    
                    // Player count with +/- buttons
                    HStack(spacing: 4) {
                        Button { simSideASize = max(100, simSideASize - 500) } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 16))
                        }
                        VStack(spacing: 0) {
                            Text("\(simSideASize.formatted())")
                                .font(FontStyles.labelSmall)
                            Text("players")
                                .font(.system(size: 8))
                        }
                        .frame(width: 50)
                        Button { simSideASize = min(50000, simSideASize + 500) } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                        }
                    }
                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
                    
                    // Stats with +/- buttons
                    HStack(spacing: 4) {
                        Button { simSideAStats = max(1, simSideAStats - 1) } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 16))
                        }
                        VStack(spacing: 0) {
                            Text("T\(simSideAStats)")
                                .font(FontStyles.labelSmall)
                            Text("stats")
                                .font(.system(size: 8))
                        }
                        .frame(width: 50)
                        Button { simSideAStats = min(10, simSideAStats + 1) } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                        }
                    }
                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
                }
                .frame(maxWidth: .infinity)
                
                // VS
                Text("vs")
                    .font(FontStyles.labelBold)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                
                // Side B
                VStack(spacing: 6) {
                    Text("SIDE B")
                        .font(FontStyles.labelBadge)
                        .foregroundColor(KingdomTheme.Colors.royalBlue)
                    
                    // Player count with +/- buttons
                    HStack(spacing: 4) {
                        Button { simSideBSize = max(100, simSideBSize - 100) } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 16))
                        }
                        VStack(spacing: 0) {
                            Text("\(simSideBSize.formatted())")
                                .font(FontStyles.labelSmall)
                            Text("players")
                                .font(.system(size: 8))
                        }
                        .frame(width: 50)
                        Button { simSideBSize = min(50000, simSideBSize + 100) } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                        }
                    }
                    .foregroundColor(KingdomTheme.Colors.royalBlue)
                    
                    // Stats with +/- buttons
                    HStack(spacing: 4) {
                        Button { simSideBStats = max(1, simSideBStats - 1) } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 16))
                        }
                        VStack(spacing: 0) {
                            Text("T\(simSideBStats)")
                                .font(FontStyles.labelSmall)
                            Text("stats")
                                .font(.system(size: 8))
                        }
                        .frame(width: 50)
                        Button { simSideBStats = min(10, simSideBStats + 1) } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                        }
                    }
                    .foregroundColor(KingdomTheme.Colors.royalBlue)
                }
                .frame(maxWidth: .infinity)
            }
            
            // Round counter and buttons
            HStack(spacing: 12) {
                if let winner = simWinner {
                    Text("\(winner) WINS!")
                        .font(FontStyles.labelBold)
                        .foregroundColor(winner == "SIDE A" ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.royalBlue)
                } else {
                    Text("Round \(simRound)")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
                
                Button {
                    resetSimulator()
                } label: {
                    Text("Reset")
                        .font(FontStyles.labelSmall)
                }
                .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.inkMedium))
                
                Button {
                    stepSimulator()
                } label: {
                    Text("Next Round")
                        .font(FontStyles.labelSmall)
                }
                .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonPrimary))
                .disabled(simWinner != nil)
            }
        }
    }
    
    private func tutorialBattleBar(value: Double) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let progress = min(1.0, max(0.0, value / 100.0))
            let sideAWidth = width * (1 - progress)
            let sideAPct = Int((1 - progress) * 100)
            let sideBPct = Int(progress * 100)
            
            ZStack(alignment: .leading) {
                // Side B (blue) - background
                RoundedRectangle(cornerRadius: 8)
                    .fill(KingdomTheme.Colors.royalBlue.opacity(0.7))
                
                // Side A (red) - from left
                RoundedRectangle(cornerRadius: 8)
                    .fill(KingdomTheme.Colors.buttonDanger.opacity(0.7))
                    .frame(width: sideAWidth)
                
                // Center line
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 2)
                    .position(x: width / 2, y: 16)
                
                // Labels
                HStack {
                    Text("\(sideAPct)%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.leading, 8)
                    
                    Spacer()
                    
                    Text("\(sideBPct)%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.trailing, 8)
                }
                
                // Border
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black, lineWidth: 2)
            }
        }
        .frame(height: 32)
    }
    
    private func resetSimulator() {
        withAnimation(.spring(response: 0.3)) {
            simBar = 50.0
            simRound = 0
            simWinner = nil
        }
    }
    
    private func stepSimulator() {
        guard simWinner == nil else { return }
        
        simRound += 1
        
        // Simplified battle math - demonstrates diminishing returns
        // Side A: big army, low stats
        // Side B: small army, high stats
        let aRolls = Double(simSideASize)
        let bRolls = Double(simSideBSize)
        
        // Push per hit scales inversely with size, boosted by stats
        let aPushPerHit = 1.0 / pow(aRolls, 0.7) * Double(simSideAStats)
        let bPushPerHit = 1.0 / pow(bRolls, 0.7) * Double(simSideBStats)
        
        // Hit rate based on stats
        let aHitRate = Double(simSideAStats) / 15.0
        let bHitRate = Double(simSideBStats) / 15.0
        
        let aHits = aRolls * aHitRate
        let bHits = bRolls * bHitRate
        
        let aPush = aHits * aPushPerHit
        let bPush = bHits * bPushPerHit
        
        // Add some randomness
        let randomFactor = Double.random(in: 0.7...1.3)
        let netPush = (aPush - bPush) * randomFactor
        
        withAnimation(.spring(response: 0.35)) {
            simBar = min(100.0, max(0.0, simBar - netPush))
        }
        
        // Check winner
        if simBar <= 5 {
            simWinner = "SIDE A"
        } else if simBar >= 95 {
            simWinner = "SIDE B"
        }
    }
    
    // MARK: - Markdown Content Renderer
    
    @ViewBuilder
    private func markdownContent(_ text: String) -> some View {
        let elements = parseMarkdown(text)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(elements.enumerated()), id: \.offset) { index, element in
                renderElement(element)
            }
        }
    }
    
    private func parseMarkdown(_ text: String) -> [MarkdownElement] {
        var elements: [MarkdownElement] = []
        let lines = text.components(separatedBy: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty {
                // Skip empty lines instead of creating spacers
                continue
            } else if trimmed.hasPrefix("**") && trimmed.hasSuffix("**") && trimmed.count > 4 {
                // Bold heading (single-line bold)
                let content = String(trimmed.dropFirst(2).dropLast(2))
                elements.append(.heading(content))
            } else if trimmed.hasPrefix("- ") {
                // Bullet point
                let content = String(trimmed.dropFirst(2))
                elements.append(.bullet(parseInlineFormatting(content)))
            } else if let match = trimmed.range(of: "^\\d+\\. ", options: .regularExpression) {
                // Numbered list
                let content = String(trimmed[match.upperBound...])
                let number = String(trimmed[..<match.lowerBound]) + String(trimmed[match])
                elements.append(.numbered(number.trimmingCharacters(in: .whitespaces), parseInlineFormatting(content)))
            } else {
                // Regular paragraph
                elements.append(.paragraph(parseInlineFormatting(trimmed)))
            }
        }
        
        return elements
    }
    
    private func parseInlineFormatting(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        
        // Handle **bold** formatting
        let boldPattern = /\*\*([^*]+)\*\*/
        var searchText = text
        var offset = 0
        
        while let match = searchText.firstMatch(of: boldPattern) {
            let boldText = String(match.1)
            let fullMatch = String(match.0)
            
            if let range = result.range(of: fullMatch) {
                var boldAttr = AttributedString(boldText)
                boldAttr.font = FontStyles.bodySmallBold
                result.replaceSubrange(range, with: boldAttr)
            }
            
            // Move past this match
            if let matchRange = searchText.range(of: fullMatch) {
                searchText = String(searchText[matchRange.upperBound...])
            } else {
                break
            }
        }
        
        return result
    }
    
    @ViewBuilder
    private func renderElement(_ element: MarkdownElement) -> some View {
        switch element {
        case .heading(let text):
            Text(text)
                .font(FontStyles.bodySmallBold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .padding(.top, 4)
            
        case .paragraph(let attributed):
            Text(attributed)
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .fixedSize(horizontal: false, vertical: true)
            
        case .bullet(let attributed):
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(FontStyles.labelBold)
                    .foregroundColor(KingdomTheme.Colors.goldLight)
                Text(attributed)
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
        case .numbered(let number, let attributed):
            HStack(alignment: .top, spacing: 8) {
                Text(number)
                    .font(FontStyles.labelBold)
                    .foregroundColor(KingdomTheme.Colors.goldLight)
                    .frame(width: 20, alignment: .trailing)
                Text(attributed)
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadTutorial() async {
        isLoading = true
        error = nil
        
        // Retry up to 3 times with delay
        for attempt in 1...3 {
            do {
                let response = try await tutorialAPI.getTutorial()
                await MainActor.run {
                    self.sections = response.sections
                    self.isLoading = false
                    self.error = nil
                }
                return // Success
            } catch {
                print("📖 Tutorial load attempt \(attempt) failed: \(error.localizedDescription)")
                if attempt < 3 {
                    // Wait a bit before retrying
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                } else {
                    // Final attempt failed
                    await MainActor.run {
                        self.error = error.localizedDescription
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    private func checkNotificationPermission() async {
        let enabled = await NotificationManager.shared.checkPermission()
        await MainActor.run {
            notificationsEnabled = enabled
        }
    }
}

// MARK: - Markdown Element

private enum MarkdownElement {
    case heading(String)
    case paragraph(AttributedString)
    case bullet(AttributedString)
    case numbered(String, AttributedString)
}

// MARK: - Feedback View

struct FeedbackView: View {
    @Environment(\.dismiss) var dismiss
    @State private var message = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ZStack(alignment: .topLeading) {
                    if message.isEmpty {
                        Text("Let's hear it")
                            .font(KingdomTheme.Typography.body())
                            .foregroundColor(KingdomTheme.Colors.inkMedium.opacity(0.6))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)
                    }
                    
                    TextEditor(text: $message)
                        .font(KingdomTheme.Typography.body())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .tint(KingdomTheme.Colors.inkDark)
                        .scrollContentBackground(.hidden)
                        .frame(height: 150)
                        .padding(12)
                }
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(KingdomTheme.Colors.inkLight.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal)
                
                if let error = errorMessage {
                    Text(error)
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.error)
                }
                
                Button {
                    submitFeedback()
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        }
                        Text(isSubmitting ? "Sending..." : "Send Feedback")
                    }
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .brutalistBadge(
                    backgroundColor: message.count >= 5 ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.inkSubtle,
                    cornerRadius: 8,
                    shadowOffset: 2,
                    borderWidth: 2
                )
                .padding(.horizontal)
                .disabled(message.count < 5 || isSubmitting)
                
                Spacer()
            }
            .padding(.top)
        }
        .navigationTitle("Send Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .alert("Thanks!", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your feedback has been sent.")
        }
    }
    
    private func submitFeedback() {
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                struct FeedbackRequest: Encodable {
                    let message: String
                }
                let request = try APIClient.shared.request(
                    endpoint: "/feedback",
                    method: "POST",
                    body: FeedbackRequest(message: message)
                )
                let _: [String: Bool] = try await APIClient.shared.execute(request)
                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "Failed to send. Try again."
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TutorialView()
}
