import SwiftUI
import AppKit

// 1. Available Fruit Types
enum FruitType: CaseIterable {
    case apple, banana, pear
    
    var assetName: String {
        switch self {
        case .apple: return "Fall - Apple"
        case .banana: return "Fall - Banana"
        case .pear: return "Fall - Pear"
        }
    }
    
    var emoji: String {
        switch self {
        case .apple: return "🍎"
        case .banana: return "🍌"
        case .pear: return "🍐"
        }
    }
    
    var points: Int {
        switch self {
        case .apple: return 20
        case .banana: return 25
        case .pear: return 30
        }
    }
}

// 2. Falling Fruit Item Model
struct FallingFruit: Identifiable {
    let id = UUID()
    let type: FruitType
    var x: CGFloat            // Relative X (0.1 to 0.9)
    var y: CGFloat            // Absolute pixel Y
    var speed: CGFloat        // Pixels per frame
    var rotation: Double
    var rotationSpeed: Double
    var isCaught: Bool = false
    var scale: CGFloat = 1.0
}

// 3. Sparkle Particle
struct FallSparkle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var emoji: String = "✨"
    var scale: CGFloat = 0.2
    var opacity: Double = 1.0
}

struct FallScene: View {
    // 🔧 STANDARD CONTRACT
    @ObservedObject var engine: TrackingEngine
    @Binding var score: Int
    @Binding var progressText: String
    
    var playerZone: PlayerZone = .solo
    var onComplete: (Bool) -> Void
    
    // 🍎 Fruit & Bag Game States
    @State private var fruits: [FallingFruit] = []
    @State private var sparkles: [FallSparkle] = []
    @State private var caughtCount: Int = 0
    @State private var bagPosition: CGPoint = CGPoint(x: 200, y: 500)
    @State private var isHandDetected: Bool = false
    @State private var isBagFilled: Bool = false
    @State private var bagTilt: Double = 0.0
    @State private var lastSpawnTime: Date = Date()
    
    // Cached SVGs
    @State private var emptyBagImage: NSImage? = nil
    @State private var filledBagImage: NSImage? = nil
    @State private var appleImage: NSImage? = nil
    @State private var bananaImage: NSImage? = nil
    @State private var pearImage: NSImage? = nil
    
    private let catchRadius: CGFloat = 80.0
    private let maxFruitsOnScreen: Int = 4
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ==========================================
                // 1. FALLING FRUITS
                // ==========================================
                ForEach(fruits) { fruit in
                    if !fruit.isCaught {
                        fruitImageView(for: fruit.type)
                            .frame(width: 85, height: 85)
                            .rotationEffect(.degrees(fruit.rotation))
                            .scaleEffect(fruit.scale)
                            .position(x: fruit.x * geo.size.width, y: fruit.y)
                            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                    }
                }
                
                // ==========================================
                // 3. CATCH SPARKLES
                // ==========================================
                ForEach(sparkles) { sparkle in
                    Text(sparkle.emoji)
                        .font(.system(size: 32))
                        .scaleEffect(sparkle.scale)
                        .opacity(sparkle.opacity)
                        .position(x: sparkle.x, y: sparkle.y)
                }
                
                // ==========================================
                // 4. HARVEST COLLECTION BAG (Tracks Hand)
                // ==========================================
                bagView
                    .position(bagPosition)
                    .rotationEffect(.degrees(bagTilt))
                    .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.75), value: bagPosition)
                    .opacity(isHandDetected ? 1.0 : 0.6)
            }
            .onAppear {
                loadAllSVGs()
                bagPosition = CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.75)
                progressText = "CAUGHT: \(caughtCount)"
            }
            // Continuous Physics & Spawning Loop (Runs smoothly via TimelineView)
            .background(
                TimelineView(.animation(minimumInterval: 0.033)) { timeline in
                    Color.clear
                        .onChange(of: timeline.date) {
                            updateFallingPhysics(in: geo.size)
                        }
                }
            )
            .onChange(of: engine.hands) {
                processHandTracking(in: geo.size)
            }
        }
    }
    
    // ==========================================
    // 🎨 ASSET VIEWS
    // ==========================================
    private func fruitImageView(for type: FruitType) -> some View {
        Group {
            if let img = imageForFruit(type) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Text(type.emoji)
                    .font(.system(size: 65))
            }
        }
    }
    
    private func imageForFruit(_ type: FruitType) -> NSImage? {
        switch type {
        case .apple: return appleImage
        case .banana: return bananaImage
        case .pear: return pearImage
        }
    }
    
    private var bagView: some View {
        ZStack {
            if isBagFilled, let filled = filledBagImage {
                Image(nsImage: filled)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 155, height: 155)
                    .shadow(color: .black.opacity(0.45), radius: 10, y: 6)
            } else if let empty = emptyBagImage {
                Image(nsImage: empty)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 150)
                    .shadow(color: .black.opacity(0.45), radius: 10, y: 6)
            } else {
                // Fallback basket shape
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.brown.opacity(0.85))
                        .frame(width: 130, height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.yellow, lineWidth: 3)
                        )
                    Text("🧺")
                        .font(.system(size: 55))
                }
            }
        }
    }
    
    private func loadAllSVGs() {
        emptyBagImage = loadSVG(named: "Fall - Empty Bag")
        filledBagImage = loadSVG(named: "Fall - Fruit Filled Bag")
        appleImage = loadSVG(named: "Fall - Apple")
        bananaImage = loadSVG(named: "Fall - Banana")
        pearImage = loadSVG(named: "Fall - Pear")
    }
    
    private func loadSVG(named name: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "svg"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        let fallbackPaths = [
            "Touchless-V1/Touchless-v1/Assets/game-assets/fall/\(name).svg",
            "Touchless-v1/Assets/game-assets/fall/\(name).svg"
        ]
        for path in fallbackPaths {
            if let img = NSImage(contentsOf: URL(fileURLWithPath: path)) {
                return img
            }
        }
        return nil
    }
    
    // ==========================================
    // 🖐️ HAND TRACKING
    // ==========================================
    private func processHandTracking(in size: CGSize) {
        let validHands = engine.hands.filter {
            CoordinateMapper.belongsToZone(rawX: $0.indexTip.x, zone: playerZone)
        }
        
        guard let primaryHand = validHands.first else {
            isHandDetected = false
            return
        }
        
        isHandDetected = true
        let trackingPoint = primaryHand.center != .zero ? primaryHand.center : primaryHand.indexTip
        
        // Accurate local point mapping with corrected Y and mirrored X
        let localPoint = CoordinateMapper.localPoint(rawPoint: trackingPoint, zone: playerZone, screenSize: size)
        
        let deltaX = localPoint.x - bagPosition.x
        bagTilt = Double(max(-20, min(20, deltaX * 0.4)))
        bagPosition = localPoint
    }
    
    // ==========================================
    // 🍏 FALLING PHYSICS & CATCH DETECTION
    // ==========================================
    private func updateFallingPhysics(in size: CGSize) {
        // 1. Spawn new fruits at controlled intervals
        let now = Date()
        let activeCount = fruits.filter { !$0.isCaught }.count
        if activeCount < maxFruitsOnScreen && now.timeIntervalSince(lastSpawnTime) > 0.85 {
            spawnNewFruit(in: size)
            lastSpawnTime = now
        }
        
        // 2. Move existing fruits downward
        for i in fruits.indices {
            guard !fruits[i].isCaught else { continue }
            
            fruits[i].y += fruits[i].speed
            fruits[i].rotation += fruits[i].rotationSpeed
            
            let fruitPixelX = fruits[i].x * size.width
            let fruitPixelY = fruits[i].y
            
            // Check collision with the collection bag
            let dist = hypot(fruitPixelX - bagPosition.x, fruitPixelY - (bagPosition.y - 20))
            if dist < catchRadius {
                catchFruit(at: i, pixelX: fruitPixelX, pixelY: fruitPixelY)
            }
        }
        
        // 3. Remove fruits that have fallen off-screen (past bottom)
        fruits.removeAll { $0.y > (size.height + 100) || ($0.isCaught && $0.scale <= 0.05) }
    }
    
    private func spawnNewFruit(in size: CGSize) {
        let type = FruitType.allCases.randomElement() ?? .apple
        let newFruit = FallingFruit(
            type: type,
            x: CGFloat.random(in: 0.12...0.88),
            y: CGFloat.random(in: -50 ... -10), // Emerge smoothly from off-screen top
            speed: CGFloat.random(in: 4.5...7.5),
            rotation: Double.random(in: -30...30),
            rotationSpeed: Double.random(in: -2.5...2.5),
            isCaught: false,
            scale: 1.0
        )
        fruits.append(newFruit)
    }
    
    private func catchFruit(at index: Int, pixelX: CGFloat, pixelY: CGFloat) {
        fruits[index].isCaught = true
        withAnimation(.easeIn(duration: 0.15)) {
            fruits[index].scale = 0.0
        }
        
        caughtCount += 1
        score += fruits[index].type.points
        progressText = "CAUGHT: \(caughtCount)"
        
        // Audio feedback on catch
        AudioManager.shared.playSFX("whoosh")
        
        // Temporarily display fruit-filled bag
        isBagFilled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isBagFilled = false
            }
        }
        
        // Sparkle burst
        spawnSparkle(at: CGPoint(x: pixelX, y: pixelY), emoji: "✨")
        spawnSparkle(at: CGPoint(x: pixelX + 15, y: pixelY - 10), emoji: fruits[index].type.emoji)
        
        // Milestone sound
        if caughtCount % 5 == 0 {
            AudioManager.shared.playSFX("win_8bit")
        }
    }
    
    private func spawnSparkle(at point: CGPoint, emoji: String = "✨") {
        let s = FallSparkle(x: point.x, y: point.y, emoji: emoji)
        sparkles.append(s)
        
        withAnimation(.easeOut(duration: 0.45)) {
            if let idx = sparkles.firstIndex(where: { $0.id == s.id }) {
                sparkles[idx].scale = 1.4
                sparkles[idx].opacity = 0.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            sparkles.removeAll { $0.id == s.id }
        }
    }
}

// 🔧 PREVIEW SUPPORT
struct FallScene_Previews: PreviewProvider {
    static var previews: some View {
        FallScene(
            engine: TrackingEngine(),
            score: .constant(100),
            progressText: .constant("CAUGHT: 5"),
            playerZone: .solo,
            onComplete: { _ in }
        )
        .background(Color.blue.opacity(0.8))
    }
}
