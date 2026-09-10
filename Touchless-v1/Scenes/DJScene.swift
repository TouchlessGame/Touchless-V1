import SwiftUI

struct DJScene: View {
    // 🔧 STANDARD CONTRACT
    @ObservedObject var engine: TrackingEngine
    @Binding var score: Int
    @Binding var progressText: String // ⬅️ THE NEW DATA PIPELINE
    
    var playerZone: PlayerZone = .solo
    var onComplete: (Bool) -> Void
    
    // 🔧 Game State
    @State private var hypeLevel: CGFloat = 0.0
    @State private var previousPositions: [CGFloat] = []
    @State private var dropCount: Int = 0 // Tracks how many times they filled the bar
    @State private var isHandsPresent: Bool = false
    
    // 📐 The Math: Lowered to 4.0 so they can trigger multiple "Drops" in the 5-second time limit!
    let requiredHype: CGFloat = 4.0
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                
                // 1. THE DJ SETUP (Decks + Hypemeter)
                VStack(spacing: 40) {
                    
                    // A. The Visual DJ Decks
                    HStack(spacing: geo.size.width * 0.2) {
                        DJDeckView(hype: hypeLevel, isActive: isHandsPresent)
                        DJDeckView(hype: hypeLevel, isActive: isHandsPresent)
                    }
                    
                    // B. THE COLORFUL HYPEMETER IS BACK! 🌈
                    GeometryReader { barGeo in
                        ZStack(alignment: .leading) {
                            // Background Track
                            Rectangle()
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 24)
                            
                            // The Neon Fill
                            Rectangle()
                                .fill(LinearGradient(colors: [.purple, .cyan], startPoint: .leading, endPoint: .trailing))
                                .frame(width: min(barGeo.size.width, barGeo.size.width * (hypeLevel / requiredHype)), height: 24)
                                .shadow(color: .cyan.opacity(0.8), radius: hypeLevel > 1.0 ? 10 : 0) // Adds a neon glow as it fills!
                                .animation(.linear(duration: 0.1), value: hypeLevel)
                        }
                        .cornerRadius(12)
                        // A little border to make it pop
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.3), lineWidth: 1))
                    }
                    .frame(height: 24)
                    .padding(.horizontal, geo.size.width * 0.15) // Keep it nicely padded on the sides
                    
                }
                // Centered beautifully in the middle of the screen!
                .position(x: geo.size.width / 2, y: geo.size.height * 0.55)
            }
            .onChange(of: engine.hands) {
                checkScratchLogic()
            }
            .onAppear {
                // 🚀 Initialize the pipeline text!
                progressText = "DROPS: \(dropCount)"
            }
        }
    }
    
    private func checkScratchLogic() {
        // 🛑 MULTIPLAYER FILTER: Calculate this fresh every single frame!
        let validHands = engine.hands.filter {
            CoordinateMapper.belongsToZone(rawX: $0.indexTip.x, zone: playerZone)
        }
        
        // Update UI state
        isHandsPresent = (validHands.count >= 2)
        
        // 🚨 STRICT RULE: Math pauses if 2 hands are not visible on THEIR side
        guard validHands.count >= 2 else {
            previousPositions = [] // Reset the math so it doesn't glitch
            return
        }
        
        // 1. Get the X coordinates of both index fingers
        let currentPositions = validHands.prefix(2).map { $0.indexTip.x }.sorted()
        
        if previousPositions.count == 2 {
            // 2. Calculate "Delta" (How far did they move?)
            let leftDelta = abs(currentPositions[0] - previousPositions[0])
            let rightDelta = abs(currentPositions[1] - previousPositions[1])
            
            // 3. Add movement to the internal math!
            hypeLevel += (leftDelta + rightDelta)
            
            // 4. Score Attack Loop!
            if hypeLevel >= requiredHype {
                triggerBeatDrop()
            }
        }
        
        // Save current positions for the next frame's math
        previousPositions = currentPositions
    }
    
    private func triggerBeatDrop() {
        // 🔊 Sound Effect
        AudioManager.shared.playSFX("stomp") // Or whatever airhorn/bass drop sound you have!
        
        // Add points and reset the math so they can do it again!
        withAnimation(.spring()) {
            dropCount += 1
            score += 50
            hypeLevel = 0.0 // Instantly reset to 0
            previousPositions = []
            
            // 🚀 PIPELINE UPDATE: Send the new text to GamePageView!
            progressText = "DROPS: \(dropCount)"
        }
    }
}

// 🔧 Visual sub-view for the spinning records
struct DJDeckView: View {
    var hype: CGFloat
    var isActive: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black)
                .frame(width: 150, height: 150)
                .shadow(color: isActive ? .cyan : .clear, radius: 20)
            
            Circle()
                .stroke(Color.gray, lineWidth: 2)
                .frame(width: 100, height: 100)
            
            Circle()
                .fill(Color.red)
                .frame(width: 40, height: 40)
        }
        // The record physically spins faster the more you move your hands!
        .rotationEffect(.degrees(Double(hype * 180)))
        .opacity(isActive ? 1.0 : 0.5)
    }
}

// 🔧 PREVIEW SUPPORT
struct DJScene_Previews: PreviewProvider {
    static var previews: some View {
        DJScene(
            engine: TrackingEngine(),
            score: .constant(0),
            progressText: .constant("DROPS: 0"),
            onComplete: { _ in }
        )
        .background(Color.black)
    }
}
