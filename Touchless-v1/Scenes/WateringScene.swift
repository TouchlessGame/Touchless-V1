import SwiftUI
import AppKit

// 1. Plant Types
enum PlantKind: CaseIterable {
    case `default`
    case rare1
    case rare2
    
    var points: Int {
        switch self {
        case .default: return 15
        case .rare1: return 40
        case .rare2: return 80
        }
    }
    
    var label: String {
        switch self {
        case .default: return "🌱 SPROUT!"
        case .rare1: return "🍅 RARE TOMATO!"
        case .rare2: return "✨ ULTRA RARE!"
        }
    }
    
    var glowColor: Color {
        switch self {
        case .default: return .green
        case .rare1: return Color(red: 1.0, green: 0.35, blue: 0.2)
        case .rare2: return Color(red: 1.0, green: 0.85, blue: 0.1)
        }
    }
    
    var emoji: String {
        switch self {
        case .default: return "🌱"
        case .rare1: return "🍅"
        case .rare2: return "✨"
        }
    }
}

// 2. Garden Plant Model (Pops up and grows as player slides & waters)
struct GardenPlant: Identifiable {
    let id = UUID()
    var x: CGFloat               // Pixel X position in the zone
    var y: CGFloat               // Ground level Y
    var kind: PlantKind          // default, rare1, rare2
    var growth: CGFloat = 0.25   // 0.25 (small seedling) -> 1.0 (fully grown / bloomed)
    var scale: CGFloat = 0.0     // Animates on pop-up & growth
    var isFullyGrown: Bool = false
    var tilt: Double = 0.0
}

// 3. Water Droplet Model
struct WaterDroplet: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var scale: CGFloat = 1.0
    var opacity: Double = 1.0
}

// 4. Splash Particle Model
struct WaterSplash: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var emoji: String = "💦"
    var scale: CGFloat = 0.5
    var opacity: Double = 1.0
}

struct WateringScene: View {
    // 🔧 STANDARD CONTRACT
    @ObservedObject var engine: TrackingEngine
    @Binding var score: Int
    @Binding var progressText: String
    
    var playerZone: PlayerZone = .solo
    var onComplete: (Bool) -> Void
    
    // 🌱 Dynamic Sliding Garden States
    @State private var plants: [GardenPlant] = []
    @State private var bloomedCount: Int = 0
    @State private var canPosition: CGPoint = CGPoint(x: 200, y: 300)
    @State private var currentDeltaX: CGFloat = 0.0
    @State private var isHandDetected: Bool = false
    @State private var isPouring: Bool = false
    @State private var canTilt: Double = 0.0
    @State private var lastAudioTime: Date = Date()
    @State private var lastSlideTime: Date = Date()
    @State private var lastSpawnAttemptTime: Date = Date()
    
    // 💧 Particle Systems
    @State private var droplets: [WaterDroplet] = []
    @State private var splashes: [WaterSplash] = []
    
    // 🎨 Cached SVGs
    @State private var wateringCanImage: NSImage? = nil
    @State private var defaultPlantImage: NSImage? = nil
    @State private var rarePlant1Image: NSImage? = nil
    @State private var rarePlant2Image: NSImage? = nil
    
    private let pinchThreshold: CGFloat = 0.14
    private let plantSpacing: CGFloat = 65.0     // Minimum distance between adjacent plants
    
    var body: some View {
        GeometryReader { geo in
            let groundY = geo.size.height * 0.80
            
            ZStack {
                // ==========================================
                // 1. GARDEN SOIL BED (Subtle footer base)
                // ==========================================
                VStack {
                    Spacer()
                    ZStack(alignment: .top) {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.28, green: 0.18, blue: 0.12).opacity(0.75), Color(red: 0.18, green: 0.10, blue: 0.06).opacity(0.85)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: geo.size.height * 0.22)
                        
                        // Grassy top ridge
                        Rectangle()
                            .fill(Color(red: 0.30, green: 0.65, blue: 0.25).opacity(0.8))
                            .frame(height: 8)
                            .shadow(color: .green.opacity(0.5), radius: 4)
                    }
                }
                .ignoresSafeArea(edges: .bottom)
                
                // ==========================================
                // 2. DYNAMIC GARDEN PLANTS (Pop up & Grow)
                // ==========================================
                ForEach(plants) { plant in
                    VStack(spacing: 4) {
                        // Badge for fully grown / rare plants
                        if plant.isFullyGrown {
                            Text(plant.kind.label)
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(plant.kind.glowColor.opacity(0.85)))
                                .shadow(color: plant.kind.glowColor, radius: 5)
                                .transition(.scale.combined(with: .opacity))
                        }
                        
                        // Plant Image anchored at bottom so it grows UPWARD from soil
                        plantView(for: plant)
                            .frame(width: 140, height: 140)
                            .scaleEffect(plant.scale, anchor: .bottom)
                            .rotationEffect(.degrees(plant.tilt), anchor: .bottom)
                            .shadow(color: plant.kind == .rare2 ? .yellow.opacity(0.6) : .black.opacity(0.35), radius: plant.kind == .rare2 ? 12 : 6, y: 4)
                    }
                    .position(x: plant.x, y: groundY - 20)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: plant.scale)
                }
                
                // ==========================================
                // 3. WATER DROPLETS (Cascade from spout)
                // ==========================================
                ForEach(droplets) { d in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.9), Color.blue],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 10 * d.scale, height: 14 * d.scale)
                        .position(x: d.x, y: d.y)
                        .opacity(d.opacity)
                        .shadow(color: .blue.opacity(0.3), radius: 3)
                }
                
                // ==========================================
                // 4. SPLASHES & BLOOM SPARKLES
                // ==========================================
                ForEach(splashes) { s in
                    Text(s.emoji)
                        .font(.system(size: 26))
                        .scaleEffect(s.scale)
                        .opacity(s.opacity)
                        .position(x: s.x, y: s.y)
                }
                
                // ==========================================
                // 5. WATERING CAN (Follows & Slides with Hand)
                // ==========================================
                wateringCanView
                    .position(canPosition)
                    .rotationEffect(.degrees(canTilt))
                    .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.75), value: canPosition)
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: canTilt)
                    .opacity(isHandDetected ? 1.0 : 0.6)
            }
            .contentShape(Rectangle())
            // Support both camera tracking & mouse/trackpad drag for easy testing
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isHandDetected = true
                        updateCanMotion(newPoint: value.location, groundY: groundY, primaryHand: nil)
                    }
                    .onEnded { _ in
                        isPouring = false
                        canTilt = 0.0
                    }
            )
            .onAppear {
                loadAllSVGs()
                canPosition = CGPoint(x: geo.size.width * 0.4, y: geo.size.height * 0.35)
                progressText = "SLIDE CAN TO GROW PLANTS!"
            }
            // Continuous Physics Loop for Droplets, Growth & Popping
            .background(
                TimelineView(.animation(minimumInterval: 0.033)) { timeline in
                    Color.clear
                        .onChange(of: timeline.date) {
                            updateWaterPhysics(groundY: groundY, screenSize: geo.size)
                        }
                }
            )
            .onChange(of: engine.hands) {
                processHandTracking(groundY: groundY, screenSize: geo.size)
            }
        }
    }
    
    // ==========================================
    // 🎨 PLANT SUBVIEW BY KIND
    // ==========================================
    private func plantView(for plant: GardenPlant) -> some View {
        Group {
            switch plant.kind {
            case .default:
                if let def = defaultPlantImage {
                    Image(nsImage: def)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Text("🪴")
                        .font(.system(size: 70))
                }
            case .rare1:
                if let r1 = rarePlant1Image {
                    Image(nsImage: r1)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Text("🍅")
                        .font(.system(size: 75))
                }
            case .rare2:
                if let r2 = rarePlant2Image {
                    Image(nsImage: r2)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Text("✨")
                        .font(.system(size: 80))
                }
            }
        }
    }
    
    // The watering can view
    private var wateringCanView: some View {
        Group {
            if let canImg = wateringCanImage {
                Image(nsImage: canImg)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 155, height: 155)
                    .shadow(color: .black.opacity(0.4), radius: 8, y: 5)
            } else {
                HStack(spacing: -10) {
                    Circle()
                        .stroke(Color.blue, lineWidth: 6)
                        .frame(width: 35, height: 35)
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.cyan)
                        .frame(width: 80, height: 60)
                    Rectangle()
                        .fill(Color.cyan)
                        .frame(width: 25, height: 7)
                        .rotationEffect(.degrees(30))
                }
            }
        }
    }
    
    // ==========================================
    // 🚀 LOAD ASSETS
    // ==========================================
    private func loadAllSVGs() {
        wateringCanImage = loadSVG(named: "Watering - Watering Can Pinch")
        defaultPlantImage = loadSVG(named: "Watering - Default Plant")
        rarePlant1Image = loadSVG(named: "Watering - Rare Plant 1")
        rarePlant2Image = loadSVG(named: "Watering - Rare Plant 2")
    }
    
    private func loadSVG(named name: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "svg"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        let fallbackPaths = [
            "Touchless-V1/Touchless-v1/Assets/game-assets/watering/\(name).svg",
            "Touchless-v1/Assets/game-assets/watering/\(name).svg"
        ]
        for path in fallbackPaths {
            if let img = NSImage(contentsOf: URL(fileURLWithPath: path)) {
                return img
            }
        }
        return nil
    }
    
    // ==========================================
    // 🖐️ HAND TRACKING & SLIDE/POUR DETECTION
    // ==========================================
    private func processHandTracking(groundY: CGFloat, screenSize: CGSize) {
        let validHands = engine.hands.filter {
            CoordinateMapper.belongsToZone(rawX: $0.indexTip.x, zone: playerZone)
        }
        
        guard let primaryHand = validHands.first else {
            isHandDetected = false
            if isPouring && Date().timeIntervalSince(lastSlideTime) > 0.25 {
                isPouring = false
                canTilt = 0.0
            }
            return
        }
        
        isHandDetected = true
        let trackingPoint = primaryHand.center != .zero ? primaryHand.center : primaryHand.indexTip
        let localPoint = CoordinateMapper.localPoint(rawPoint: trackingPoint, zone: playerZone, screenSize: screenSize)
        
        updateCanMotion(newPoint: localPoint, groundY: groundY, primaryHand: primaryHand)
    }
    
    // Update can position, slide speed, and tilting
    private func updateCanMotion(newPoint: CGPoint, groundY: CGFloat, primaryHand: HandData?) {
        let deltaX = newPoint.x - canPosition.x
        currentDeltaX = deltaX
        canPosition = newPoint
        
        // 1. Gesture A: Sliding horizontally (moving can left or right)
        let slideSpeed = abs(deltaX)
        let isSliding = slideSpeed > 1.8
        
        // 2. Gesture B: Pinch detection
        var isPinching = false
        var isHandTilted = false
        if let hand = primaryHand {
            let pinchDist = hypot(hand.indexTip.x - hand.thumbTip.x, hand.indexTip.y - hand.thumbTip.y)
            isPinching = pinchDist < pinchThreshold
            isHandTilted = (hand.indexTip.y - hand.wrist.y) < CGFloat(-0.04)
        }
        
        // Pour when sliding across the garden, or tilting/pinching!
        let shouldPour = isSliding || isPinching || isHandTilted
        
        if shouldPour {
            isPouring = true
            // Tilt dynamically based on slide direction for natural pouring angle (20° to 45°)
            let dynamicTilt = 28.0 + min(15.0, max(-8.0, Double(deltaX * 1.2)))
            canTilt = dynamicTilt
            lastSlideTime = Date()
        } else {
            // Keep pouring for a smooth 0.22s follow-through after sliding, then return upright
            if Date().timeIntervalSince(lastSlideTime) > 0.22 {
                isPouring = false
                canTilt = 0.0
            }
        }
    }
    
    // ==========================================
    // 💧 WATER PHYSICS & POPPING/GROWING LOGIC
    // ==========================================
    private func updateWaterPhysics(groundY: CGFloat, screenSize: CGSize) {
        // 1. Emit droplets if pouring
        if isPouring {
            // Calculate accurate spout tip position considering canTilt rotation
            let rad = CGFloat(canTilt * .pi / 180.0)
            let unrotatedSpoutX: CGFloat = 65.0
            let unrotatedSpoutY: CGFloat = 10.0
            let rotSpoutX = unrotatedSpoutX * cos(rad) - unrotatedSpoutY * sin(rad)
            let rotSpoutY = unrotatedSpoutX * sin(rad) + unrotatedSpoutY * cos(rad)
            
            let emitOrigin = CGPoint(x: canPosition.x + rotSpoutX, y: canPosition.y + rotSpoutY)
            
            for _ in 0..<2 {
                let drop = WaterDroplet(
                    x: emitOrigin.x + CGFloat.random(in: -5...5),
                    y: emitOrigin.y + CGFloat.random(in: -3...3),
                    vx: CGFloat.random(in: -0.8...1.5) + (currentDeltaX * 0.15),
                    vy: CGFloat.random(in: 8.0...13.0),
                    scale: CGFloat.random(in: 0.8...1.2),
                    opacity: 1.0
                )
                droplets.append(drop)
            }
            
            // Audio feedback throttled to every 0.35s
            let now = Date()
            if now.timeIntervalSince(lastAudioTime) > 0.35 {
                AudioManager.shared.playSFX("whoosh")
                lastAudioTime = now
            }
        }
        
        // 2. Move droplets and check ground collisions
        for i in droplets.indices {
            droplets[i].x += droplets[i].vx
            droplets[i].y += droplets[i].vy
            droplets[i].vy += 0.5 // gravity
            
            let dropX = droplets[i].x
            let dropY = droplets[i].y
            
            // Reached ground / soil level
            if dropY >= (groundY - 15) {
                droplets[i].opacity = 0.0
                spawnSplash(at: CGPoint(x: dropX, y: groundY - 15), emoji: "💧")
                waterSoilAt(x: dropX, groundY: groundY, screenWidth: screenSize.width)
            }
        }
        
        // Remove dead droplets
        droplets.removeAll { $0.y > screenSize.height || $0.opacity <= 0.05 }
    }
    
    // ==========================================
    // 🌱 POPPING & GROWING PLANTS
    // ==========================================
    private func waterSoilAt(x: CGFloat, groundY: CGFloat, screenWidth: CGFloat) {
        // Keep plants nicely within play bounds
        guard x > 45 && x < (screenWidth - 45) else { return }
        
        let maxPlants = max(6, Int((screenWidth - 100) / plantSpacing))
        
        // 1. Check if an existing plant is already near this spot
        if let existingIndex = plants.firstIndex(where: { abs($0.x - x) < plantSpacing }) {
            // Nourish the plant: it grows bigger!
            growPlant(at: existingIndex)
        } else if plants.count < maxPlants {
            // 2. No plant here: POP UP A NEW PLANT!
            let now = Date()
            if now.timeIntervalSince(lastSpawnAttemptTime) > 0.15 {
                spawnNewPlant(atX: x, groundY: groundY)
                lastSpawnAttemptTime = now
            }
        }
    }
    
    // Pop up a new plant (mostly default, randomly rare!)
    private func spawnNewPlant(atX x: CGFloat, groundY: CGFloat) {
        // Rarity Roll:
        // 84% Default Plant (🌱 Green Sprout)
        // 12% Rare Plant 1 (🍅 Tomato Plant with ripe tomatoes)
        // 4% Ultra-Rare Plant 2 (✨ Golden Multi-Stalk Tomato Bush)
        let roll = Int.random(in: 1...100)
        let kind: PlantKind
        if roll <= 84 {
            kind = .default
        } else if roll <= 96 {
            kind = .rare1
        } else {
            kind = .rare2
        }
        
        let newPlant = GardenPlant(
            x: x,
            y: groundY,
            kind: kind,
            growth: 0.20,
            scale: 0.1,
            isFullyGrown: false,
            tilt: Double.random(in: -5...5)
        )
        
        plants.append(newPlant)
        
        // Pop-up bounce animation
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
            if let idx = plants.firstIndex(where: { $0.id == newPlant.id }) {
                plants[idx].scale = 0.45
            }
        }
        
        // Sparkle pop
        spawnSplash(at: CGPoint(x: x, y: groundY - 50), emoji: kind == .rare2 ? "✨" : (kind == .rare1 ? "🍅" : "🌱"))
        
        // Audio reward
        if kind == .rare2 {
            AudioManager.shared.playSFX("win_8bit")
            spawnSplash(at: CGPoint(x: x, y: groundY - 70), emoji: "✨")
            score += 25
        } else if kind == .rare1 {
            AudioManager.shared.playSFX("whoosh")
            spawnSplash(at: CGPoint(x: x, y: groundY - 60), emoji: "🍅")
            score += 15
        } else {
            score += 5
        }
        
        updateProgressHUD()
    }
    
    // Grow existing plant bigger as water continues to hit it
    private func growPlant(at index: Int) {
        guard !plants[index].isFullyGrown else { return }
        
        plants[index].growth = min(1.0, plants[index].growth + 0.018)
        
        // Plant grows bigger!
        let newScale = 0.45 + (plants[index].growth * 0.65) // grows from 0.45 up to 1.10
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            plants[index].scale = newScale
        }
        
        score += 1
        
        // Milestone: Full Bloom!
        if plants[index].growth >= 1.0 {
            plants[index].isFullyGrown = true
            bloomedCount += 1
            score += plants[index].kind.points
            
            // Celebration effects on bloom
            spawnSplash(at: CGPoint(x: plants[index].x, y: plants[index].y - 80), emoji: "✨")
            spawnSplash(at: CGPoint(x: plants[index].x + 12, y: plants[index].y - 95), emoji: plants[index].kind.emoji)
            
            if plants[index].kind == .rare2 || bloomedCount % 3 == 0 {
                AudioManager.shared.playSFX("win_8bit")
            }
        }
        
        updateProgressHUD()
    }
    
    private func updateProgressHUD() {
        progressText = "PLANTS: \(plants.count) 🌱 | BLOOMED: \(bloomedCount)"
    }
    
    private func spawnSplash(at point: CGPoint, emoji: String) {
        let splash = WaterSplash(x: point.x, y: point.y, emoji: emoji)
        splashes.append(splash)
        
        withAnimation(.easeOut(duration: 0.4)) {
            if let idx = splashes.firstIndex(where: { $0.id == splash.id }) {
                splashes[idx].scale = 1.3
                splashes[idx].opacity = 0.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            splashes.removeAll { $0.id == splash.id }
        }
    }
}

// 🔧 PREVIEW SUPPORT
struct WateringScene_Previews: PreviewProvider {
    static var previews: some View {
        WateringScene(
            engine: TrackingEngine(),
            score: .constant(100),
            progressText: .constant("PLANTS: 4 🌱"),
            playerZone: .solo,
            onComplete: { _ in }
        )
        .background(Color.blue.opacity(0.8))
    }
}
