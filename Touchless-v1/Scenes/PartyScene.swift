import SwiftUI

// Used to track which side of the screen they need to wave to next
enum PartySide {
    case left, right
}

struct PartyScene: View {
    // 🔧 STANDARD CONTRACT
    @ObservedObject var engine: TrackingEngine
    @Binding var score: Int
    @Binding var progressText: String // ⬅️ THE NEW DATA PIPELINE
    
    var playerZone: PlayerZone = .solo
    var onComplete: (Bool) -> Void
    
    // 🔧 Infinite Game State
    @State private var hits: Int = 0
    @State private var currentSide: PartySide = .left
    @State private var bgColor: Color = .clear
    
    // 🪩 Disco colors for when they hit a zone
    let partyColors: [Color] = [.purple, .blue, .green, .red, .orange, .cyan]
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. The Disco Background Filter (Flashes on hit)
                bgColor.ignoresSafeArea()
                
                // 2. The Target Zones (No Text HUD, just visual targets!)
                HStack(spacing: 0) {
                    
                    // LEFT HIT ZONE
                    ZStack {
                        Rectangle()
                            .fill(currentSide == .left ? Color.white.opacity(0.15) : Color.clear)
                        
                        // Pulsing Target Ring
                        Circle()
                            .stroke(Color.white.opacity(currentSide == .left ? 0.6 : 0.0), lineWidth: 6)
                            .frame(width: 80, height: 80)
                            .scaleEffect(currentSide == .left ? 1.1 : 0.8)
                            .animation(currentSide == .left ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true) : .default, value: currentSide)
                    }
                    .frame(width: geo.size.width / 3)
                    
                    Spacer() // KEEPS THE CENTER CLEAR!
                    
                    // RIGHT HIT ZONE
                    ZStack {
                        Rectangle()
                            .fill(currentSide == .right ? Color.white.opacity(0.15) : Color.clear)
                        
                        // Pulsing Target Ring
                        Circle()
                            .stroke(Color.white.opacity(currentSide == .right ? 0.6 : 0.0), lineWidth: 6)
                            .frame(width: 80, height: 80)
                            .scaleEffect(currentSide == .right ? 1.1 : 0.8)
                            .animation(currentSide == .right ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true) : .default, value: currentSide)
                    }
                    .frame(width: geo.size.width / 3)
                }
            }
            // 4. The Logic Loop
            .onChange(of: engine.hands) {
                checkWaveLogic(in: geo.size)
            }
            .onAppear {
                // 🚀 Initialize the pipeline text!
                progressText = "WAVES: \(hits)"
            }
        }
    }
    
    private func checkWaveLogic(in size: CGSize) {
        // 🛑 MULTIPLAYER FILTER: Ignore the other player's hands
        let validHands = engine.hands.filter {
            CoordinateMapper.belongsToZone(rawX: $0.indexTip.x, zone: playerZone)
        }
        
        for hand in validHands {
            // 🎯 UNIVERSAL LENS: Map the raw camera X to this specific UI view
            let localPoint = CoordinateMapper.localPoint(rawPoint: hand.indexTip, zone: playerZone, screenSize: size)
            
            // Convert pixels back to a percentage (0.0 to 1.0) for the local UI bounds
            let localX = localPoint.x / size.width
            
            // 3. HIT DETECTION: Check if they reached the active 33% zone
            if currentSide == .left && localX < 0.35 {
                triggerHit(nextSide: .right)
                break // Stop checking other hands this frame to prevent double-hits
            } else if currentSide == .right && localX > 0.65 {
                triggerHit(nextSide: .left)
                break
            }
        }
    }
    
    private func triggerHit(nextSide: PartySide) {
        // 🔊 Play the whoosh instantly
        AudioManager.shared.playSFX("whoosh")
        
        // 1. Instantly swap the target side so they have to wave back
        currentSide = nextSide
        
        // 2. Add points & update pipeline!
        hits += 1
        score += 20
        progressText = "WAVES: \(hits)" // 🚀 Feed the dashboard
        
        // 3. Disco Filter Logic!
        let newColor = partyColors.randomElement() ?? .purple
        withAnimation(.easeIn(duration: 0.05)) {
            // Apply lowered transparency (opacity) to act as a camera filter
            bgColor = newColor.opacity(0.5)
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.05)) {
            // Fade back to completely clear
            bgColor = .clear
        }
    }
}

// 🔧 PREVIEW SUPPORT
struct PartyScene_Previews: PreviewProvider {
    static var previews: some View {
        PartyScene(
            engine: TrackingEngine(),
            score: .constant(100),
            progressText: .constant("WAVES: 0"),
            onComplete: { _ in }
        )
        .background(Color.black)
    }
}
