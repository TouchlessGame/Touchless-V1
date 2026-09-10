import SwiftUI

// 1. The Dynamic Drill Model
struct DrillTarget: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var radius: CGFloat
    var isDrilled: Bool = false
}

// 💥 NEW: The Decal Model to hold our explosion coordinates
struct DrillDecal: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
}

struct DrillScene: View {
    @ObservedObject var engine: TrackingEngine
    @Binding var score: Int
    @Binding var progressText: String
    
    var playerZone: PlayerZone = .solo
    var onComplete: (Bool) -> Void
    
    @State private var drillSpots: [DrillTarget] = []
    @State private var totalDrilled: Int = 0
    @State private var isShaking: Bool = false
    
    // 💥 NEW: State to hold active explosions
    @State private var activeDecals: [DrillDecal] = []
    
    let maxSpotsOnScreen = 4
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 2. Draw the Drill Spots
                ForEach(drillSpots) { spot in
                    ZStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: spot.radius * 2, height: spot.radius * 2)
                            .shadow(color: .orange.opacity(0.8), radius: 8)
                        
                        Circle()
                            .stroke(Color.black, lineWidth: 4)
                            .frame(width: spot.radius * 1.5, height: spot.radius * 1.5)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: spot.radius * 0.8, weight: .black))
                            .foregroundColor(.black)
                    }
                    .position(x: spot.x * geo.size.width, y: spot.y * geo.size.height)
                    .rotationEffect(.degrees(isShaking ? 8 : -8))
                    .animation(
                        .easeInOut(duration: 0.05).repeatForever(autoreverses: true),
                        value: isShaking
                    )
                }
                
                // 💥 NEW: Draw the Explosions!
                ForEach(activeDecals) { decal in
                    Text("💥")
                        .font(.system(size: 80))
                        .position(x: decal.x * geo.size.width, y: decal.y * geo.size.height)
                        // Applies our custom pop-and-fade animation below
                        .modifier(ExplosionAnimationModifier())
                }
            }
            .onAppear {
                isShaking = true
                for _ in 0..<maxSpotsOnScreen {
                    drillSpots.append(generateRandomSpot())
                }
                progressText = "DRILLED: \(totalDrilled)"
            }
            .onChange(of: engine.hands) {
                checkDrills(in: geo.size)
            }
        }
    }
    
    private func generateRandomSpot() -> DrillTarget {
        return DrillTarget(
            x: CGFloat.random(in: 0.20...0.80),
            y: CGFloat.random(in: 0.35...0.70),
            radius: CGFloat.random(in: 35...65)
        )
    }
    
    private func checkDrills(in size: CGSize) {
        let validHands = engine.hands.filter {
            CoordinateMapper.belongsToZone(rawX: $0.indexTip.x, zone: playerZone)
        }
        
        var newSpots = drillSpots
        var drilledCountThisFrame = 0
        
        for hand in validHands {
            let handPoint = CoordinateMapper.localPoint(rawPoint: hand.indexTip, zone: playerZone, screenSize: size)
            
            for i in newSpots.indices {
                let spotX = newSpots[i].x * size.width
                let spotY = newSpots[i].y * size.height
                let distance = hypot(handPoint.x - spotX, handPoint.y - spotY)
                
                if distance < (newSpots[i].radius + 40) && !newSpots[i].isDrilled {
                    newSpots[i].isDrilled = true
                    drilledCountThisFrame += 1
                    
                    // 💥 NEW: Spawn the explosion decal exactly where the target was!
                    let decal = DrillDecal(x: newSpots[i].x, y: newSpots[i].y)
                    activeDecals.append(decal)
                    
                    // Automatically clean up the decal after half a second
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        activeDecals.removeAll { $0.id == decal.id }
                    }
                }
            }
        }
        
        if drilledCountThisFrame > 0 {
            AudioManager.shared.playSFX("drill")
            
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                totalDrilled += drilledCountThisFrame
                score += (10 * drilledCountThisFrame)
                progressText = "DRILLED: \(totalDrilled)"
                
                newSpots.removeAll { $0.isDrilled }
                
                for _ in 0..<drilledCountThisFrame {
                    newSpots.append(generateRandomSpot())
                }
                
                drillSpots = newSpots
            }
        }
    }
}

// 💥 NEW: The custom animation magic
// This makes the emoji scale up quickly, then fade out and expand
struct ExplosionAnimationModifier: ViewModifier {
    @State private var scale: CGFloat = 0.2
    @State private var opacity: Double = 1.0
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                // 1. Pop in fast
                withAnimation(.easeOut(duration: 0.15)) {
                    scale = 1.3
                }
                // 2. Fade out and expand slightly
                withAnimation(.easeIn(duration: 0.35).delay(0.15)) {
                    opacity = 0.0
                    scale = 1.6
                }
            }
    }
}

// 🔧 PREVIEW SUPPORT
struct DrillScene_Previews: PreviewProvider {
    static var previews: some View {
        DrillScene(
            engine: TrackingEngine(),
            score: .constant(0),
            progressText: .constant("DRILLED: 0"),
            onComplete: { _ in }
        )
        .background(Color.black)
    }
}
