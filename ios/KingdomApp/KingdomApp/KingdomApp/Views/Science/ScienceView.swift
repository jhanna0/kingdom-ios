 import SwiftUI

// MARK: - Science View
// THE LABORATORY - High/Low guessing game

struct ScienceView: View {
    @StateObject private var viewModel = ScienceViewModel()
    @Environment(\.dismiss) private var dismiss
    
    let apiClient: APIClient
    
    // Animation state
    @State private var numberScale: CGFloat = 1.0
    @State private var isAnalyzing: Bool = false
    @State private var gaugeValue: Double = 50
    @State private var isCalibrating: Bool = true
    @State private var showNumber: Bool = false
    
    // Rewards popup
    @State private var showWinningsPopup: Bool = false
    @State private var pendingPlayAgainAfterWinnings: Bool = false
    
    // Colors
    private var labBlue: Color { KingdomTheme.Colors.royalBlue }
    private var labPurple: Color { KingdomTheme.Colors.royalPurple }
    private var labGold: Color { KingdomTheme.Colors.imperialGold }
    private var labOrange: Color { KingdomTheme.Colors.buttonWarning }
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchmentDark
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                // History cards - completed rounds
                historyBar
                    .frame(height: 50)
                
                // Fixed content area - no spacers, no shifting
                VStack(spacing: 16) {
                    Spacer(minLength: 0)
                    
                    // THE MAIN DISPLAY - Gauge + Number side by side
                    mainDisplay
                        .frame(height: 280)
                    
                    // Result card - FIXED HEIGHT
                    resultCard
                        .frame(height: 70)
                    
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, KingdomTheme.Spacing.large)
                
                bottomButtons
            }
            
            if showWinningsPopup, let collect = viewModel.collectResponse {
                winningsPopup(collect)
                    .transition(.opacity)
            }
        }
        .navigationBarHidden(true)
        .task {
            viewModel.configure(with: apiClient)
            await viewModel.loadConfig()
        }
        .onChange(of: viewModel.currentNumber) { _, newValue in
            runCalibrationAnimation()
        }
        .onChange(of: viewModel.uiState) { _, newState in
            if newState == .correct || newState == .wonMax {
                haptic(.success)
                pulseNumber()
            } else if newState == .wrong {
                haptic(.warning)
            } else if newState == .ready {
                // Run calibration when entering ready state (including after NEXT tap)
                runCalibrationAnimation()
            } else if newState == .collected {
                // Pop winnings overlay after collecting (win or loss)
                if let collect = viewModel.collectResponse, (collect.gold > 0 || collect.blueprint > 0 || !collect.rewards.isEmpty) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        showWinningsPopup = true
                    }
                }
            }
        }
    }
    
    // MARK: - Calibration Animation
    
    private func runCalibrationAnimation() {
        Task {
            await runCalibrationSequence()
        }
    }
    
    @MainActor
    private func runCalibrationSequence() async {
        let targetValue = Double(viewModel.currentNumber)
        
        isCalibrating = true
        showNumber = false
        
        // Sweep through random positions before landing
        let positions: [Double] = [
            Double.random(in: 80...100),
            Double.random(in: 10...30),
            Double.random(in: 60...80),
            Double.random(in: 20...40),
            Double.random(in: 50...70),
            Double.random(in: 30...50),
            targetValue  // Land on target
        ]
        
        for (index, pos) in positions.enumerated() {
            let duration = index == positions.count - 1 ? 0.35 : 0.12
            withAnimation(.easeInOut(duration: duration)) {
                gaugeValue = pos
            }
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        }
        
        // Final spring settle
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            gaugeValue = targetValue
        }
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        // Show the number
        withAnimation(.easeIn(duration: 0.2)) {
            showNumber = true
        }
        isCalibrating = false
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                Text("THE LABORATORY")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                Button("Done") {
                    Task {
                        await viewModel.endExperiment()
                        dismiss()
                    }
                }
                .font(FontStyles.bodyMediumBold)
                .foregroundColor(labBlue)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            
            // Streak indicator
            HStack(spacing: 12) {
                ForEach(0..<max(1, viewModel.maxStreak), id: \.self) { i in
                    streakDot(index: i)
                }
            }
            .padding(.bottom, 12)
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
        }
        .background(KingdomTheme.Colors.parchmentLight)
    }
    
    private func streakDot(index: Int) -> some View {
        let isComplete = index < viewModel.streak
        let isFinal = index == max(0, viewModel.maxStreak - 1)
        let goldReward = (index + 1) * 5
        
        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isComplete ? labGold : KingdomTheme.Colors.parchment)
                    .frame(width: 32, height: 32)
                    .overlay(Circle().stroke(Color.black, lineWidth: 2))
                
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            
            ZStack {
                Text("\(goldReward)g")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isComplete ? labGold : KingdomTheme.Colors.inkMedium)
                    .opacity(isFinal ? 0 : 1)
                
                Image(systemName: "scroll.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isComplete ? labGold : KingdomTheme.Colors.inkMedium)
                    .opacity(isFinal ? 1 : 0)
            }
        }
    }
    
    // MARK: - History Bar (completed rounds)
    
    private var historyBar: some View {
        let rounds = viewModel.playedRounds.filter { $0.is_revealed }
        
        return HStack(spacing: 8) {
            // Show up to 3 history cards (one per round)
            ForEach(0..<max(1, viewModel.maxStreak), id: \.self) { index in
                historyCard(for: index, rounds: rounds)
            }
        }
        .padding(.horizontal, KingdomTheme.Spacing.large)
        .padding(.vertical, 8)
        .background(KingdomTheme.Colors.parchment)
    }
    
    private func historyCard(for index: Int, rounds: [ScienceRound]) -> some View {
        let round = rounds.first { $0.round_num == index + 1 }
        let isPlayed = round != nil
        let isCorrect = round?.is_correct ?? false
        let bgColor = isPlayed ? (isCorrect ? labGold : labOrange) : KingdomTheme.Colors.parchmentLight
        let textColor = isPlayed ? Color.white : KingdomTheme.Colors.inkMedium
        
        let shownNumber = round?.shown_number ?? 0
        let hiddenNumber = round?.hidden_number ?? 0
        let arrowName = (round?.guess == "high") ? "arrow.up" : "arrow.down"
        
        return ZStack {
            // Played round - always rendered, toggled by opacity
            HStack(spacing: 4) {
                Text("\(shownNumber)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                Image(systemName: arrowName)
                    .font(.system(size: 10, weight: .bold))
                Text("\(hiddenNumber)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            .foregroundColor(textColor)
            .opacity(isPlayed ? 1 : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(!isPlayed)
            
            // Not played yet - always rendered, toggled by opacity
            Text("R\(index + 1)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(textColor)
                .opacity(isPlayed ? 0 : 1)
                .allowsHitTesting(false)
                .accessibilityHidden(isPlayed)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .background(bgColor)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.black, lineWidth: 1)
        )
    }
    
    // MARK: - Main Display (Gauge + Number)
    
    private var mainDisplay: some View {
        HStack(alignment: .center, spacing: 20) {
            // GAUGE - fixed size
            gauge
                .frame(width: 60, height: 280)
            
            // NUMBER CARD - fixed size
            numberCard
                .frame(width: 180, height: 220)
        }
    }
    
    // MARK: - Gauge (vertical scale with line marker) - FIXED SIZE
    
    private var gauge: some View {
        VStack(spacing: 2) {
            Text("100")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(height: 16)
            
            ZStack {
                // Background bar
                RoundedRectangle(cornerRadius: 10)
                    .fill(KingdomTheme.Colors.parchmentLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black, lineWidth: 3)
                    )
                
                // Tick marks
                GeometryReader { geo in
                    let tickHeight = geo.size.height - 16
                    VStack(spacing: 0) {
                        ForEach(0..<11, id: \.self) { i in
                            Rectangle()
                                .fill(Color.black.opacity(i % 5 == 0 ? 0.4 : 0.2))
                                .frame(width: i % 5 == 0 ? 28 : 14, height: 2)
                            if i < 10 { Spacer() }
                        }
                    }
                    .frame(height: tickHeight)
                    .padding(.vertical, 8)
                }
                
                // THE LINE MARKER
                GeometryReader { geo in
                    let inset: CGFloat = 8
                    let usableHeight = geo.size.height - (inset * 2)
                    let yPos = inset + usableHeight * (1 - gaugeValue / 100)
                    
                    Rectangle()
                        .fill(labBlue)
                        .frame(width: geo.size.width, height: 4)
                        .position(x: geo.size.width / 2, y: yPos)
                    
                    Circle()
                        .fill(labBlue)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .position(x: geo.size.width / 2, y: yPos)
                }
            }
            
            Text("1")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(height: 16)
        }
    }
    
    // MARK: - Number Card
    
    private var numberCard: some View {
        ZStack {
            // Shadow
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black)
                .offset(x: 4, y: 4)
            
            // Card
            RoundedRectangle(cornerRadius: 20)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(cardBorder, lineWidth: 4)
                )
            
            // Content - FIXED LAYOUT, use opacity for states
            VStack(spacing: 8) {
                // Top label - always present
                Text(cardLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(cardLabelColor)
                    .frame(height: 16)
                
                // Number area - fixed height
                ZStack {
                    // The number (shows result after guess, baseline before)
                    Text("\(displayNumber)")
                        .font(.system(size: 56, weight: .black, design: .monospaced))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .opacity(showNumber && !isAnalyzing ? 1 : 0)
                    
                    // Dash when calibrating or analyzing
                    Text("—")
                        .font(.system(size: 56, weight: .black, design: .monospaced))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .opacity((isCalibrating || isAnalyzing) ? 1 : 0)
                }
                .frame(height: 70)
                
                // Bottom label - always takes space
                Text(cardBottomLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(cardBottomLabelColor)
                    .opacity(cardBottomLabelOpacity)
                    .frame(height: 16)
            }
            .padding(16)
        }
        .scaleEffect(numberScale)
    }
    
    private var cardBackground: Color {
        // Always solid parchment - no opacity
        return KingdomTheme.Colors.parchmentLight
    }
    
    private var cardBorder: Color {
        switch viewModel.uiState {
        case .correct, .wonMax: return labGold
        case .wrong: return labOrange
        default: return Color.black
        }
    }
    
    // After a guess resolves, show the RESULT; otherwise show BASELINE
    private var showingResult: Bool {
        switch viewModel.uiState {
        case .correct, .wrong, .wonMax: return true
        default: return false
        }
    }
    
    private var displayNumber: Int {
        if showingResult, let result = viewModel.lastGuessResult {
            return result.hidden_number
        }
        return viewModel.currentNumber
    }
    
    private var cardLabel: String {
        if isCalibrating { return "CALIBRATING" }
        if isAnalyzing { return "ANALYZING" }
        if showingResult { return "RESULT" }
        return "BASELINE"
    }
    
    private var cardLabelColor: Color {
        if isAnalyzing { return labBlue }
        if showingResult {
            return viewModel.lastGuessResult?.is_correct == true ? labGold : labOrange
        }
        return KingdomTheme.Colors.inkMedium
    }
    
    private var cardBottomLabel: String {
        if showingResult {
            return viewModel.lastGuessResult?.is_correct == true ? "Confirmed" : "Rejected"
        }
        return "Higher or Lower?"
    }
    
    private var cardBottomLabelColor: Color {
        if showingResult {
            return viewModel.lastGuessResult?.is_correct == true ? labGold : labOrange
        }
        return KingdomTheme.Colors.inkMedium
    }
    
    private var cardBottomLabelOpacity: Double {
        if isAnalyzing { return 0 }
        if showingResult { return 1 }
        // Show "Higher or Lower?" during calibration and when ready
        return 1
    }
    
    // MARK: - Result Card (FIXED height, no shifting)
    
    private var resultCard: some View {
        let hasResult = viewModel.lastGuessResult != nil
        let result = viewModel.lastGuessResult
        let resultColor = (result?.is_correct ?? false) ? labGold : labOrange
        
        return ZStack {
            // Empty state - always rendered, hidden when result exists
            HStack {
                Image(systemName: "flask.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(labBlue)
                
                Text("Awaiting hypothesis...")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Spacer()
                
                Text("1-100")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .padding(12)
            .opacity(hasResult ? 0 : 1)
            
            // Result state - always rendered, hidden when no result
            HStack(spacing: 0) {
                // Left: Badge
                Text(result?.is_correct == true ? "CONFIRMED" : "REJECTED")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(resultColor)
                    .cornerRadius(6)
                
                Spacer()
                
                // Center: The data
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("OBS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        Text("\(result?.shown_number ?? 0)")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    }
                    
                    Image(systemName: result?.guess == "high" ? "arrow.up" : "arrow.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    VStack(spacing: 2) {
                        Text("RESULT")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        Text("\(result?.hidden_number ?? 0)")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundColor(resultColor)
                    }
                }
                
                Spacer()
                
                // Right: Icon
                Image(systemName: result?.is_correct == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(resultColor)
            }
            .padding(12)
            .opacity(hasResult ? 1 : 0)
        }
        .frame(height: 70)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
    }
    
    // MARK: - Bottom Buttons
    
    private var bottomButtons: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.black)
                .frame(height: 3)
            
            bottomButtonContent
                .padding(.horizontal, KingdomTheme.Spacing.large)
                .padding(.vertical, KingdomTheme.Spacing.medium)
        }
        .background(KingdomTheme.Colors.parchmentLight.ignoresSafeArea(edges: .bottom))
    }
    
    private var bottomButtonContent: some View {
        let showCalibrating = viewModel.uiState == .loading || (viewModel.uiState == .ready && isCalibrating)
        let showGuessButtons = (viewModel.uiState == .ready) && !isCalibrating && viewModel.canGuess
        let showNewTrial = viewModel.uiState == .notStarted || (viewModel.uiState == .collected) || ((viewModel.uiState == .ready) && !isCalibrating && !viewModel.canGuess)
        let showAnalyzing = viewModel.uiState == .guessing
        let showNext = viewModel.uiState == .correct
        let showWrong = viewModel.uiState == .wrong
        let showClaim = viewModel.uiState == .wonMax
        let showRecording = viewModel.uiState == .collecting
        let errorMessage: String? = {
            if case let .error(msg) = viewModel.uiState { return msg }
            return nil
        }()
        
        return ZStack {
            loadingRow("Calibrating...")
                .opacity(showCalibrating ? 1 : 0)
                .allowsHitTesting(showCalibrating)
                .accessibilityHidden(!showCalibrating)
            
            guessButtons
                .opacity(showGuessButtons ? 1 : 0)
                .allowsHitTesting(showGuessButtons)
                .accessibilityHidden(!showGuessButtons)
            
            loadingRow("Analyzing...")
                .opacity(showAnalyzing ? 1 : 0)
                .allowsHitTesting(showAnalyzing)
                .accessibilityHidden(!showAnalyzing)
            
            nextButton
                .opacity(showNext ? 1 : 0)
                .allowsHitTesting(showNext)
                .accessibilityHidden(!showNext)
            
            wrongButtons
                .opacity(showWrong ? 1 : 0)
                .allowsHitTesting(showWrong)
                .accessibilityHidden(!showWrong)
            
            claimButton
                .opacity(showClaim ? 1 : 0)
                .allowsHitTesting(showClaim)
                .accessibilityHidden(!showClaim)
            
            loadingRow("Recording...")
                .opacity(showRecording ? 1 : 0)
                .allowsHitTesting(showRecording)
                .accessibilityHidden(!showRecording)
            
            newTrialButton
                .opacity(showNewTrial ? 1 : 0)
                .allowsHitTesting(showNewTrial)
                .accessibilityHidden(!showNewTrial)
            
            // Error row - keep space stable, avoid red/green
            Text(errorMessage ?? "")
                .font(FontStyles.bodyMedium)
                .foregroundColor(labOrange)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .opacity(errorMessage == nil ? 0 : 1)
                .allowsHitTesting(false)
                .accessibilityHidden(errorMessage == nil)
        }
        .frame(height: 50)
    }
    
    private func loadingRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(labBlue)
            Text(text)
                .font(FontStyles.bodyMediumBold)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .frame(height: 50)
    }
    
    private var guessButtons: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            Button {
                Task { await makeGuess("low") }
            } label: {
                HStack {
                    Image(systemName: "arrow.down")
                    Text("Lower")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.brutalist(backgroundColor: labPurple, foregroundColor: .white, fullWidth: true))
            .disabled(isAnalyzing)
            
            Button {
                Task { await makeGuess("high") }
            } label: {
                HStack {
                    Image(systemName: "arrow.up")
                    Text("Higher")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.brutalist(backgroundColor: labBlue, foregroundColor: .white, fullWidth: true))
            .disabled(isAnalyzing)
        }
    }
    
    private var nextButton: some View {
        Button {
            viewModel.continueToNextTrial()
        } label: {
            HStack {
                Text("Next")
                Image(systemName: "arrow.right")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.brutalist(backgroundColor: labBlue, foregroundColor: .white, fullWidth: true))
    }
    
    private var wrongButtons: some View {
        // Auto-collect then show winnings popup, then start new trial
        Button {
            Task {
                if viewModel.canCollect {
                    pendingPlayAgainAfterWinnings = true
                    await viewModel.collect()
                } else {
                    pendingPlayAgainAfterWinnings = false
                    await viewModel.playAgain()
                }
            }
        } label: {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                Text("New Trial (\(viewModel.entryCost)g)")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.brutalist(backgroundColor: labBlue, foregroundColor: .white, fullWidth: true))
    }
    
    private var claimButton: some View {
        Button {
            Task { await viewModel.collect() }
        } label: {
            HStack {
                Image(systemName: "sparkles")
                Text("Claim Blueprint!")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.brutalist(backgroundColor: labGold, foregroundColor: .white, fullWidth: true))
    }
    
    private var newTrialButton: some View {
        Button {
            Task {
                await viewModel.startExperiment()
                runCalibrationAnimation()
            }
        } label: {
            HStack {
                Image(systemName: "flask.fill")
                Text("Start Trial (\(viewModel.entryCost)g)")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.brutalist(backgroundColor: labBlue, foregroundColor: .white, fullWidth: true))
    }
    
    // MARK: - Actions
    
    private func makeGuess(_ direction: String) async {
        isAnalyzing = true
        
        // SUSPENSE ANIMATION - line bounces around before landing
        await runRollAnimation(direction)
        
        isAnalyzing = false
    }
    
    @MainActor
    private func runRollAnimation(_ direction: String) async {
        // First, get the result from backend (but don't show yet)
        await viewModel.guess(direction)
        
        guard let result = viewModel.lastGuessResult else { return }
        let finalValue = Double(result.hidden_number)
        
        // Now animate the line bouncing before landing
        // Sweep up and down dramatically
        let positions: [Double] = [
            Double.random(in: 10...30),
            Double.random(in: 70...90),
            Double.random(in: 20...40),
            Double.random(in: 60...80),
            Double.random(in: 30...50),
            Double.random(in: 50...70),
            finalValue  // Land on result
        ]
        
        for (index, pos) in positions.enumerated() {
            let duration = index == positions.count - 1 ? 0.4 : 0.15
            withAnimation(.easeInOut(duration: duration)) {
                gaugeValue = pos
            }
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        }
        
        // Small bounce at the end
        try? await Task.sleep(nanoseconds: 100_000_000)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            gaugeValue = finalValue
        }
    }
    
    private func pulseNumber() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            numberScale = 1.1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                numberScale = 1.0
            }
        }
    }
    
    private func haptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
    
    // MARK: - Winnings Popup
    
    private func winningsPopup(_ collect: ScienceCollectResponse) -> some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissWinningsPopup()
                }
            
            VStack(spacing: 16) {
                // Title (no emoji)
                Text(collect.blueprint > 0 ? "BREAKTHROUGH RECORDED" : "FINDINGS RECORDED")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .multilineTextAlignment(.center)
                
                if let msg = collect.message, !msg.isEmpty {
                    Text(msg)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 10) {
                    ForEach(collect.rewards.indices, id: \.self) { idx in
                        let r = collect.rewards[idx]
                        HStack(spacing: 10) {
                            Image(systemName: r.icon)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                                .frame(width: 26)
                            
                            Text("+\(r.amount) \(r.display_name)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight)
                    }
                }
                
                Button {
                    dismissWinningsPopup()
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.brutalist(backgroundColor: labBlue, foregroundColor: .white, fullWidth: true))
            }
            .padding(22)
            .frame(maxWidth: 320)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 18)
        }
    }
    
    private func dismissWinningsPopup() {
        withAnimation(.easeOut(duration: 0.18)) {
            showWinningsPopup = false
        }
        
        if pendingPlayAgainAfterWinnings {
            pendingPlayAgainAfterWinnings = false
            Task { await viewModel.playAgain() }
        }
    }
}

#Preview {
    Text("Science Preview")
}
