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
    
    // 🛑 NEW: State for the instruction screen
    @State private var showInstruction: Bool = true
    
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
                // 🎮 STATE A: THE GAME IS RUNNING
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
                
                // 🎨 THE UNIVERSAL HUD OVERLAY
                universalGameHUD
                
                // ⏸️ THE PAUSE MENU
                if director.isPaused && !showInstruction {
                    pauseMenuOverlay
                }
                
                // 🛑 THE BIG INSTRUCTION OVERLAY
                if showInstruction {
                    InstructionOverlay(
                        actionWord: getActionWord(),
                        description: getInstruction(),
                        videoFilename: getVideoFilename()
                    )
                    .transition(.opacity)
                    .zIndex(100) // Forces it to the very top!
                }
            }
        }
        .onAppear {
            director.start(rounds: rounds)
            triggerInstruction() // Fire instruction on round 1
        }
        // Fire instruction every time the mini-game changes
        .onChange(of: director.currentGame) { _ in
            triggerInstruction()
        }
    }
    
    // --- 🚀 NEW HELPER: Timer & Overlay Logic ---
    private func triggerInstruction() {
        showInstruction = true
        director.pauseTimer() // Pause game so they don't lose time watching the video!
        
        // 1. Ambil nama video dan hitung durasinya
        let filename = getVideoFilename()
        let exactDuration = getVideoDuration(filename: filename)
        
        // 2. Tutup instruksi sesuai durasi video
        DispatchQueue.main.asyncAfter(deadline: .now() + exactDuration) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showInstruction = false
            }
            director.resumeTimer() // Start the 5-second clock tepat setelah video hilang!
        }
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
        case .stomp: StompScene(engine: engine, score: score, progressText: progressText, playerZone: zone) { _ in }
        case .drill: DrillScene(engine: engine, score: score, progressText: progressText, playerZone: zone) { _ in }
        case .party: PartyScene(engine: engine, score: score, progressText: progressText, playerZone: zone) { _ in }
        case .dj: DJScene(engine: engine, score: score, progressText: progressText, playerZone: zone) { _ in }
        case .cymbals: CymbalScene(engine: engine, score: score, progressText: progressText, playerZone: zone) { _ in }
        case .furniture: FurnitureScene(engine: engine, score: score, progressText: progressText, playerZone: zone) { _ in }
        case .bonus: BonusScene(engine: engine, score: score, progressText: progressText, playerZone: zone) { _ in }
        case .wipe: WipeScene(engine: engine, score: score, progressText: progressText, playerZone: zone) { _ in }
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
        case .stomp: return "Stomp_Recording"
        case .drill: return "Tap_Recording"
        case .party: return "Wave_Recording"
        case .dj: return "DJ_Recording"
        case .cymbals: return "Clap_Recording"
        case .furniture: return "Pinch_Recording"
        case .bonus: return "67_Recording"
        case .wipe: return "Wave_Recording"
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
        case .stomp: return "STOMP THE FLOOR!"
        case .drill: return "POWER DRILL!"
        case .party: return "IT'S A PARTY!"
        case .dj: return "DJ TIME!"
        case .cymbals: return "CYMBALS PRACTICE!"
        case .furniture: return "HOME RENO!"
        case .bonus: return "67 REDEMPTION!"
        case .wipe: return "WIPE THE WINDOW!"
        }
    }
    
    private func getInstruction() -> String {
        switch director.currentGame {
        case .stomp: return "STOMP your hands past the line!"
        case .drill: return "TAP the targets to drill holes"
        case .party: return "WAVE your hands to the targets!"
        case .dj: return "MOVE your hands left and right like a DJ!"
        case .cymbals: return "CLAP your hands together loudly!"
        case .furniture: return "PINCH the furniture and DRAG it away!"
        case .bonus: return "ALTERNATE PUMPING your arms up and down!"
        case .wipe: return "WIPE your cloth across the screen to clean the window!"
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
