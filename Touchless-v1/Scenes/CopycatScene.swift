import SwiftUI
import Combine

// 1. Holographic Target Zone Model
struct TargetZone: Identifiable {
    let id = UUID()
    var normX: CGFloat
    var normY: CGFloat
    var emoji: String
    var label: String
    var isSatisfied: Bool = false
    var pulseScale: CGFloat = 1.0
}

// 2. Pose Blueprint
struct PoseTemplate: Identifiable {
    let id = UUID()
    var name: String
    var catMood: String
    var hint: String
    var zones: [TargetZone]
}

// 3. Floating Celebration Particle
struct PoseParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var emoji: String
    var scale: CGFloat = 0.5
    var opacity: Double = 1.0
    var vy: CGFloat = -3.0
    var vx: CGFloat = 0.0
}

struct CopycatScene: View {
    @ObservedObject var engine: TrackingEngine
    @Binding var score: Int
    @Binding var progressText: String
    
    var playerZone: PlayerZone = .solo
    var onComplete: (Bool) -> Void
    
    // 🔧 Game State
    @State private var poseIndex: Int = 0
    @State private var matchedCount: Int = 0
    @State private var holdProgress: CGFloat = 0.0 // 0.0 to 1.0
    @State private var isHoldingAll: Bool = false
    @State private var isCelebrating: Bool = false
    
    // Visual Polish
    @State private var celebrationBanner: String = ""
    @State private var celebrationOpacity: Double = 0.0
    @State private var celebrationScale: CGFloat = 0.5
    @State private var particles: [PoseParticle] = []
    @State private var catBounce: CGFloat = 1.0
    @State private var ringRotation: Double = 0.0
    
    // Mouse Testing Support
    @State private var mousePos: CGPoint? = nil
    
    // Game Loop Timer (25 FPS for smooth hold & particles)
    private let timer = Timer.publish(every: 0.04, on: .main, in: .common).autoconnect()
    
    // 🎭 Predefined Silly Poses (All Hand Emojis)
    @State private var poses: [PoseTemplate] = [
        PoseTemplate(
            name: "TOS BARENG! 🫸🫷",
            catMood: "🫸🫷",
            hint: "Tos kedua tanganmu barengan! 🫸🫷",
            zones: [
                TargetZone(normX: 0.38, normY: 0.45, emoji: "🫸", label: "TOS KIRI"),
                TargetZone(normX: 0.62, normY: 0.45, emoji: "🫷", label: "TOS KANAN")
            ]
        ),
        PoseTemplate(
            name: "DOUBLE PEACE! ✌️",
            catMood: "✌️",
            hint: "Dua jari peace kanan & kiri!",
            zones: [
                TargetZone(normX: 0.28, normY: 0.40, emoji: "✌️", label: "PEACE KIRI"),
                TargetZone(normX: 0.72, normY: 0.40, emoji: "✌️", label: "PEACE KANAN")
            ]
        ),
        PoseTemplate(
            name: "HEART HANDS! 🫶",
            catMood: "🫶",
            hint: "Bentuk lambang hati dengan dua tangan!",
            zones: [
                TargetZone(normX: 0.42, normY: 0.50, emoji: "🫶", label: "HEART KIRI"),
                TargetZone(normX: 0.58, normY: 0.50, emoji: "🫶", label: "HEART KANAN")
            ]
        ),
        PoseTemplate(
            name: "OPEN HANDS! 🖐️",
            catMood: "🖐️",
            hint: "Buka kedua telapak tangan lebar-lebar!",
            zones: [
                TargetZone(normX: 0.26, normY: 0.32, emoji: "🖐️", label: "TELAPAK KIRI"),
                TargetZone(normX: 0.74, normY: 0.32, emoji: "🖐️", label: "TELAPAK KANAN")
            ]
        ),
        PoseTemplate(
            name: "DOUBLE THUMBS UP! 👍",
            catMood: "👍",
            hint: "Acungkan dua jempol mantap!",
            zones: [
                TargetZone(normX: 0.32, normY: 0.46, emoji: "👍", label: "JEMPOL KIRI"),
                TargetZone(normX: 0.68, normY: 0.46, emoji: "👍", label: "JEMPOL KANAN")
            ]
        ),
        PoseTemplate(
            name: "POINT UP! 👆",
            catMood: "👆",
            hint: "Tunjuk jari telunjuk tinggi ke atas!",
            zones: [
                TargetZone(normX: 0.50, normY: 0.20, emoji: "👆", label: "TUNJUK ATAS")
            ]
        ),
        PoseTemplate(
            name: "FIST BUMP! 👊",
            catMood: "👊",
            hint: "Kepalkan tangan siap tos kepal!",
            zones: [
                TargetZone(normX: 0.34, normY: 0.48, emoji: "👊", label: "KEPAL KIRI"),
                TargetZone(normX: 0.66, normY: 0.48, emoji: "👊", label: "KEPAL KANAN")
            ]
        )
    ]
    
    private let matchRadius: CGFloat = 80.0
    private let holdDurationSeconds: Double = 0.40
    
    var currentPose: PoseTemplate {
        poses[poseIndex % poses.count]
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. Transparent Drag Surface for Mouse / Trackpad Testing
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                mousePos = value.location
                            }
                            .onEnded { _ in
                                mousePos = nil
                            }
                    )
                
                // 2. Holographic Guide Connecting Line (when 2 zones exist)
                if currentPose.zones.count == 2 {
                    let z1 = currentPose.zones[0]
                    let z2 = currentPose.zones[1]
                    Path { path in
                        path.move(to: CGPoint(x: z1.normX * geo.size.width, y: z1.normY * geo.size.height))
                        path.addLine(to: CGPoint(x: z2.normX * geo.size.width, y: z2.normY * geo.size.height))
                    }
                    .stroke(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.3), Color.purple.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, dash: [8, 6])
                    )
                    .allowsHitTesting(false)
                }
                
                // 3. AR Holographic Target Rings on Screen
                ForEach(currentPose.zones) { zone in
                    renderTargetZone(zone: zone, screenSize: geo.size)
                }
                
                // 4. Mascot Top Header & Instruction Pill
                VStack(spacing: 8) {
                    HStack(spacing: 14) {
                        // Animated Cat Avatar
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 58, height: 58)
                                .overlay(
                                    Circle()
                                        .stroke(Color.yellow.opacity(0.8), lineWidth: 2)
                                )
                                .shadow(color: .yellow.opacity(0.4), radius: 8)
                            
                            Text(currentPose.catMood)
                                .font(.system(size: 34))
                                .scaleEffect(catBounce)
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text("COPYCAT HAND POSE")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.yellow)
                                    .tracking(2)
                                
                                // Mini Progress Dots
                                HStack(spacing: 4) {
                                    ForEach(0..<3) { i in
                                        Circle()
                                            .fill(i < matchedCount ? Color.green : Color.white.opacity(0.3))
                                            .frame(width: 7, height: 7)
                                    }
                                }
                            }
                            
                            Text(currentPose.name)
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text(currentPose.hint)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        
                        Spacer()
                        
                        // Hold Meter
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 5)
                                .frame(width: 48, height: 48)
                            
                            Circle()
                                .trim(from: 0.0, to: holdProgress)
                                .stroke(
                                    LinearGradient(colors: [.green, .yellow], startPoint: .top, endPoint: .bottom),
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                                )
                                .frame(width: 48, height: 48)
                                .rotationEffect(.degrees(-90))
                            
                            if isHoldingAll {
                                Text("\(Int(holdProgress * 100))%")
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "hand.raised.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.yellow.opacity(0.8))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.4), radius: 12)
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    
                    Spacer()
                }
                .allowsHitTesting(false)
                
                // 5. Celebration Popups & Starburst Particles
                ForEach(particles) { p in
                    Text(p.emoji)
                        .font(.system(size: 26))
                        .scaleEffect(p.scale)
                        .opacity(p.opacity)
                        .position(x: p.x, y: p.y)
                        .allowsHitTesting(false)
                }
                
                // Banner "✨ PURRFECT MATCH! ✨"
                if isCelebrating {
                    VStack(spacing: 6) {
                        Text(celebrationBanner)
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundColor(.yellow)
                            .shadow(color: .orange, radius: 10)
                        
                        Text("+50 PTS")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundColor(.green)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.ultraThinMaterial))
                    }
                    .scaleEffect(celebrationScale)
                    .opacity(celebrationOpacity)
                    .allowsHitTesting(false)
                }
            }
            .onReceive(timer) { _ in
                updateGameLoop(screenSize: geo.size)
            }
            .onChange(of: engine.hands) {
                evaluatePoses(screenSize: geo.size)
            }
            .onAppear {
                progressText = "POSES: \(matchedCount)"
            }
        }
    }
    
    // MARK: - Render Target Zone
    @ViewBuilder
    private func renderTargetZone(zone: TargetZone, screenSize: CGSize) -> some View {
        let px = zone.normX * screenSize.width
        let py = zone.normY * screenSize.height
        
        ZStack {
            // Outer Pulsating Halo
            Circle()
                .stroke(
                    zone.isSatisfied ? Color.green : Color.cyan.opacity(0.6),
                    style: StrokeStyle(lineWidth: zone.isSatisfied ? 4 : 2, dash: [6, 4])
                )
                .frame(width: matchRadius * 2.0, height: matchRadius * 2.0)
                .rotationEffect(.degrees(ringRotation))
                .scaleEffect(zone.pulseScale)
                .shadow(color: zone.isSatisfied ? Color.green.opacity(0.8) : Color.cyan.opacity(0.4), radius: zone.isSatisfied ? 12 : 6)
            
            // Inner Target Glass Disc
            Circle()
                .fill(
                    zone.isSatisfied
                    ? Color.green.opacity(0.35)
                    : Color.blue.opacity(0.12)
                )
                .frame(width: matchRadius * 1.5, height: matchRadius * 1.5)
                .overlay(
                    Circle()
                        .stroke(zone.isSatisfied ? Color.green : Color.white.opacity(0.4), lineWidth: 1.5)
                )
            
            // Emoji & Status Icon
            VStack(spacing: 2) {
                ZStack {
                    Text(zone.emoji)
                        .font(.system(size: 34))
                        .scaleEffect(zone.isSatisfied ? 1.25 : 1.0)
                    
                    if zone.isSatisfied {
                        Text("✅")
                            .font(.system(size: 16))
                            .offset(x: 16, y: -16)
                    }
                }
                
                Text(zone.label)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundColor(zone.isSatisfied ? .green : .white.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.ultraThinMaterial))
            }
        }
        .position(x: px, y: py)
        .allowsHitTesting(false)
    }
    
    // MARK: - Pose Evaluation
    private func evaluatePoses(screenSize: CGSize) {
        guard !isCelebrating else { return }
        
        // 1. Filter hands for active player zone
        let validHands = engine.hands.filter {
            CoordinateMapper.belongsToZone(rawX: $0.indexTip.x, zone: playerZone)
        }
        
        var handPoints: [CGPoint] = []
        for hand in validHands {
            let tip = CoordinateMapper.localPoint(rawPoint: hand.indexTip, zone: playerZone, screenSize: screenSize)
            let wrist = CoordinateMapper.localPoint(rawPoint: hand.wrist, zone: playerZone, screenSize: screenSize)
            handPoints.append(tip)
            handPoints.append(wrist)
        }
        
        // Append mouse point if dragging
        if let mouse = mousePos {
            handPoints.append(mouse)
        }
        
        // 2. Check each target zone
        var allZonesSatisfied = true
        var anyZoneSatisfied = false
        
        for i in 0..<poses[poseIndex % poses.count].zones.count {
            let z = poses[poseIndex % poses.count].zones[i]
            let targetCenter = CGPoint(x: z.normX * screenSize.width, y: z.normY * screenSize.height)
            
            // Check if any tracked point is inside the match radius
            var satisfied = false
            for pt in handPoints {
                let dist = hypot(pt.x - targetCenter.x, pt.y - targetCenter.y)
                if dist < matchRadius {
                    satisfied = true
                    break
                }
            }
            
            poses[poseIndex % poses.count].zones[i].isSatisfied = satisfied
            if satisfied {
                anyZoneSatisfied = true
            } else {
                allZonesSatisfied = false
            }
        }
        
        // Accessibility: Single-hand player fallback
        // If player has only 1 hand visible and satisfies at least one zone of a 2-zone pose, count as holding
        let singleHandCredit = (validHands.count == 1 && anyZoneSatisfied && currentPose.zones.count == 2)
        
        isHoldingAll = allZonesSatisfied || singleHandCredit
    }
    
    // MARK: - Game Loop
    private func updateGameLoop(screenSize: CGSize) {
        ringRotation += 1.5
        
        // Advance hold progress when pose is struck
        if isHoldingAll && !isCelebrating {
            holdProgress = min(1.0, holdProgress + CGFloat(0.04 / holdDurationSeconds))
            
            // Subtle pulse on mascot
            catBounce = 1.0 + holdProgress * 0.2
            
            if holdProgress >= 1.0 {
                completePose(screenSize: screenSize)
            }
        } else if !isCelebrating {
            holdProgress = max(0.0, holdProgress - 0.08)
            catBounce = 1.0
        }
        
        // Update particles
        for i in 0..<particles.count {
            particles[i].y += particles[i].vy
            particles[i].x += particles[i].vx
            particles[i].opacity -= 0.03
            particles[i].scale = max(0.2, particles[i].scale + 0.02)
        }
        particles.removeAll { $0.opacity <= 0 }
    }
    
    // MARK: - Complete Pose
    private func completePose(screenSize: CGSize) {
        isCelebrating = true
        holdProgress = 0.0
        matchedCount += 1
        score += 50
        progressText = "POSES: \(matchedCount)"
        
        AudioManager.shared.playSFX("win_8bit")
        
        // Spawn particles around targets
        for z in currentPose.zones {
            let px = z.normX * screenSize.width
            let py = z.normY * screenSize.height
            spawnParticles(around: CGPoint(x: px, y: py))
        }
        
        // Banner animation
        let banners = [
            "✨ TOS MANTAP! 🫸🫷",
            "🙌 PERFECT POSE! 🙌",
            "✌️ PEACE OVERLOAD! ✌️",
            "🫶 SO SWEET! 🫶",
            "👍 JOSS GANDOS! 👍",
            "👏 TEPUK TANGAN! 👏"
        ]
        celebrationBanner = banners.randomElement() ?? "✨ PURRFECT! ✨"
        celebrationOpacity = 1.0
        celebrationScale = 0.6
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            celebrationScale = 1.15
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeOut(duration: 0.2)) {
                celebrationOpacity = 0.0
                celebrationScale = 0.8
            }
        }
        
        // Advance to next pose after brief celebration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            poseIndex += 1
            isHoldingAll = false
            isCelebrating = false
            
            // Reset zone satisfaction
            for i in 0..<poses[poseIndex % poses.count].zones.count {
                poses[poseIndex % poses.count].zones[i].isSatisfied = false
            }
        }
    }
    
    private func spawnParticles(around center: CGPoint) {
        let emojis = ["🫸", "🫷", "✌️", "🫶", "🖐️", "👍", "👏", "🙌", "👊", "👆"]
        for _ in 0..<8 {
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 3...7)
            let p = PoseParticle(
                x: center.x,
                y: center.y,
                emoji: emojis.randomElement() ?? "✨",
                scale: CGFloat.random(in: 0.6...1.2),
                opacity: 1.0,
                vy: sin(angle) * speed,
                vx: cos(angle) * speed
            )
            particles.append(p)
        }
    }
}

// 🔧 PREVIEWS
struct CopycatScene_Previews: PreviewProvider {
    static var previews: some View {
        CopycatScene(
            engine: TrackingEngine(),
            score: .constant(100),
            progressText: .constant("POSES: 0"),
            onComplete: { _ in }
        )
        .background(Color.black)
    }
}
