import SwiftUI

struct StompScene: View {
    @ObservedObject var engine: TrackingEngine
    @Binding var score: Int
    @Binding var progressText: String // ⬅️ THE NEW DATA PIPELINE
    
    var playerZone: PlayerZone = .solo
    var onComplete: (Bool) -> Void
    
    @State private var hitCount: Int = 0
    @State private var isReady: Bool = true
    @State private var flashColor: Color = .red.opacity(0.4)
    
    let stompLine: CGFloat = 0.75
    let resetLine: CGFloat = 0.60
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. SPATIAL VISUALS ONLY (No Text HUD!)
                // We keep the rectangle because the player needs to see the physical 'hit zone'
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(flashColor)
                        .frame(height: geo.size.height * (1.0 - stompLine))
                }
            }
            .onChange(of: engine.hands) {
                checkStompLogic()
            }
            .onAppear {
                // Initialize the text immediately when the scene loads
                progressText = "STOMPS: \(hitCount)"
            }
        }
    }
    
    private func checkStompLogic() {
        let validHands = engine.hands.filter { CoordinateMapper.belongsToZone(rawX: $0.indexTip.x, zone: playerZone) }
        
        var lowestFingerY: CGFloat = 0.0
        var highestFingerY: CGFloat = 1.0
        
        for hand in validHands {
            lowestFingerY = max(lowestFingerY, hand.indexTip.y)
            highestFingerY = min(highestFingerY, hand.indexTip.y)
        }
        
        if highestFingerY < resetLine && !isReady {
            isReady = true
            flashColor = .red.opacity(0.4)
        }
        
        if lowestFingerY > stompLine && isReady {
            triggerStomp()
        }
    }
    
    private func triggerStomp() {
        isReady = false
        AudioManager.shared.playSFX("stomp")
        
        flashColor = .green.opacity(0.6)
        hitCount += 1
        score += 15
        
        // 🚀 PIPELINE UPDATE: Send the new text up to GamePageView!
        progressText = "STOMPS: \(hitCount)"
    }
}
