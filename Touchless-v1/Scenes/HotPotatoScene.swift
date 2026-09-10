import SwiftUI
import AppKit

// 1. Flight States of the Hot Durian
enum DurianState {
    case arriving    // Arcs in from off-screen
    case holding     // Floating in zone, heating up rapidly
    case launched    // Swatted away with high velocity
    case burnt       // Overheated / exploded from holding too long
}

// 2. Particle Model
struct HeatParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var emoji: String
    var scale: CGFloat = 0.6
    var opacity: Double = 1.0
}

// 3. Floating Pass Reaction Badge
struct PassBadge: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var text: String
    var color: Color
    var scale: CGFloat = 0.6
    var opacity: Double = 1.0
}

struct HotPotatoScene: View {
    // 🔧 STANDARD CONTRACT
    @ObservedObject var engine: TrackingEngine
    @Binding var score: Int
    @Binding var progressText: String
    
    var playerZone: PlayerZone = .solo
    var onComplete: (Bool) -> Void
    
    // 🥔 Hot Durian States
    @State private var durianPosition: CGPoint = CGPoint(x: 200, y: 200)
    @State private var durianVelocity: CGPoint = .zero
    @State private var durianState: DurianState = .arriving
    @State private var durianRotation: Double = 0.0
    @State private var durianScale: CGFloat = 0.2
    @State private var heatLevel: CGFloat = 0.0           // 0.0 (fresh) -> 1.0 (exploding)
    @State private var holdStartTime: Date = Date()
    @State private var passCount: Int = 0
    @State private var streakCount: Int = 0
    
    // 🖐️ Hand Movement Tracking
    @State private var previousHandX: CGFloat = 0.0
    @State private var previousHandY: CGFloat = 0.0
    @State private var handVelocityX: CGFloat = 0.0
    @State private var handVelocityY: CGFloat = 0.0
    @State private var handCursor: CGPoint? = nil
    @State private var isHandDetected: Bool = false
    
    // 🔥 Particle Systems
    @State private var particles: [HeatParticle] = []
    @State private var badges: [PassBadge] = []
    
    // 🎨 Cached SVG Asset
    @State private var durianImage: NSImage? = nil
    
    private let durianRadius: CGFloat = 62.0
    private let heatDuration: Double = 2.2                // Seconds before durian overheats
    
    var body: some View {
        GeometryReader { geo in
            let centerPoint = CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.48)
            
            ZStack {
                // ==========================================
                // 1. PARTICLES (Smoke, Steam & Flames)
                // ==========================================
                ForEach(particles) { p in
                    Text(p.emoji)
                        .font(.system(size: 26))
                        .scaleEffect(p.scale)
                        .opacity(p.opacity)
                        .position(x: p.x, y: p.y)
                }
                
                // ==========================================
                // 2. THE SIZZLING HOT DURIAN
                // ==========================================
                VStack(spacing: 6) {
                    // Temperature Heat Gauge (Only visible during holding)
                    if durianState == .holding {
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 90, height: 16)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: heatLevel > 0.7 ? [Color.yellow, Color.red] : [Color.green, Color.orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(8, 90 * heatLevel), height: 16)
                            
                            HStack {
                                Spacer()
                                Text(heatLevel > 0.75 ? "🔥 DANGER!" : "♨️ HOT")
                                    .font(.system(size: 9, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.trailing, 6)
                            }
                            .frame(width: 90)
                        }
                        .shadow(color: heatLevel > 0.7 ? .red.opacity(0.8) : .orange.opacity(0.5), radius: 6)
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Durian Image with Dynamic Heat Glow & Jiggle
                    durianView
                        .frame(width: durianRadius * 2, height: durianRadius * 2)
                        .rotationEffect(.degrees(durianRotation + (durianState == .holding ? Double.random(in: -heatLevel * 9...heatLevel * 9) : 0)))
                        .scaleEffect(durianScale)
                        .shadow(
                            color: heatLevel > 0.65 ? Color.red.opacity(0.9) : Color.orange.opacity(0.6),
                            radius: 10 + (heatLevel * 22)
                        )
                }
                .position(durianPosition)
                
                // ==========================================
                // 3. FLOATING PASS REACTION BADGES
                // ==========================================
                ForEach(badges) { badge in
                    Text(badge.text)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(badge.color.opacity(0.9)))
                        .shadow(color: badge.color, radius: 10)
                        .scaleEffect(badge.scale)
                        .opacity(badge.opacity)
                        .position(x: badge.x, y: badge.y)
                }
                
                // ==========================================
                // 4. HAND / SWIPER VISUAL TOUCH
                // ==========================================
                if let pos = handCursor, isHandDetected {
                    Circle()
                        .fill(RadialGradient(colors: [Color.white.opacity(0.8), Color.orange.opacity(0.4), Color.clear], center: .center, startRadius: 2, endRadius: 28))
                        .frame(width: 56, height: 56)
                        .position(pos)
                        .animation(.interactiveSpring(response: 0.08, dampingFraction: 0.8), value: pos)
                }
            }
            .contentShape(Rectangle())
            // Mouse/Trackpad Drag/Swipe Gesture for instant testing
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isHandDetected = true
                        handCursor = value.location
                        let dx = value.location.x - (previousHandX == 0 ? value.location.x : previousHandX)
                        let dy = value.location.y - (previousHandY == 0 ? value.location.y : previousHandY)
                        previousHandX = value.location.x
                        previousHandY = value.location.y
                        handVelocityX = dx * 1.5
                        handVelocityY = dy * 1.5
                        
                        checkSwatAt(point: value.location, velocity: CGPoint(x: dx * 2.0, y: dy * 2.0), in: geo.size)
                    }
                    .onEnded { _ in
                        handCursor = nil
                        previousHandX = 0
                        previousHandY = 0
                    }
            )
            .onAppear {
                loadSVG()
                progressText = "PASSED: 0 🔥"
                spawnNewDurian(in: geo.size, fromLeft: Bool.random())
            }
            // Physics and Heat Loop
            .background(
                TimelineView(.animation(minimumInterval: 0.033)) { timeline in
                    Color.clear
                        .onChange(of: timeline.date) {
                            updateDurianPhysics(in: geo.size, targetCenter: centerPoint)
                        }
                }
            )
            .onChange(of: engine.hands) {
                processHandTracking(in: geo.size)
            }
        }
    }
    
    // ==========================================
    // 🎨 DURIAN VIEW
    // ==========================================
    private var durianView: some View {
        Group {
            if let img = durianImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.6, green: 0.55, blue: 0.2))
                    Text("🥔")
                        .font(.system(size: 60))
                }
            }
        }
    }
    
    // ==========================================
    // 🚀 LOAD ASSETS
    // ==========================================
    private func loadSVG() {
        if let url = Bundle.main.url(forResource: "Hot Potato - Durian Edition", withExtension: "svg"),
           let img = NSImage(contentsOf: url) {
            durianImage = img
            return
        }
        let fallbackPaths = [
            "Touchless-V1/Touchless-v1/Assets/game-assets/hot-potato/Hot Potato - Durian Edition.svg",
            "Touchless-v1/Assets/game-assets/hot-potato/Hot Potato - Durian Edition.svg"
        ]
        for path in fallbackPaths {
            if let img = NSImage(contentsOf: URL(fileURLWithPath: path)) {
                durianImage = img
                return
            }
        }
    }
    
    // ==========================================
    // 🥔 SPAWNING & FLIGHT LIFECYCLE
    // ==========================================
    private func spawnNewDurian(in size: CGSize, fromLeft: Bool) {
        let spawnX: CGFloat = fromLeft ? -durianRadius * 1.5 : size.width + durianRadius * 1.5
        let spawnY: CGFloat = CGFloat.random(in: size.height * 0.3...size.height * 0.5)
        
        durianPosition = CGPoint(x: spawnX, y: spawnY)
        durianScale = 0.4
        durianRotation = Double.random(in: -30...30)
        durianState = .arriving
        heatLevel = 0.0
        
        let targetCenter = CGPoint(x: size.width * 0.5, y: size.height * 0.48)
        let distanceX = targetCenter.x - spawnX
        let distanceY = targetCenter.y - spawnY
        
        // Calculate arc velocity towards center
        durianVelocity = CGPoint(x: distanceX * 0.08, y: distanceY * 0.08 - 2.5)
    }
    
    // ==========================================
    // ⚙️ PHYSICS & HEAT TIMER LOOP
    // ==========================================
    private func updateDurianPhysics(in size: CGSize, targetCenter: CGPoint) {
        switch durianState {
        case .arriving:
            // Arc towards center
            durianPosition.x += durianVelocity.x
            durianPosition.y += durianVelocity.y
            durianVelocity.y += 0.3 // gravity arc
            durianRotation += 6.0
            durianScale = min(1.0, durianScale + 0.04)
            
            // Reached destination zone center
            let dist = hypot(durianPosition.x - targetCenter.x, durianPosition.y - targetCenter.y)
            if dist < 35.0 || (durianVelocity.y > 0 && durianPosition.y >= targetCenter.y) {
                durianPosition = targetCenter
                durianVelocity = .zero
                durianState = .holding
                holdStartTime = Date()
                heatLevel = 0.0
                AudioManager.shared.playSFX("whoosh")
            }
            
        case .holding:
            // Heat is building up!
            let elapsed = Date().timeIntervalSince(holdStartTime)
            heatLevel = CGFloat(min(1.0, elapsed / heatDuration))
            
            // Emit steam and flame particles as it gets hotter
            if Double.random(in: 0...1) < (0.25 + Double(heatLevel) * 0.5) {
                let emoji = heatLevel > 0.65 ? (Bool.random() ? "🔥" : "♨️") : "💨"
                emitParticle(
                    at: CGPoint(
                        x: durianPosition.x + CGFloat.random(in: -20...20),
                        y: durianPosition.y + CGFloat.random(in: -20...20)
                    ),
                    emoji: emoji,
                    vy: CGFloat.random(in: (-4.0)...(-1.5))
                )
            }
            
            // Overheat explosion if player didn't swat in time!
            if heatLevel >= 1.0 {
                triggerOverheatExplosion(in: size)
            }
            
        case .launched:
            // Flying off-screen rapidly
            durianPosition.x += durianVelocity.x
            durianPosition.y += durianVelocity.y
            durianVelocity.y += 0.4
            durianRotation += durianVelocity.x * 0.8
            
            // Spark trail
            if Double.random(in: 0...1) < 0.45 {
                emitParticle(at: durianPosition, emoji: "✨", vy: CGFloat.random(in: -1...1))
            }
            
            // Clean up when completely off-screen, then spawn next incoming durian!
            let isOffscreen = durianPosition.x < -120 || durianPosition.x > (size.width + 120) || durianPosition.y > (size.height + 150)
            if isOffscreen {
                durianState = .arriving
                let comingFromOpposite = durianVelocity.x > 0 ? false : true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    spawnNewDurian(in: size, fromLeft: comingFromOpposite)
                }
            }
            
        case .burnt:
            // Drops down smoking
            durianPosition.y += durianVelocity.y
            durianVelocity.y += 0.8
            durianScale = max(0.1, durianScale - 0.03)
            durianRotation += 12.0
            
            if durianPosition.y > size.height + 100 {
                durianState = .arriving
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    spawnNewDurian(in: size, fromLeft: Bool.random())
                }
            }
        }
        
        // Update particles
        for i in particles.indices {
            particles[i].x += particles[i].vx
            particles[i].y += particles[i].vy
            particles[i].opacity -= 0.04
            particles[i].scale = max(0.1, particles[i].scale - 0.015)
        }
        particles.removeAll { $0.opacity <= 0.05 }
    }
    
    // ==========================================
    // 🖐️ HAND TRACKING & SWAT DETECTION
    // ==========================================
    private func processHandTracking(in size: CGSize) {
        let validHands = engine.hands.filter {
            CoordinateMapper.belongsToZone(rawX: $0.indexTip.x, zone: playerZone)
        }
        
        guard let primaryHand = validHands.first else {
            isHandDetected = false
            handCursor = nil
            return
        }
        
        isHandDetected = true
        let trackingPoint = primaryHand.center != .zero ? primaryHand.center : primaryHand.indexTip
        let localPoint = CoordinateMapper.localPoint(rawPoint: trackingPoint, zone: playerZone, screenSize: size)
        handCursor = localPoint
        
        // Compute hand velocity
        let dx = localPoint.x - (previousHandX == 0 ? localPoint.x : previousHandX)
        let dy = localPoint.y - (previousHandY == 0 ? localPoint.y : previousHandY)
        previousHandX = localPoint.x
        previousHandY = localPoint.y
        handVelocityX = dx
        handVelocityY = dy
        
        checkSwatAt(point: localPoint, velocity: CGPoint(x: dx, y: dy), in: size)
    }
    
    // ==========================================
    // 💥 SWAT COLLISION & REACTION
    // ==========================================
    private func checkSwatAt(point: CGPoint, velocity: CGPoint, in size: CGSize) {
        guard durianState == .holding else { return }
        
        let dist = hypot(point.x - durianPosition.x, point.y - durianPosition.y)
        let hitRadius = durianRadius + 42.0 // Forgiving hit radius
        
        if dist < hitRadius {
            launchDurian(byVelocity: velocity, in: size)
        }
    }
    
    private func launchDurian(byVelocity velocity: CGPoint, in size: CGSize) {
        durianState = .launched
        passCount += 1
        streakCount += 1
        
        // Compute launch vector: if hand was moving, launch in that direction, otherwise launch outward
        var launchVx: CGFloat = velocity.x * 2.0
        if abs(launchVx) < 8.0 {
            // Default outward pass towards opponent / border
            launchVx = (durianPosition.x < size.width * 0.5) ? 18.0 : -18.0
        } else {
            launchVx = max(-26.0, min(26.0, launchVx))
        }
        
        let launchVy: CGFloat = min(-8.0, velocity.y * 1.5 - 6.0)
        durianVelocity = CGPoint(x: launchVx, y: launchVy)
        
        // Reflex score calculation
        let holdTime = Date().timeIntervalSince(holdStartTime)
        let isQuickPass = holdTime < 0.85
        
        let pointsEarned = isQuickPass ? 25 : 15
        score += pointsEarned
        
        // Feedback Badges
        let badgeText = isQuickPass ? "⚡ QUICK PASS! +25" : (streakCount >= 3 ? "🔥 STREAK x\(streakCount)! +15" : "👋 PASS! +15")
        let badgeColor: Color = isQuickPass ? Color.yellow : (streakCount >= 3 ? Color.orange : Color.green)
        spawnBadge(at: CGPoint(x: durianPosition.x, y: durianPosition.y - 60), text: badgeText, color: badgeColor)
        
        // Impact bursts
        for _ in 0..<4 {
            emitParticle(
                at: durianPosition,
                emoji: Bool.random() ? "💥" : "🚀",
                vy: CGFloat.random(in: -4...2)
            )
        }
        
        // Audio
        AudioManager.shared.playSFX("stomp")
        if streakCount % 3 == 0 || isQuickPass {
            AudioManager.shared.playSFX("win_8bit")
        }
        
        progressText = "PASSED: \(passCount) 🔥"
    }
    
    private func triggerOverheatExplosion(in size: CGSize) {
        durianState = .burnt
        streakCount = 0
        durianVelocity = CGPoint(x: CGFloat.random(in: -3...3), y: 4.0)
        
        // Explosion particles
        for _ in 0..<6 {
            emitParticle(
                at: durianPosition,
                emoji: ["💥", "💨", "🔥", "⚠️"].randomElement()!,
                vy: CGFloat.random(in: -5...1)
            )
        }
        
        spawnBadge(at: CGPoint(x: durianPosition.x, y: durianPosition.y - 60), text: "💥 TOO HOT!", color: .red)
        AudioManager.shared.playSFX("whoosh")
    }
    
    // ==========================================
    // ✨ FX HELPERS
    // ==========================================
    private func emitParticle(at point: CGPoint, emoji: String, vy: CGFloat) {
        let p = HeatParticle(
            x: point.x,
            y: point.y,
            vx: CGFloat.random(in: -2...2),
            vy: vy,
            emoji: emoji,
            scale: CGFloat.random(in: 0.6...1.0)
        )
        particles.append(p)
    }
    
    private func spawnBadge(at point: CGPoint, text: String, color: Color) {
        let badge = PassBadge(x: point.x, y: point.y, text: text, color: color)
        badges.append(badge)
        
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            if let idx = badges.firstIndex(where: { $0.id == badge.id }) {
                badges[idx].scale = 1.1
            }
        }
        
        withAnimation(.easeOut(duration: 0.55).delay(0.25)) {
            if let idx = badges.firstIndex(where: { $0.id == badge.id }) {
                badges[idx].y -= 35
                badges[idx].opacity = 0.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            badges.removeAll { $0.id == badge.id }
        }
    }
}

// 🔧 PREVIEW SUPPORT
struct HotPotatoScene_Previews: PreviewProvider {
    static var previews: some View {
        HotPotatoScene(
            engine: TrackingEngine(),
            score: .constant(60),
            progressText: .constant("PASSED: 4 🔥"),
            playerZone: .solo,
            onComplete: { _ in }
        )
        .background(Color.blue.opacity(0.8))
    }
}
