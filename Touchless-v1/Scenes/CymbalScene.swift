import SwiftUI

struct CymbalScene: View {
    @ObservedObject var engine: TrackingEngine
    @Binding var score: Int
    @Binding var progressText: String // ⬅️ THE NEW DATA PIPELINE
    
    var playerZone: PlayerZone = .solo
    var onComplete: (Bool) -> Void
    
    @State private var currentCrashes: Int = 0
    @State private var lastDistance: CGFloat = 1000
    @State private var isClappedThisFrame: Bool = false
    @State private var flashColor: Color = .clear
    @State private var leftCymbalPos: CGPoint = CGPoint(x: 100, y: 300)
    @State private var rightCymbalPos: CGPoint = CGPoint(x: 300, y: 300)
    
    let crashThreshold: CGFloat = 120.0
    let minimumClapVelocity: CGFloat = 40.0
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. Flash Background
                flashColor.ignoresSafeArea()
                
                // 2. The Spatial Cymbals (No Text HUD!)
                drawCymbal(color: .orange, pos: leftCymbalPos, size: geo.size.width * 0.35)
                drawCymbal(color: .yellow, pos: rightCymbalPos, size: geo.size.width * 0.35)
            }
            .onChange(of: engine.hands) {
                updateCymbalLogic(in: geo.size)
            }
            .onAppear {
                // 🚀 Initialize the pipeline text!
                progressText = "CLAPS: \(currentCrashes)"
            }
        }
    }
    
    private func drawCymbal(color: Color, pos: CGPoint, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(gradient: Gradient(colors: [color.opacity(0.8), Color.black.opacity(0.2)]), center: .center, startRadius: 5, endRadius: size/2))
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 4))
            Circle().fill(Color.black.opacity(0.5)).frame(width: size * 0.2)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(isClappedThisFrame ? 5 : 0))
        .position(pos)
    }
    
    private func updateCymbalLogic(in size: CGSize) {
        
        // 🛑 Use the Universal Filter!
        let validHands = engine.hands.filter { hand in
            CoordinateMapper.belongsToZone(rawX: hand.indexTip.x, zone: playerZone)
        }
        
        // Check validHands instead of engine.hands
        guard validHands.count >= 2 else {
            isClappedThisFrame = false
            return
        }
        
        // 🎯 Use the Universal Lens to get exact pixels!
        let leftHandPoint = CoordinateMapper.localPoint(rawPoint: validHands[0].indexTip, zone: playerZone, screenSize: size)
        let rightHandPoint = CoordinateMapper.localPoint(rawPoint: validHands[1].indexTip, zone: playerZone, screenSize: size)
        
        withAnimation(.interactiveSpring(response: 0.1, dampingFraction: 0.6)) {
            leftCymbalPos = leftHandPoint
            rightCymbalPos = rightHandPoint
        }
        
        // CLAP DETECTION MATH
        let dx = leftHandPoint.x - rightHandPoint.x
        let dy = leftHandPoint.y - rightHandPoint.y
        let currentDistance = hypot(dx, dy)
        let clapVelocity = lastDistance - currentDistance
        lastDistance = currentDistance
        
        if currentDistance < crashThreshold && clapVelocity > minimumClapVelocity {
            if !isClappedThisFrame { triggerCrasherHit() }
        } else if currentDistance > crashThreshold + 20 {
            isClappedThisFrame = false
        }
    }
    
    private func triggerCrasherHit() {
        isClappedThisFrame = true
        AudioManager.shared.playSFX("cymbals")
        
        withAnimation(.easeIn(duration: 0.05)) {
            flashColor = .green.opacity(0.3)
            currentCrashes += 1
            score += 25
            
            // 🚀 PIPELINE UPDATE: Send the new text to GamePageView!
            progressText = "CLAPS: \(currentCrashes)"
        }
        withAnimation(.easeOut(duration: 0.2).delay(0.05)) {
            flashColor = .clear
        }
    }
}

// 🔧 PREVIEW SUPPORT
struct CymbalScene_Previews: PreviewProvider {
    static var previews: some View {
        CymbalScene(
            engine: TrackingEngine(),
            score: .constant(100),
            progressText: .constant("CLAPS: 0"),
            onComplete: { _ in }
        )
        .background(Color.black)
    }
}
