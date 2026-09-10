import SwiftUI
import AVFoundation

// 🔧 A cleaner list of scenes to test
enum DebugScene: String, CaseIterable {
    case wipe = "🧽 WIPE WINDOW!"
    case fall = "🍎 CATCH FRUITS!"
    case watering = "🌱 WATER PLANT!"
    case bubble = "🫧 POP BUBBLES!"
    case hotPotato = "🥔 HOT POTATO!"
    case copycat = "🫸🫷 COPYCAT POSE!"
    case bonus = "6️⃣7️⃣ 67 BONUS!"
}

struct DebugTrackerView: View {
    @ObservedObject var engine: TrackingEngine
    var onExit: () -> Void
    
    // Default immediately to Wipe for testing
    @State private var selectedScene: DebugScene = .wipe
    
    // 🧍‍♂️ Player 1 States
    @State private var mockScore: Int = 0
    @State private var winCount: Int = 0
    @State private var p1Progress: String = "" // Pipeline Catcher P1
    
    // ⚔️ Player 2 States (Multiplayer)
    @State private var isMultiplayerMode: Bool = false
    @State private var p2Score: Int = 0
    @State private var p2WinCount: Int = 0
    @State private var p2Progress: String = "" // Pipeline Catcher P2
    
    // 🛑 State to control the instruction overlay
    @State private var showInstruction: Bool = true
    @State private var dismissInstructionWorkItem: DispatchWorkItem? = nil
    
    var body: some View {
        ZStack {
            // ==========================================
            // 1. THE STAGE (Only active when tutorial is dismissed!)
            // ==========================================
            if !showInstruction {
                if isMultiplayerMode {
                    // ⚔️ SPLIT SCREEN
                    HStack(spacing: 0) {
                        ZStack {
                            Color.blue.opacity(0.15).ignoresSafeArea()
                            renderScene(for: selectedScene, score: $mockScore, progressText: $p1Progress, wins: $winCount, zone: .leftPlayer)
                        }
                        Rectangle().fill(Color.white).frame(width: 4).ignoresSafeArea()
                        ZStack {
                            Color.red.opacity(0.15).ignoresSafeArea()
                            renderScene(for: selectedScene, score: $p2Score, progressText: $p2Progress, wins: $p2WinCount, zone: .rightPlayer)
                        }
                    }
                } else {
                    // 🧍‍♂️ SOLO MODE
                    renderScene(for: selectedScene, score: $mockScore, progressText: $p1Progress, wins: $winCount, zone: .solo)
                }
            }
            
            // ==========================================
            // 2. THE BEAUTIFUL SANDBOX HUD
            // ==========================================
            sandboxHUD
            
            // ==========================================
            // 3. 🛑 THE INSTRUCTION OVERLAY (Tap anywhere to skip!)
            // ==========================================
            if showInstruction {
                InstructionOverlay(
                    actionWord: getActionWord(for: selectedScene),
                    description: getInstruction(for: selectedScene),
                    videoFilename: getVideoFilename(for: selectedScene),
                    onSkip: skipInstruction
                )
                .id(selectedScene)
                .transition(.opacity)
                .zIndex(100) // Forces it to the very top!
            }
        }
        .onAppear {
            triggerInstruction()
        }
        // Reset everything AND trigger instruction when swapping games or modes
        .onChange(of: selectedScene) {
            resetSandboxStates()
            triggerInstruction()
        }
        .onChange(of: isMultiplayerMode) {
            resetSandboxStates()
            triggerInstruction()
        }
    }
    
    // --- 🚀 HELPER: Instruction Trigger Logic ---
    private func triggerInstruction() {
        dismissInstructionWorkItem?.cancel()
        showInstruction = true
        
        // 1. Ambil nama file videonya
        let filename = getVideoFilename(for: selectedScene)
        
        // 2. Minta sistem menghitung durasi persisnya
        let exactDuration = getVideoDuration(filename: filename)
        
        // 3. Gunakan durasi aslinya untuk menutup overlay otomatis jika tidak di-skip
        let workItem = DispatchWorkItem {
            guard self.showInstruction else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                self.showInstruction = false
            }
        }
        self.dismissInstructionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + exactDuration, execute: workItem)
    }
    
    // ⏩ SKIP TUTORIAL: Instantly starts the scene when player taps anywhere
    private func skipInstruction() {
        dismissInstructionWorkItem?.cancel()
        dismissInstructionWorkItem = nil
        guard showInstruction else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            showInstruction = false
        }
    }
    
    private func getVideoDuration(filename: String?) -> Double {
        // Kalau videonya tidak ada (nil), fallback ke 2.5 detik
        guard let filename = filename,
              let url = Bundle.main.url(forResource: filename, withExtension: "mov") else {
            return 2.5
        }
        
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        
        // Tambahkan sedikit buffer (0.2 detik) agar transisinya tidak memotong akhir video
        return duration + 0.2
    }
    
    // 🎨 THE REDESIGNED DEBUG HUD
    private var sandboxHUD: some View {
        ZStack(alignment: .top) {
            
            // 🛡️ GRADIENT SAFE ZONES (Top & Bottom for readability)
            VStack {
                LinearGradient(colors: [Color.black.opacity(0.85), Color.black.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 250) // Taller to fit instructions
                    .ignoresSafeArea(.all, edges: .top)
                Spacer()
                LinearGradient(colors: [.clear, Color.black.opacity(0.6), Color.black.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 150)
                    .ignoresSafeArea(.all, edges: .bottom)
            }
            
            VStack(spacing: 0) {
                
                // --- 1. TOP BAR: DEBUG CONTROLS ---
                HStack {
                    // EXIT BUTTON
                    Button(action: onExit) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("EXIT")
                        }
                        .font(.headline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.8))
                        .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    // SCENE PICKER
                    Picker("Test Scene", selection: $selectedScene) {
                        ForEach(DebugScene.allCases, id: \.self) { scene in
                            Text(scene.rawValue).tag(scene)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.7)))
                    .foregroundColor(.white)
                    .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    
                    Spacer()
                    
                    // MULTIPLAYER TOGGLE
                    Toggle("VS MODE", isOn: $isMultiplayerMode)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .font(.headline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.black.opacity(0.7)))
                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                        .frame(width: 180)
                }
                .padding(.horizontal, 30)
                .padding(.top, 10)
                
                // --- 2. UPPER AREA: BIG ACTION WORD & INSTRUCTION ---
                VStack(spacing: 12) {
                    Text(getActionWord(for: selectedScene))
                        .font(.system(size: 70, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .orange, radius: 15)
                        .rotationEffect(.degrees(-3))
                    
                    // ⬆️ MOVED UP: INSTRUCTION TEXT
                    Text(getInstruction(for: selectedScene))
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
                .padding(.top, 10)
                
                Spacer() // Keeps the center clear!
                
                // --- 3. BOTTOM: PROGRESS PILLS & SCORES ---
                ZStack(alignment: .bottom) {
                    
                    // LEFT CORNER: P1 SCORES
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            scoreBadge(title: "SCORE", score: mockScore, color: .blue, icon: "star.fill")
                        }
                        Spacer()
                    }
                    
                    // RIGHT CORNER: P2 SCORES
                    if isMultiplayerMode {
                        HStack {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 8) {
                                scoreBadge(title: "SCORE", score: p2Score, color: .red, icon: "star.fill")
                            }
                        }
                    }
                    
                    // ⬇️ MOVED DOWN: PROGRESS PILLS
                    HStack {
                        Spacer()
                        if isMultiplayerMode {
                            HStack(spacing: 60) {
                                if !p1Progress.isEmpty { progressPill(text: p1Progress, color: .blue) }
                                if !p2Progress.isEmpty { progressPill(text: p2Progress, color: .red) }
                            }
                        } else {
                            if !p1Progress.isEmpty { progressPill(text: p1Progress, color: .orange) }
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
    }
    
    // 🏗️ HELPER: Renders the active game
    @ViewBuilder
    private func renderScene(for scene: DebugScene, score: Binding<Int>, progressText: Binding<String>, wins: Binding<Int>, zone: PlayerZone) -> some View {
        switch scene {
        case .wipe: WipeScene(engine: engine, score: score, progressText: progressText, playerZone: zone) { _ in wins.wrappedValue += 1 }
        case .fall: FallScene(engine: engine, score: score, progressText: progressText, playerZone: zone) { _ in wins.wrappedValue += 1 }
        case .watering: WateringScene(engine: engine, score: score, progressText: progressText, playerZone: zone) { _ in wins.wrappedValue += 1 }
        case .bubble: BubbleScene(engine: engine, score: score, progressText: progressText, playerZone: zone) { _ in wins.wrappedValue += 1 }
        case .hotPotato: HotPotatoScene(engine: engine, score: score, progressText: progressText, playerZone: zone) { _ in wins.wrappedValue += 1 }
        case .copycat: CopycatScene(engine: engine, score: score, progressText: progressText, playerZone: zone) { _ in wins.wrappedValue += 1 }
        case .bonus: BonusScene(engine: engine, score: score, progressText: progressText, playerZone: zone) { _ in wins.wrappedValue += 1 }
        }
    }
    
    // 🧹 HELPER: Resets all variables
    private func resetSandboxStates() {
        mockScore = 0
        winCount = 0
        p1Progress = ""
        p2Score = 0
        p2WinCount = 0
        p2Progress = ""
    }
    
    // ==========================================
    // 🎨 UI & LOGIC HELPERS (Mirrored from GamePageView)
    // ==========================================
    
    private func scoreBadge(title: String, score: Int, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(color)
            Text("\(title): \(score)")
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
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
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
    }
    
    private func getActionWord(for scene: DebugScene) -> String {
        switch scene {
        case .wipe: return "WIPE THE WINDOW!"
        case .fall: return "CATCH THE FRUITS!"
        case .watering: return "WATER THE GARDEN!"
        case .bubble: return "POP THE BUBBLES!"
        case .hotPotato: return "HOT POTATO!"
        case .copycat: return "COPYCAT POSE!"
        case .bonus: return "67 REDEMPTION!"
        }
    }
    
    private func getInstruction(for scene: DebugScene) -> String {
        switch scene {
        case .wipe: return "WIPE your hand across the screen to clean the window!"
        case .fall: return "SLIDE your basket left and right to catch the falling fruits!"
        case .watering: return "PINCH and TILT your watering can to bloom the plants!"
        case .bubble: return "TAP and POP the floating bubbles with your fingers!"
        case .hotPotato: return "SWAT the hot durian before it burns you!"
        case .copycat: return "MATCH the hand poses shown on screen!"
        case .bonus: return "ALTERNATE PUMPING your arms up and down!"
        }
    }
    
    private func getVideoFilename(for scene: DebugScene) -> String? {
        switch scene {
        case .wipe: return "Wave_Recording"       // Waving hand = wiping window
        case .fall: return "DJ_Recording"         // Moving hands left & right = sliding fruit basket
        case .watering: return "Pinch_Recording"  // Pinching fingers = pinching & pouring watering can
        case .bubble: return "Tap_Recording"      // Finger tap = popping bubbles
        case .hotPotato: return "Wave_Recording"  // Hand swat = slapping durian
        case .copycat: return "Clap_Recording"    // Clapping hands = TOS push-hand pose
        case .bonus: return "67_Recording"        // Alternating arm pumps = 67 redemption
        }
    }
}
