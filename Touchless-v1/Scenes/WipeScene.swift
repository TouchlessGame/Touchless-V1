import SwiftUI
import AppKit

// 1. Data model for individual dirt / smudge targets on the glass
struct DirtSpot: Identifiable {
    let id = UUID()
    var x: CGFloat       // Relative X (0.0 to 1.0)
    var y: CGFloat       // Relative Y (0.0 to 1.0)
    var radius: CGFloat
    var isCleaned: Bool = false
    var cleanScale: CGFloat = 1.0
}

// 2. Data model for sparkling clean particles
struct WipeSparkle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var scale: CGFloat = 0.2
    var opacity: Double = 1.0
}

// 3. Line segment representing the path wiped by the cloth
struct WipeStroke: Identifiable {
    let id = UUID()
    var points: [CGPoint]
}

struct WipeScene: View {
    // 🔧 STANDARD SCENE CONTRACT
    @ObservedObject var engine: TrackingEngine
    @Binding var score: Int
    @Binding var progressText: String
    
    var playerZone: PlayerZone = .solo
    var onComplete: (Bool) -> Void
    
    // 🧽 Fog & Wiping Trail State
    @State private var wipeStrokes: [WipeStroke] = []
    @State private var currentStrokePoints: [CGPoint] = []
    @State private var sparkles: [WipeSparkle] = []
    @State private var dirtSpots: [DirtSpot] = []
    
    // Hand tracking & cloth positioning
    @State private var clothPosition: CGPoint = CGPoint(x: 200, y: 300)
    @State private var isHandDetected: Bool = false
    @State private var clothTilt: Double = 0.0
    
    // Grid Coverage Calculation (24 cols x 16 rows = 384 cells)
    private let gridCols: Int = 24
    private let gridRows: Int = 16
    @State private var cleanedCells: Set<Int> = []
    @State private var percentCleaned: Int = 0
    @State private var showCleanFlash: Bool = false
    @State private var windowsCleanedCount: Int = 0
    
    // Cached cloth image
    @State private var clothImage: NSImage? = nil
    
    private let wipeRadius: CGFloat = 65.0 // Width of cloth wiping swath
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ====================================================================
                // 1. THE STEAMY FOGGY WINDOW LAYER (Masked out along the wiped trail)
                // ====================================================================
                ZStack {
                    // Base heavy frosted steam (semi-translucent white with glass texture)
                    Rectangle()
                        .fill(Color.white.opacity(0.82))
                        .ignoresSafeArea()
                    
                    // Condensation speckle / blur texture overlay
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.9),
                            Color(white: 0.92, opacity: 0.75),
                            Color.white.opacity(0.88)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    // Realistic window panes grid (frosted along with the glass)
                    windowPanesGrid(size: geo.size)
                    
                    // Grimy Dirt / Soap spots on the foggy window
                    ForEach(dirtSpots) { spot in
                        if !spot.isCleaned || spot.cleanScale > 0.05 {
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                Color(white: 0.7, opacity: 0.65),
                                                Color.white.opacity(0.4),
                                                Color.clear
                                            ],
                                            center: .center,
                                            startRadius: 4,
                                            endRadius: spot.radius
                                        )
                                    )
                                    .frame(width: spot.radius * 2, height: spot.radius * 2)
                                
                                // Soap bubble ring / smudge
                                Circle()
                                    .stroke(Color.white.opacity(0.7), lineWidth: 2)
                                    .frame(width: spot.radius * 1.1, height: spot.radius * 1.1)
                            }
                            .scaleEffect(spot.cleanScale)
                            .position(x: spot.x * geo.size.width, y: spot.y * geo.size.height)
                        }
                    }
                }
                // 🪄 MAGIC CUTOUT MASK: Erases the fog along the exact path the cloth traveled!
                .mask(
                    Canvas { context, size in
                        // 1. Draw solid white covering the entire screen (Opaque = Fog visible)
                        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
                        
                        // 2. Switch blend mode to CLEAR (Erases white wherever the cloth wiped!)
                        context.blendMode = .clear
                        
                        // Erase completed wipe strokes
                        for stroke in wipeStrokes {
                            if stroke.points.count >= 2 {
                                var path = Path()
                                path.addLines(stroke.points)
                                context.stroke(
                                    path,
                                    with: .color(.white),
                                    style: StrokeStyle(lineWidth: wipeRadius * 2, lineCap: .round, lineJoin: .round)
                                )
                            } else if let single = stroke.points.first {
                                let circle = Path(ellipseIn: CGRect(
                                    x: single.x - wipeRadius,
                                    y: single.y - wipeRadius,
                                    width: wipeRadius * 2,
                                    height: wipeRadius * 2
                                ))
                                context.fill(circle, with: .color(.white))
                            }
                        }
                        
                        // Erase current active stroke
                        if currentStrokePoints.count >= 2 {
                            var activePath = Path()
                            activePath.addLines(currentStrokePoints)
                            context.stroke(
                                activePath,
                                with: .color(.white),
                                style: StrokeStyle(lineWidth: wipeRadius * 2, lineCap: .round, lineJoin: .round)
                            )
                        } else if let single = currentStrokePoints.first {
                            let circle = Path(ellipseIn: CGRect(
                                x: single.x - wipeRadius,
                                y: single.y - wipeRadius,
                                width: wipeRadius * 2,
                                height: wipeRadius * 2
                            ))
                            context.fill(circle, with: .color(.white))
                        }
                    }
                )
                
                // ====================================================================
                // 2. SPARKLING PARTICLES ALONG THE CLEANED TRAIL
                // ====================================================================
                ForEach(sparkles) { sparkle in
                    Text("✨")
                        .font(.system(size: 34))
                        .scaleEffect(sparkle.scale)
                        .opacity(sparkle.opacity)
                        .position(x: sparkle.x, y: sparkle.y)
                }
                
                // ====================================================================
                // 3. "100% SQUEAKY CLEAN!" CELEBRATION BANNER
                // ====================================================================
                if showCleanFlash {
                    VStack(spacing: 8) {
                        Text("✨ 100% SQUEAKY CLEAN! ✨")
                            .font(.system(size: 46, weight: .black, design: .rounded))
                            .foregroundColor(.yellow)
                            .shadow(color: .orange, radius: 14)
                        
                        Text("+200 SPEED BONUS!")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 6)
                    }
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(50)
                }
                
                // ====================================================================
                // 4. THE CLOTH (TRACKS PLAYER'S ACTIVE HAND DIRECTLY)
                // ====================================================================
                clothView
                    .position(clothPosition)
                    .rotationEffect(.degrees(clothTilt))
                    .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.75), value: clothPosition)
                    .opacity(isHandDetected ? 1.0 : 0.6)
                    .zIndex(60)
            }
            .onAppear {
                loadClothAsset()
                initWindowEnvironment()
                clothPosition = CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.5)
                updateProgressUI()
            }
            .onChange(of: engine.hands) {
                processHandTracking(in: geo.size)
            }
        }
    }
    
    // ==========================================
    // 🪟 WINDOW PANE GRID DIVIDER
    // ==========================================
    private func windowPanesGrid(size: CGSize) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.35))
                .frame(height: 4)
                .position(x: size.width / 2, y: size.height / 2)
            
            Rectangle()
                .fill(Color.white.opacity(0.35))
                .frame(width: 4)
                .position(x: size.width / 2, y: size.height / 2)
            
            Rectangle()
                .stroke(Color.white.opacity(0.4), lineWidth: 6)
                .ignoresSafeArea()
        }
    }
    
    // ==========================================
    // 🧽 CLOTH VIEW (SVG ASSET)
    // ==========================================
    private var clothView: some View {
        Group {
            if let nsImg = clothImage {
                Image(nsImage: nsImg)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 145, height: 145)
                    .shadow(color: .black.opacity(0.5), radius: 10, x: 4, y: 8)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(playerZone == .rightPlayer ? Color(hex: "#ffde59") : Color(hex: "#f5bdbd"))
                        .frame(width: 130, height: 110)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white, style: StrokeStyle(lineWidth: 3, dash: [6, 4]))
                        )
                        .shadow(color: .black.opacity(0.4), radius: 8)
                    Text("🧽")
                        .font(.system(size: 45))
                }
            }
        }
    }
    
    // ==========================================
    // 🚀 ASSET LOADER
    // ==========================================
    private func loadClothAsset() {
        let assetName = (playerZone == .rightPlayer) ? "Wipe - Cloth Player 2" : "Wipe - Cloth Player 1"
        
        if let url = Bundle.main.url(forResource: assetName, withExtension: "svg"),
           let img = NSImage(contentsOf: url) {
            self.clothImage = img
            return
        }
        
        let fallbackPaths = [
            "Touchless-V1/Touchless-v1/Assets/game-assets/wipe/\(assetName).svg",
            "Touchless-v1/Assets/game-assets/wipe/\(assetName).svg"
        ]
        for path in fallbackPaths {
            if let img = NSImage(contentsOf: URL(fileURLWithPath: path)) {
                self.clothImage = img
                return
            }
        }
    }
    
    // ==========================================
    // 💨 INITIALIZE / RESET STEAM & DIRT
    // ==========================================
    private func initWindowEnvironment() {
        cleanedCells.removeAll()
        wipeStrokes.removeAll()
        currentStrokePoints.removeAll()
        
        var spots: [DirtSpot] = []
        for _ in 0..<14 {
            spots.append(
                DirtSpot(
                    x: CGFloat.random(in: 0.15...0.85),
                    y: CGFloat.random(in: 0.18...0.82),
                    radius: CGFloat.random(in: 40...65),
                    isCleaned: false,
                    cleanScale: 1.0
                )
            )
        }
        self.dirtSpots = spots
        percentCleaned = 0
    }
    
    // ==========================================
    // 🖐️ HAND TRACKING & REAL-TIME WIPING
    // ==========================================
    private func processHandTracking(in size: CGSize) {
        let validHands = engine.hands.filter {
            CoordinateMapper.belongsToZone(rawX: $0.indexTip.x, zone: playerZone)
        }
        
        guard let primaryHand = validHands.first else {
            isHandDetected = false
            // Finalize current stroke when hand is lost
            if !currentStrokePoints.isEmpty {
                wipeStrokes.append(WipeStroke(points: currentStrokePoints))
                currentStrokePoints.removeAll()
            }
            return
        }
        
        isHandDetected = true
        
        // Use hand center or index tip
        let trackingPoint = primaryHand.center != .zero ? primaryHand.center : primaryHand.indexTip
        
        // 🎯 EXACT LOCAL COORDINATE MAPPING (X mirrored, Y inverted from Vision to SwiftUI)
        let localPoint = CoordinateMapper.localPoint(rawPoint: trackingPoint, zone: playerZone, screenSize: size)
        
        // Smooth cloth tilt based on movement vector
        let deltaX = localPoint.x - clothPosition.x
        clothTilt = Double(max(-25, min(25, deltaX * 0.4)))
        clothPosition = localPoint
        
        // Append point to continuous wipe trail
        currentStrokePoints.append(localPoint)
        if currentStrokePoints.count > 60 {
            // Keep memory optimal by moving older points into committed strokes
            wipeStrokes.append(WipeStroke(points: Array(currentStrokePoints.prefix(30))))
            currentStrokePoints.removeFirst(30)
        }
        
        // Update Grid Cleaning Coverage
        applyWipeToGrid(at: localPoint, in: size)
        
        // Clean overlapping dirt spots
        checkDirtSpotCleaning(at: localPoint, in: size)
    }
    
    // ==========================================
    // 🧮 GRID COVERAGE & PERCENTAGE CALCULATION
    // ==========================================
    private func applyWipeToGrid(at point: CGPoint, in size: CGSize) {
        let totalCells = gridCols * gridRows
        let cellWidth = size.width / CGFloat(gridCols)
        let cellHeight = size.height / CGFloat(gridRows)
        
        var newlyCleanedInThisStep = 0
        
        for r in 0..<gridRows {
            for c in 0..<gridCols {
                let cellIndex = r * gridCols + c
                guard !cleanedCells.contains(cellIndex) else { continue }
                
                let cellCenter = CGPoint(
                    x: (CGFloat(c) + 0.5) * cellWidth,
                    y: (CGFloat(r) + 0.5) * cellHeight
                )
                
                let dist = hypot(point.x - cellCenter.x, point.y - cellCenter.y)
                if dist < wipeRadius {
                    cleanedCells.insert(cellIndex)
                    newlyCleanedInThisStep += 1
                }
            }
        }
        
        if newlyCleanedInThisStep > 0 {
            AudioManager.shared.playScrapeOnce()
            
            // Add points per cleaned cell
            score += newlyCleanedInThisStep * 2
            
            let newPercent = Int((Double(cleanedCells.count) / Double(totalCells)) * 100)
            if newPercent != percentCleaned {
                percentCleaned = newPercent
                updateProgressUI()
            }
            
            // Spawn sparkles periodically along wipe path
            if Bool.random() {
                spawnSparkle(at: point)
            }
            
            // If 100% or virtually all (>= 96%) clean: trigger celebratory complete!
            if cleanedCells.count >= Int(Double(totalCells) * 0.96) && !showCleanFlash {
                triggerFullWindowCleared()
            }
        }
    }
    
    // ==========================================
    // 🧼 DIRT SPOT CLEANING
    // ==========================================
    private func checkDirtSpotCleaning(at point: CGPoint, in size: CGSize) {
        for idx in dirtSpots.indices {
            guard !dirtSpots[idx].isCleaned else { continue }
            
            let spotPixelX = dirtSpots[idx].x * size.width
            let spotPixelY = dirtSpots[idx].y * size.height
            
            let dist = hypot(point.x - spotPixelX, point.y - spotPixelY)
            if dist < (wipeRadius + dirtSpots[idx].radius * 0.5) {
                dirtSpots[idx].isCleaned = true
                dirtSpots[idx].cleanScale = 0.0
                score += 25 // Bonus points for wiping out dirt spots!
                spawnSparkle(at: CGPoint(x: spotPixelX, y: spotPixelY))
            }
        }
    }
    
    // ==========================================
    // ✨ SPARKLE PARTICLES
    // ==========================================
    private func spawnSparkle(at point: CGPoint) {
        let newSparkle = WipeSparkle(x: point.x, y: point.y)
        sparkles.append(newSparkle)
        
        withAnimation(.easeOut(duration: 0.4)) {
            if let idx = sparkles.firstIndex(where: { $0.id == newSparkle.id }) {
                sparkles[idx].scale = 1.3
                sparkles[idx].opacity = 0.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            sparkles.removeAll { $0.id == newSparkle.id }
        }
    }
    
    // ==========================================
    // 🎉 100% SQUEAKY CLEAN COMPLETE LOGIC
    // ==========================================
    private func triggerFullWindowCleared() {
        windowsCleanedCount += 1
        score += 200 // Huge speed bonus!
        AudioManager.shared.playSFX("win_8bit")
        
        withAnimation(.spring()) {
            showCleanFlash = true
        }
        
        onComplete(true)
        
        // Spawn fresh steamy window after a moment to keep the rapid-fire frenzy going!
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.4)) {
                showCleanFlash = false
                initWindowEnvironment()
                updateProgressUI()
            }
        }
    }
    
    private func updateProgressUI() {
        progressText = "CLEAN: \(percentCleaned)%"
    }
}

// Helper color extension for hex support
private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// 🔧 PREVIEW SUPPORT
struct WipeScene_Previews: PreviewProvider {
    static var previews: some View {
        WipeScene(
            engine: TrackingEngine(),
            score: .constant(150),
            progressText: .constant("CLEAN: 75%"),
            playerZone: .solo,
            onComplete: { _ in }
        )
        .background(Color.blue.opacity(0.8))
    }
}
