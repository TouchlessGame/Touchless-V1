import SwiftUI
import AVFoundation

struct GamePageView: View {
    @ObservedObject var engine: TrackingEngine
    @StateObject private var director = GameDirector()
    
    var isMultiplayer: Bool
    var rounds: Int
    var onReturnToMenu: () -> Void
    
    // 🏆 Global Score Trackers
    @State private var p1Score: Int = 0
    @State private var p2Score: Int = 0
    
    // 🪚 THE DATA PIPELINES
    @State private var p1Progress: String = ""
    @State private var p2Progress: String = ""
    
    // 🛑 State for the instruction screen
    @State private var showInstruction: Bool = true
    @State private var dismissInstructionWorkItem: DispatchWorkItem? = nil
    
    var body: some View {
        ZStack {
            // 🚦 TRAFFIC CONTROLLER
            if director.isSequenceComplete {
                // 🏁 STATE B: THE GAME IS OVER
                ResultsPageView(
                    p1Score: p1Score,
                    p2Score: p2Score,
                    isMultiplayer: isMultiplayer,
                    onRematch: resetGame,
                    onMainMenu: onReturnToMenu
                )
            } else {
                // 🎮 STATE A: THE ACTIVE GAME (Only starts and processes inputs when instruction is dismissed!)
                if !showInstruction {
                    if isMultiplayer {
                        HStack(spacing: 0) {
                            ZStack {
                                Color.blue.opacity(0.15).ignoresSafeArea()
                                renderActiveGame(score: $p1Score, progressText: $p1Progress, zone: .leftPlayer)
                            }
                            Rectangle().fill(Color.white).frame(width: 4).ignoresSafeArea()
                            ZStack {
                                Color.red.opacity(0.15).ignoresSafeArea()
                                renderActiveGame(score: $p2Score, progressText: $p2Progress, zone: .rightPlayer)
                            }
                        }
                    } else {
                        renderActiveGame(score: $p1Score, progressText: $p1Progress, zone: .solo)
                    }
                }
                
                // 🎨 THE UNIVERSAL HUD OVERLAY
                universalGameHUD
                
                // ⏸️ THE PAUSE MENU
                if director.isPaused && !showInstruction {
                    pauseMenuOverlay
                }
                
                // 🛑 THE BIG INSTRUCTION OVERLAY (Tap anywhere to skip!)
                if showInstruction {
                    InstructionOverlay(
                        actionWord: getActionWord(),
                        description: getInstruction(),
                        videoFilename: getVideoFilename(),
                        onSkip: skipInstruction
                    )
                    .id("\(director.currentRoundIndex)-\(director.currentGame)")
                    .transition(.opacity)
                    .zIndex(100) // Forces it to the very top!
                }
            }
        }
        .onAppear {
            director.start(rounds: rounds)
            triggerInstruction() // Fire instruction on round 1
        }
        // Fire instruction every time a new round starts
        .onChange(of: director.currentRoundIndex) { _ in
            triggerInstruction()
        }
    }
    
    // --- 🚀 HELPER: Timer & Overlay Logic ---
    private func triggerInstruction() {
        dismissInstructionWorkItem?.cancel()
        showInstruction = true
        director.pauseTimer() // Pause game so they don't lose time watching the video!
        
        // 1. Ambil nama video dan hitung durasinya
        let filename = getVideoFilename()
        let exactDuration = getVideoDuration(filename: filename)
        
        // 2. Tutup instruksi sesuai durasi video secara otomatis jika tidak di-skip
        let workItem = DispatchWorkItem { [weak director] in
            guard self.showInstruction else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                self.showInstruction = false
            }
            director?.resumeTimer()
        }
        self.dismissInstructionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + exactDuration, execute: workItem)
    }
    
    // ⏩ SKIP TUTORIAL: Instantly starts the game when player taps anywhere
    private func skipInstruction() {
        dismissInstructionWorkItem?.cancel()
        dismissInstructionWorkItem = nil
        guard showInstruction else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            showInstruction = false
        }
        director.resumeTimer() // Start the clock immediately!
    }
    
    // --- ⏱️ HELPER: Otomatis baca durasi file .mov ---
    private func getVideoDuration(filename: String?) -> Double {
        guard let filename = filename,
              let url = Bundle.main.url(forResource: filename, withExtension: "mov") else {
            return 2.5
        }
        
        let asset = AVURLAsset(url: url)
        return CMTimeGetSeconds(asset.duration)
    }
    
    // 🏗️ HELPER 1: The Switchboard
    @ViewBuilder
    private func renderActiveGame(score: Binding<Int>, progressText: Binding<String>, zone: PlayerZone) -> some View {
        switch director.currentGame {
        case .wipe: WipeScene(engine: engine, score: score, progressText: progressText, playerZone: zone) { _ in }
        case .fall: FallScene(engine: engine, score: score, progressText: progressText, playerZone: zone) { _ in }
        case .watering: WateringScene(engine: engine, score: score, progressText: progressText, playerZone: zone) { _ in }
        case .bubble: BubbleScene(engine: engine, score: score, progressText: progressText, playerZone: zone) { _ in }
        case .hotPotato: HotPotatoScene(engine: engine, score: score, progressText: progressText, playerZone: zone) { _ in }
        case .copycat: CopycatScene(engine: engine, score: score, progressText: progressText, playerZone: zone) { _ in }
        case .bonus: BonusScene(engine: engine, score: score, progressText: progressText, playerZone: zone) { _ in }
        }
    }
    
    // 🎨 HELPER 2: The Redesigned Universal Heads Up Display
    private var universalGameHUD: some View {
        ZStack(alignment: .top) {
            // Top Dark Gradient (For Scores & Timer)
            LinearGradient(
                colors: [Color.black.opacity(0.9), Color.black.opacity(0.4), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 250) // Made slightly taller to accommodate the text moving up
            .ignoresSafeArea(.all, edges: .top)
            
            // Bottom Dark Gradient (For Progress Pills)
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.3), Color.black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 150)
                .ignoresSafeArea(.all, edges: .bottom)
            }
            
            VStack(spacing: 0) {
                // --- TOP BAR: SCORES & TIMER ---
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        if isMultiplayer {
                            scoreBadge(title: "P1", score: p1Score, color: .blue, icon: "star.fill")
                            scoreBadge(title: "P2", score: p2Score, color: .red, icon: "star.fill")
                        } else {
                            scoreBadge(title: "SCORE", score: p1Score, color: .yellow, icon: "trophy.fill")
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 8) {
                        HStack(spacing: 4) {
                            ForEach(0..<director.totalRounds, id: \.self) { index in
                                Capsule()
                                    .fill(index <= director.currentRoundIndex ? Color.yellow : Color.white.opacity(0.3))
                                    .frame(width: 15, height: 6)
                            }
                        }
                        
                        GeometryReader { barGeo in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Color.white.opacity(0.2)).cornerRadius(8)
                                Rectangle()
                                    .fill(director.timeRemaining <= 2.0 ? Color.red : Color.green)
                                    .cornerRadius(8)
                                    .frame(width: max(0, barGeo.size.width * (director.timeRemaining / director.currentGame.timeLimit)))
                                    .animation(.linear(duration: 0.1), value: director.timeRemaining)
                                
                                HStack {
                                    Spacer()
                                    Text(String(format: "%.1f", max(0, director.timeRemaining)))
                                        .font(.system(size: 16, weight: .black, design: .monospaced))
                                        .foregroundColor(.white)
                                        .shadow(color: .black, radius: 2)
                                        .padding(.trailing, 8)
                                }
                            }
                        }
                        .frame(width: 180, height: 24)
                    }
                    .padding(.trailing, 15)
                    
                    Button(action: { director.pauseTimer() }) {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 45))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 5)
                    }
                }
                .padding(.horizontal, 25)
                .padding(.top, 5)
                
                // --- UPPER AREA: BIG ACTION WORD & INSTRUCTION ---
                VStack(spacing: 12) {
                    Text(getActionWord())
                        .font(.system(size: 70, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .orange, radius: 15)
                        .rotationEffect(.degrees(-3))
                    
                    // ⬆️ MOVED HERE: INSTRUCTIONS
                    Text(getInstruction())
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 25)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.3), lineWidth: 1))
                        .shadow(color: .black.opacity(0.3), radius: 10)
                }
                .padding(.top, 10) // Small push down from the top bar
                
                Spacer() // Pushes everything below this to the bottom
                
                // --- BOTTOM AREA: PROGRESS PILLS ---
                HStack {
                    Spacer()
                    if isMultiplayer {
                        HStack(spacing: 60) {
                            if !p1Progress.isEmpty { progressPill(text: p1Progress, color: .blue) }
                            if !p2Progress.isEmpty { progressPill(text: p2Progress, color: .red) }
                        }
                    } else {
                        if !p1Progress.isEmpty { progressPill(text: p1Progress, color: .orange) }
                    }
                    Spacer()
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    // --- UI HELPERS & LOGIC ---
    private func getVideoFilename() -> String? {
        switch director.currentGame {
        case .wipe: return "Wave_Recording"       // Waving hand = wiping window
        case .fall: return "DJ_Recording"         // Moving hands left & right = sliding fruit basket
        case .watering: return "Pinch_Recording"  // Pinching fingers = pinching & pouring watering can
        case .bubble: return "Tap_Recording"      // Finger tap = popping bubbles
        case .hotPotato: return "Wave_Recording"  // Hand swat = slapping durian
        case .copycat: return "Clap_Recording"    // Clapping hands = TOS push-hand pose
        case .bonus: return "67_Recording"        // Alternating arm pumps = 67 redemption
        }
    }

    private func scoreBadge(title: String, score: Int, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(color)
            Text("\(title): \(score)")
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Capsule().fill(.ultraThinMaterial).environment(\.colorScheme, .dark))
        .overlay(Capsule().stroke(color.opacity(0.8), lineWidth: 2))
        .shadow(color: color.opacity(0.3), radius: 5)
    }
    
    private func progressPill(text: String, color: Color) -> some View {
        Text(text)
            .font(.title2.bold())
            .foregroundColor(color)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .cornerRadius(25) // Made slightly rounder to look like a progress bubble
            .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
    }
    
    private func getActionWord() -> String {
        switch director.currentGame {
        case .wipe: return "WIPE THE WINDOW!"
        case .fall: return "CATCH THE FRUITS!"
        case .watering: return "WATER THE GARDEN!"
        case .bubble: return "POP THE BUBBLES!"
        case .hotPotato: return "HOT POTATO!"
        case .copycat: return "COPYCAT POSE!"
        case .bonus: return "67 REDEMPTION!"
        }
    }
    
    private func getInstruction() -> String {
        switch director.currentGame {
        case .wipe: return "WIPE your hand across the screen to clean the window!"
        case .fall: return "SLIDE your basket left and right to catch the falling fruits!"
        case .watering: return "PINCH and TILT your watering can to bloom the plants!"
        case .bubble: return "TAP and POP the floating bubbles with your fingers!"
        case .hotPotato: return "SWAT the hot durian before it burns you!"
        case .copycat: return "MATCH the hand poses shown on screen!"
        case .bonus: return "ALTERNATE PUMPING your arms up and down!"
        }
    }
    
    private var pauseMenuOverlay: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 30) {
                Text("PAUSED").font(.system(size: 60, weight: .black, design: .rounded)).foregroundColor(.white).padding(.bottom, 20)
                Button(action: { director.resumeTimer() }) {
                    Text("▶️ RESUME").font(.title.bold()).foregroundColor(.white).frame(width: 250).padding().background(Color.blue).cornerRadius(15)
                }
                Button(action: { director.forceEndGame() }) {
                    Text("🛑 END GAME").font(.title.bold()).foregroundColor(.white).frame(width: 250).padding().background(Color.red).cornerRadius(15)
                }
            }
        }
    }
    
    private func resetGame() {
        p1Score = 0
        p2Score = 0
        director.start(rounds: rounds)
    }
}
