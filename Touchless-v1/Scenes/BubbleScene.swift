import SwiftUI
import AppKit
import Combine

// MARK: - 1. Bubble Varieties
enum BubbleKind: CaseIterable {
    case standard
    case mini
    case giant
    
    var points: Int {
        switch self {
        case .standard: return 10
        case .mini: return 15
        case .giant: return 30
        }
    }
    
    var diameter: CGFloat {
        switch self {
        case .standard: return 92.0
        case .mini: return 68.0
        case .giant: return 138.0
        }
    }
    
    var hitRadius: CGFloat {
        return (diameter / 2.0) + 24.0 // Generous, forgiving tap target
    }
    
    var glowColor: Color {
        switch self {
        case .standard: return Color.cyan
        case .mini: return Color(red: 0.4, green: 0.8, blue: 1.0)
        case .giant: return Color(red: 1.0, green: 0.85, blue: 0.2)
        }
    }
}

// MARK: - 2. Active Bubble Item
struct BubbleItem: Identifiable {
    let id = UUID()
    var kind: BubbleKind
    var slotIndex: Int
    var xRatio: CGFloat          // Relative X in zone (0.15 ... 0.85)
    var yRatio: CGFloat          // Relative Y in zone (0.22 ... 0.78)
    var isPopped: Bool = false
    var popScale: CGFloat = 1.0
    var popOpacity: Double = 1.0
    var spawnTime: Date = Date()
    var bobDuration: Double = Double.random(in: 1.8...2.6)
}

// MARK: - 3. Tap Splash Particles
struct TapSplash: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var text: String
    var scale: CGFloat = 0.6
    var opacity: Double = 1.0
}

// MARK: - 4. Main BubbleScene View
struct BubbleScene: View {
    // 🔧 STANDARD SCENE CONTRACT
    @ObservedObject var engine: TrackingEngine
    @Binding var score: Int
    @Binding var progressText: String
    
    var playerZone: PlayerZone = .solo
    var onComplete: (Bool) -> Void
    
    // 🫧 State Management
    @State private var bubbles: [BubbleItem] = []
    @State private var splashes: [TapSplash] = []
    @State private var poppedCount: Int = 0
    
    // ⚡ Combo System
    @State private var lastPopTime: Date = Date.distantPast
    @State private var comboStreak: Int = 0
    
    // 🖐️ Hand & Tap Tracking
    @State private var handPosition: CGPoint? = nil
    @State private var isHandDetected: Bool = false
    @State private var lastTappedBubbleId: UUID? = nil
    @State private var lastTapTime: Date = Date.distantPast
    
    // 🎨 Pre-Rasterized High-Performance Bitmaps
    @State private var fullBubbleImage: NSImage? = nil
    @State private var poppedBubbleImage: NSImage? = nil
    
    // 🎯 Predefined Spawn Slots (Prevents overlapping, ensures crisp distribution)
    private let spawnSlots: [CGPoint] = [
        CGPoint(x: 0.22, y: 0.32),
        CGPoint(x: 0.50, y: 0.26),
        CGPoint(x: 0.78, y: 0.34),
        CGPoint(x: 0.24, y: 0.66),
        CGPoint(x: 0.52, y: 0.72),
        CGPoint(x: 0.76, y: 0.62)
    ]
    private let targetBubbleCount: Int = 5
    
    // Slow refresh timer (every 2.5s) to cycle idle bubbles with zero CPU impact
    private let maintenanceTimer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ==========================================
                // 1. ACTIVE TAPPABLE BUBBLES
                // ==========================================
                ForEach(bubbles) { bubble in
                    let center = CGPoint(
                        x: bubble.xRatio * geo.size.width,
                        y: bubble.yRatio * geo.size.height
                    )
                    
                    IndividualBubbleView(
                        bubble: bubble,
                        fullImage: fullBubbleImage,
                        poppedImage: poppedBubbleImage,
                        onTap: {
                            popBubble(withId: bubble.id, at: center)
                        }
                    )
                    .position(center)
                }
                
                // ==========================================
                // 2. TAP REWARD PARTICLES / COMBO BADGES
                // ==========================================
                ForEach(splashes) { splash in
                    Text(splash.text)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(LinearGradient(colors: [.cyan.opacity(0.85), .blue.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                        .scaleEffect(splash.scale)
                        .opacity(splash.opacity)
                        .position(x: splash.x, y: splash.y)
                        .allowsHitTesting(false)
                }
                
                // ==========================================
                // 3. RETICLE / FINGERTIP CURSOR
                // ==========================================
                if let pos = handPosition, isHandDetected {
                    ZStack {
                        Circle()
                            .stroke(Color.cyan.opacity(0.85), lineWidth: 2.5)
                            .frame(width: 44, height: 44)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                    }
                    .position(pos)
                    .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            // Mouse/Trackpad Tap Fallback: Direct tap anywhere near a bubble pops it!
            .onTapGesture { location in
                checkDirectTap(at: location, in: geo.size)
            }
            .onAppear {
                loadPreRasterizedSVGs()
                initBubbles()
                progressText = "POPPED: 0 🫧"
            }
            .onReceive(maintenanceTimer) { _ in
                cycleOldBubbles()
            }
            .onChange(of: engine.hands) {
                processHandTracking(in: geo.size)
            }
        }
    }
    
    // ==========================================
    // 🎨 ASSET LOADING & PRE-RASTERIZATION (LAG FIX)
    // ==========================================
    private func loadPreRasterizedSVGs() {
        // Pre-rasterize once to avoid re-evaluating SVG vector paths & masks at 60 FPS
        fullBubbleImage = rasterizeSVG(named: "Bubble - Full Bubble", targetSize: CGSize(width: 256, height: 256))
        poppedBubbleImage = rasterizeSVG(named: "Bubble - Popped Bubble", targetSize: CGSize(width: 256, height: 256))
    }
    
    private func rasterizeSVG(named name: String, targetSize: CGSize) -> NSImage? {
        guard let sourceImage = loadSVG(named: name) else { return nil }
        
        let scale: CGFloat = 2.0 // 2x Retina
        let pixelWidth = max(1, Int(targetSize.width * scale))
        let pixelHeight = max(1, Int(targetSize.height * scale))
        
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return sourceImage
        }
        
        rep.size = targetSize
        NSGraphicsContext.saveGraphicsState()
        let ctx = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current = ctx
        sourceImage.draw(in: NSRect(origin: .zero, size: targetSize))
        NSGraphicsContext.restoreGraphicsState()
        
        let result = NSImage(size: targetSize)
        result.addRepresentation(rep)
        return result
    }
    
    private func loadSVG(named name: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "svg"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        let fallbackPaths = [
            "Touchless-V1/Touchless-v1/Assets/game-assets/bubble/\(name).svg",
            "Touchless-v1/Assets/game-assets/bubble/\(name).svg"
        ]
        for path in fallbackPaths {
            if let img = NSImage(contentsOf: URL(fileURLWithPath: path)) {
                return img
            }
        }
        return nil
    }
    
    // ==========================================
    // 🫧 SPAWN & SLOT MANAGEMENT
    // ==========================================
    private func initBubbles() {
        bubbles.removeAll()
        var availableSlots = Array(0..<spawnSlots.count).shuffled()
        for _ in 0..<min(targetBubbleCount, availableSlots.count) {
            let slot = availableSlots.removeFirst()
            bubbles.append(createBubble(forSlot: slot))
        }
    }
    
    private func createBubble(forSlot slotIndex: Int) -> BubbleItem {
        let slotPos = spawnSlots[slotIndex]
        let jitterX = CGFloat.random(in: -0.03...0.03)
        let jitterY = CGFloat.random(in: -0.03...0.03)
        
        // Distribution: 65% Standard, 25% Mini, 10% Giant
        let roll = Int.random(in: 1...100)
        let kind: BubbleKind
        if roll <= 65 {
            kind = .standard
        } else if roll <= 90 {
            kind = .mini
        } else {
            kind = .giant
        }
        
        return BubbleItem(
            kind: kind,
            slotIndex: slotIndex,
            xRatio: min(0.88, max(0.12, slotPos.x + jitterX)),
            yRatio: min(0.80, max(0.20, slotPos.y + jitterY))
        )
    }
    
    private func replenishBubblesIfNeeded() {
        let occupiedSlots = Set(bubbles.filter { !$0.isPopped }.map { $0.slotIndex })
        let freeSlots = Array(0..<spawnSlots.count).filter { !occupiedSlots.contains($0) }.shuffled()
        
        guard let nextSlot = freeSlots.first, bubbles.filter({ !$0.isPopped }).count < targetBubbleCount else {
            return
        }
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
            bubbles.append(createBubble(forSlot: nextSlot))
        }
    }
    
    private func cycleOldBubbles() {
        let now = Date()
        let oldBubbles = bubbles.filter { !$0.isPopped && now.timeIntervalSince($0.spawnTime) > 7.0 }
        if let oldest = oldBubbles.first {
            withAnimation(.easeOut(duration: 0.3)) {
                if let idx = bubbles.firstIndex(where: { $0.id == oldest.id }) {
                    bubbles[idx].popOpacity = 0.0
                    bubbles[idx].popScale = 0.4
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                bubbles.removeAll { $0.id == oldest.id }
                replenishBubblesIfNeeded()
            }
        }
    }
    
    // ==========================================
    // 🖐️ TAP MECHANIC & TRACKING
    // ==========================================
    private func processHandTracking(in size: CGSize) {
        let validHands = engine.hands.filter {
            CoordinateMapper.belongsToZone(rawX: $0.indexTip.x, zone: playerZone)
        }
        
        guard let primaryHand = validHands.first else {
            isHandDetected = false
            handPosition = nil
            lastTappedBubbleId = nil
            return
        }
        
        isHandDetected = true
        let tipPoint = CoordinateMapper.localPoint(rawPoint: primaryHand.indexTip, zone: playerZone, screenSize: size)
        handPosition = tipPoint
        
        // Check discrete fingertip tap
        checkHandTap(at: tipPoint, in: size)
    }
    
    private func checkHandTap(at point: CGPoint, in size: CGSize) {
        let now = Date()
        // Tap debounce (120ms) guarantees crisp individual "tap-tap" pops rather than continuous hover wiping
        guard now.timeIntervalSince(lastTapTime) >= 0.12 else { return }
        
        for bubble in bubbles {
            guard !bubble.isPopped else { continue }
            
            let center = CGPoint(x: bubble.xRatio * size.width, y: bubble.yRatio * size.height)
            let dist = hypot(point.x - center.x, point.y - center.y)
            
            if dist <= bubble.kind.hitRadius {
                // Must be a new bubble target or enough time has passed for a fresh tap
                if bubble.id != lastTappedBubbleId || now.timeIntervalSince(lastTapTime) >= 0.35 {
                    lastTappedBubbleId = bubble.id
                    lastTapTime = now
                    popBubble(withId: bubble.id, at: center)
                    break
                }
            }
        }
    }
    
    private func checkDirectTap(at point: CGPoint, in size: CGSize) {
        for bubble in bubbles {
            guard !bubble.isPopped else { continue }
            let center = CGPoint(x: bubble.xRatio * size.width, y: bubble.yRatio * size.height)
            let dist = hypot(point.x - center.x, point.y - center.y)
            if dist <= bubble.kind.hitRadius {
                popBubble(withId: bubble.id, at: center)
                break
            }
        }
    }
    
    // ==========================================
    // 💥 POPPING REWARD & AUDIO FEEDBACK
    // ==========================================
    private func popBubble(withId id: UUID, at center: CGPoint) {
        guard let index = bubbles.firstIndex(where: { $0.id == id && !$0.isPopped }) else { return }
        
        let kind = bubbles[index].kind
        bubbles[index].isPopped = true
        poppedCount += 1
        
        // ⚡ Combo System Evaluation
        let now = Date()
        let isCombo = now.timeIntervalSince(lastPopTime) < 0.75
        lastPopTime = now
        
        if isCombo {
            comboStreak += 1
        } else {
            comboStreak = 1
        }
        
        var pointsEarned = kind.points
        if comboStreak >= 2 {
            let comboBonus = comboStreak * 5
            pointsEarned += comboBonus
        }
        
        score += pointsEarned
        progressText = "POPPED: \(poppedCount) 🫧"
        
        // 🔊 Snappy Audio Feedback
        if kind == .giant || comboStreak >= 3 {
            AudioManager.shared.playSFX("win_8bit")
        } else {
            AudioManager.shared.playSFX("whoosh")
        }
        
        // ✨ Visual Burst Animation
        withAnimation(.easeOut(duration: 0.22)) {
            if let idx = bubbles.firstIndex(where: { $0.id == id }) {
                bubbles[idx].popScale = 1.35
                bubbles[idx].popOpacity = 0.0
            }
        }
        
        // Splash Badge
        spawnSplash(at: center, points: pointsEarned, streak: comboStreak)
        
        // Clean up & spawn replacement
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            bubbles.removeAll { $0.id == id }
            replenishBubblesIfNeeded()
        }
    }
    
    private func spawnSplash(at point: CGPoint, points: Int, streak: Int) {
        let badgeText = streak >= 2 ? "+\(points) COMBO x\(streak)! 🔥" : "+\(points) 🫧"
        let splash = TapSplash(x: point.x, y: point.y - 25, text: badgeText)
        
        if splashes.count >= 3 {
            splashes.removeFirst()
        }
        splashes.append(splash)
        
        withAnimation(.easeOut(duration: 0.45)) {
            if let idx = splashes.firstIndex(where: { $0.id == splash.id }) {
                splashes[idx].y -= 30
                splashes[idx].opacity = 0.0
                splashes[idx].scale = 1.15
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) {
            splashes.removeAll { $0.id == splash.id }
        }
    }
}

// MARK: - 5. Individual Bubble Component (GPU Accelerated Bobbing)
private struct IndividualBubbleView: View {
    let bubble: BubbleItem
    let fullImage: NSImage?
    let poppedImage: NSImage?
    let onTap: () -> Void
    
    @State private var isBobbing: Bool = false
    
    var body: some View {
        ZStack {
            if bubble.isPopped {
                if let popImg = poppedImage {
                    Image(nsImage: popImg)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: bubble.kind.diameter * 1.3, height: bubble.kind.diameter * 1.3)
                        .scaleEffect(bubble.popScale)
                        .opacity(bubble.popOpacity)
                } else {
                    Circle()
                        .stroke(Color.cyan, lineWidth: 3)
                        .frame(width: bubble.kind.diameter, height: bubble.kind.diameter)
                        .scaleEffect(bubble.popScale)
                        .opacity(bubble.popOpacity)
                }
            } else {
                if let fullImg = fullImage {
                    Image(nsImage: fullImg)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: bubble.kind.diameter, height: bubble.kind.diameter)
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.6), Color.blue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: bubble.kind.diameter, height: bubble.kind.diameter)
                        .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 2))
                }
                
                if bubble.kind == .giant {
                    Text("✨")
                        .font(.system(size: 24))
                        .offset(x: bubble.kind.diameter * 0.28, y: -bubble.kind.diameter * 0.28)
                }
            }
        }
        .contentShape(Circle())
        .offset(y: isBobbing ? -10 : 10)
        .onAppear {
            withAnimation(
                .easeInOut(duration: bubble.bobDuration)
                .repeatForever(autoreverses: true)
            ) {
                isBobbing = true
            }
        }
        .onTapGesture {
            onTap()
        }
    }
}

// 🔧 PREVIEW SUPPORT
struct BubbleScene_Previews: PreviewProvider {
    static var previews: some View {
        BubbleScene(
            engine: TrackingEngine(),
            score: .constant(50),
            progressText: .constant("POPPED: 5 🫧"),
            playerZone: .solo,
            onComplete: { _ in }
        )
        .background(Color.black.opacity(0.8))
    }
}
