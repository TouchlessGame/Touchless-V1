import SwiftUI

struct BonusScene: View {
    @ObservedObject var engine: TrackingEngine
    @Binding var score: Int
    @Binding var progressText: String // ⬅️ THE NEW DATA PIPELINE
    
    var playerZone: PlayerZone = .solo
    var onComplete: (Bool) -> Void
    
    // 🔧 Game State
    @State private var pumps: Int = 0
    @State private var leftIsDown: Bool = true
    @State private var rightIsDown: Bool = true
    @State private var flashColor: Color = .clear
    
    // 📐 THE FIXED MATH (Y: 0.0 is top, Y: 1.0 is bottom)
    // By setting these to 0.35 and 0.65, we leave a 30% empty gap in the middle!
    let liftLine: CGFloat = 0.50
    let resetLine: CGFloat = 0.65
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. Gold/Neon Flash Background
                flashColor.ignoresSafeArea()
                
                // 2. Visual Guide Lines
                VStack(spacing: 0) {
                    // TOP GREEN ZONE
                    Rectangle()
                        .fill(Color.green.opacity(0.3))
                        .frame(height: geo.size.height * liftLine)
                    
                    // THE GAP! (Because 35% + 35% is only 70%, the Spacer gets 30% of the screen!)
                    Spacer()
                    
                    // BOTTOM RED ZONE
                    Rectangle()
                        .fill(Color.red.opacity(0.3))
                        .frame(height: geo.size.height * (1.0 - resetLine))
                }
            }
            .onChange(of: engine.hands) {
                checkAlternatingPump()
            }
            .onAppear {
                // 🚀 Initialize the pipeline text!
                progressText = "67 PUMPS: \(pumps)"
            }
        }
    }
    
    private func checkAlternatingPump() {
        // 🛑 1. FILTER: Ignore the other player
        let validHands = engine.hands.filter { CoordinateMapper.belongsToZone(rawX: $0.indexTip.x, zone: playerZone) }
        
        // 2. Check validHands instead of engine.hands
        guard validHands.count >= 2 else { return }
        
        let hand1 = validHands[0]
        let hand2 = validHands[1]
        
        let leftHand = hand1.indexTip.x > hand2.indexTip.x ? hand1 : hand2
        let rightHand = hand1.indexTip.x > hand2.indexTip.x ? hand2 : hand1
        
        // Process Left Hand
        if leftHand.indexTip.y < liftLine && leftIsDown {
            leftIsDown = false
            triggerPump()
        } else if leftHand.indexTip.y > resetLine && !leftIsDown {
            leftIsDown = true
        }
        
        // Process Right Hand
        if rightHand.indexTip.y < liftLine && rightIsDown {
            rightIsDown = false
            triggerPump()
        } else if rightHand.indexTip.y > resetLine && !rightIsDown {
            rightIsDown = true
        }
    }
    
    private func triggerPump() {
        AudioManager.shared.playSFX("whoosh")
        
        withAnimation(.easeIn(duration: 0.05)) {
            pumps += 1
            score += 30
            flashColor = .yellow.opacity(0.4)
            
            // 🚀 PIPELINE UPDATE: Send the new text to GamePageView!
            progressText = "67 PUMPS: \(pumps)"
        }
        
        withAnimation(.easeOut(duration: 0.2).delay(0.05)) {
            flashColor = .clear
        }
    }
}

// 🔧 PREVIEW
struct BonusScene_Previews: PreviewProvider {
    static var previews: some View {
        BonusScene(
            engine: TrackingEngine(),
            score: .constant(500),
            progressText: .constant("67 PUMPS: 0"),
            onComplete: { _ in }
        )
        .background(Color.black)
    }
}
