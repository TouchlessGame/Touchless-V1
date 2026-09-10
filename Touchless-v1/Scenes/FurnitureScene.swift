import SwiftUI

struct FurnitureScene: View {
    // 🔧 STANDARD CONTRACT
    @ObservedObject var engine: TrackingEngine
    @Binding var score: Int
    @Binding var progressText: String // ⬅️ THE NEW DATA PIPELINE
    
    var playerZone: PlayerZone = .solo
    var onComplete: (Bool) -> Void
    
    // 🔧 Game State
    // ⬇️ Lowered the starting Y position to 0.65 to keep the camera and dashboard clear!
    @State private var chairLocalPosition: CGPoint = CGPoint(x: 0.5, y: 0.65)
    @State private var isGrabbed: Bool = false
    @State private var totalDistanceDragged: CGFloat = 0.0
    @State private var distanceToChair: CGFloat = 1.0
    
    // 📐 The Math Thresholds
    let pinchThreshold: CGFloat = 0.12
    let grabRadius: CGFloat = 0.25
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 🎨 1. THE AR CAMERA FILTER
                (isGrabbed ? Color.yellow : Color.orange)
                    .opacity(isGrabbed ? 0.3 : 0.15)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.3), value: isGrabbed)
                
                // 3. Objek Kursi yang Bisa Diseret (NO TEXT HUD!)
                ZStack {
                    // 🧲 Visual Feedback
                    Circle()
                        .fill(isGrabbed ? Color.yellow.opacity(0.5) : (distanceToChair < grabRadius ? Color.white.opacity(0.3) : Color.clear))
                        .frame(width: 120, height: 120)
                        .scaleEffect(isGrabbed ? 1.2 : 1.0)
                        .animation(.spring().repeatForever(autoreverses: true), value: isGrabbed)
                    
                    Text("🪑")
                        .font(.system(size: 80))
                }
                .position(
                    x: chairLocalPosition.x * geo.size.width,
                    y: chairLocalPosition.y * geo.size.height
                )
                .animation(.interactiveSpring(response: 0.1, dampingFraction: 0.8), value: chairLocalPosition)
            }
            .onChange(of: engine.hands) {
                checkPinchAndDrag(in: geo.size)
            }
            .onAppear {
                // 🚀 Initialize the pipeline text!
                progressText = "DRAGGED: \(Int(totalDistanceDragged))m"
            }
            .onDisappear {
                AudioManager.shared.forceStopScrape()
            }
        }
    }
    
    private func checkPinchAndDrag(in size: CGSize) {
        let validHands = engine.hands.filter {
            CoordinateMapper.belongsToZone(rawX: $0.indexTip.x, zone: playerZone)
        }
        
        var foundGrabThisFrame = false
        var closestHandDistance: CGFloat = 1.0
        
        for hand in validHands {
            let rawIndex = hand.indexTip
            let rawThumb = hand.thumbTip
            
            let pinchDistance = hypot(rawIndex.x - rawThumb.x, rawIndex.y - rawThumb.y)
            let isPinching = pinchDistance < pinchThreshold
            
            let localHandPoint = CoordinateMapper.localPoint(rawPoint: rawIndex, zone: playerZone, screenSize: size)
            let localHandX = localHandPoint.x / size.width
            let localHandY = localHandPoint.y / size.height
            
            let currentDistance = hypot(localHandX - chairLocalPosition.x, localHandY - chairLocalPosition.y)
            
            if currentDistance < closestHandDistance {
                closestHandDistance = currentDistance
            }
            
            if isPinching {
                if isGrabbed || currentDistance < grabRadius {
                    // 🔥 BERHASIL GRAB!
                    foundGrabThisFrame = true
                    
                    let dragDelta = hypot(localHandX - chairLocalPosition.x, localHandY - chairLocalPosition.y)
                    
                    if dragDelta > 0.005 {
                        AudioManager.shared.playScrapeOnce()
                        
                        totalDistanceDragged += (dragDelta * 100)
                        
                        // 🚀 PIPELINE UPDATE: Send the new text to the master dashboard!
                        progressText = "DRAGGED: \(Int(totalDistanceDragged))m"
                        
                        if totalDistanceDragged.truncatingRemainder(dividingBy: 10) < dragDelta * 100 {
                            score += 5
                        }
                    }
                    
                    // Pindahkan kursi
                    chairLocalPosition = CGPoint(x: localHandX, y: localHandY)
                    break
                }
            }
        }
        
        isGrabbed = foundGrabThisFrame
        distanceToChair = closestHandDistance
    }
}

// 🔧 PREVIEW SUPPORT
struct FurnitureScene_Previews: PreviewProvider {
    static var previews: some View {
        FurnitureScene(
            engine: TrackingEngine(),
            score: .constant(0),
            progressText: .constant("DRAGGED: 0m"),
            onComplete: { _ in }
        )
        .background(Color.black)
    }
}
