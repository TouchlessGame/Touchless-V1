import SwiftUI

// 1. Energetic Floating Burst Model for 67 Pumps
struct PumpBurst: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var text: String
    var scale: CGFloat = 0.5
    var opacity: Double = 1.0
    var color: Color = .yellow
}

struct BonusScene: View {
    @ObservedObject var engine: TrackingEngine
    @Binding var score: Int
    @Binding var progressText: String
    
    var playerZone: PlayerZone = .solo
    var onComplete: (Bool) -> Void
    
    // 🔧 Game State
    @State private var pumps: Int = 0
    @State private var leftIsDown: Bool = true
    @State private var rightIsDown: Bool = true
    @State private var singleIsDown: Bool = true
    @State private var mouseIsDown: Bool = true
    
    // Visual Polish & Bursts
    @State private var flashOpacity: Double = 0.0
    @State private var bursts: [PumpBurst] = []
    @State private var lastPumpArm: String = ""
    @State private var pulsePumps: CGFloat = 1.0
    
    // 📐 THRESHOLD LINES (Normalized Y: 0.0 = top, 1.0 = bottom)
    let liftLine: CGFloat = 0.48
    let resetLine: CGFloat = 0.66
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. Interactive Drag Gesture layer for mouse/trackpad Xcode testing
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handleMouseDrag(location: value.location, size: geo.size)
                            }
                    )
                
                // 2. Gold/Yellow Edge Glow on Pump
                RadialGradient(
                    gradient: Gradient(colors: [Color.yellow.opacity(flashOpacity), Color.clear]),
                    center: .center,
                    startRadius: 80,
                    endRadius: geo.size.width * 0.75
                )
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.2), value: flashOpacity)
                
                // 3. Mirror Magic Glassmorphic Guide Zones (Subtle & high camera visibility)
                VStack(spacing: 0) {
                    // TOP LIFT ZONE (Green)
                    ZStack(alignment: .bottom) {
                        LinearGradient(
                            colors: [Color.green.opacity(0.18), Color.green.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        
                        // Lift boundary line with glowing indicator
                        HStack {
                            Label("⬆️ LIFT ARMS ABOVE LINE", systemImage: "arrow.up.circle.fill")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundColor(.green)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(.ultraThinMaterial).shadow(color: .green.opacity(0.5), radius: 6))
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 6)
                        
                        Rectangle()
                            .fill(Color.green.opacity(0.8))
                            .frame(height: 2)
                            .shadow(color: .green, radius: 4)
                    }
                    .frame(height: geo.size.height * liftLine)
                    
                    // MIDDLE TRANSPARENT GAP (Crystal clear camera reflection)
                    Spacer()
                    
                    // BOTTOM RESET ZONE (Orange/Red)
                    ZStack(alignment: .top) {
                        Rectangle()
                            .fill(Color.red.opacity(0.7))
                            .frame(height: 2)
                            .shadow(color: .red, radius: 4)
                        
                        LinearGradient(
                            colors: [Color.red.opacity(0.04), Color.red.opacity(0.18)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        
                        // Reset boundary line indicator
                        HStack {
                            Spacer()
                            Label("⬇️ RESET BELOW LINE", systemImage: "arrow.down.circle.fill")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(.ultraThinMaterial).shadow(color: .orange.opacity(0.5), radius: 6))
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 6)
                    }
                    .frame(height: geo.size.height * (1.0 - resetLine))
                }
                .allowsHitTesting(false)
                
                // 4. Center Top 67 Pump Badge
                VStack {
                    HStack(spacing: 12) {
                        Text("6️⃣7️⃣")
                            .font(.system(size: 32))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PUMP REDEMPTION")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.yellow.opacity(0.9))
                                .tracking(2)
                            
                            Text("\(pumps) PUMPS")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .scaleEffect(pulsePumps)
                        }
                        
                        if !lastPumpArm.isEmpty {
                            Text(lastPumpArm)
                                .font(.system(size: 12, weight: .black))
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.yellow))
                                .transition(.scale)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.yellow.opacity(0.6), lineWidth: 1.5)
                            )
                            .shadow(color: .yellow.opacity(0.3), radius: 10)
                    )
                    .padding(.top, geo.size.height * 0.12)
                    
                    Spacer()
                }
                .allowsHitTesting(false)
                
                // 5. Floating Pump Bursts & Particles
                ForEach(bursts) { burst in
                    Text(burst.text)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(burst.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .scaleEffect(burst.scale)
                        .opacity(burst.opacity)
                        .position(x: burst.x, y: burst.y)
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: engine.hands) {
                checkAlternatingPump(geoSize: geo.size)
            }
            .onAppear {
                progressText = "67 PUMPS: \(pumps)"
            }
        }
    }
    
    // MARK: - Hand Tracking Logic
    private func checkAlternatingPump(geoSize: CGSize) {
        // 🛑 Filter hands belonging to this player's zone
        let validHands = engine.hands.filter { CoordinateMapper.belongsToZone(rawX: $0.indexTip.x, zone: playerZone) }
        
        guard !validHands.isEmpty else { return }
        
        if validHands.count >= 2 {
            // Dual Hand Alternating Mode
            let hand1 = validHands[0]
            let hand2 = validHands[1]
            
            let leftHand = hand1.indexTip.x > hand2.indexTip.x ? hand1 : hand2
            let rightHand = hand1.indexTip.x > hand2.indexTip.x ? hand2 : hand1
            
            // Process Left Hand
            if leftHand.indexTip.y < liftLine && leftIsDown {
                leftIsDown = false
                triggerPump(at: CGPoint(x: (1.0 - leftHand.indexTip.x) * geoSize.width, y: leftHand.indexTip.y * geoSize.height), arm: "LEFT 💪")
            } else if leftHand.indexTip.y > resetLine && !leftIsDown {
                leftIsDown = true
            }
            
            // Process Right Hand
            if rightHand.indexTip.y < liftLine && rightIsDown {
                rightIsDown = false
                triggerPump(at: CGPoint(x: (1.0 - rightHand.indexTip.x) * geoSize.width, y: rightHand.indexTip.y * geoSize.height), arm: "RIGHT 💪")
            } else if rightHand.indexTip.y > resetLine && !rightIsDown {
                rightIsDown = true
            }
        } else {
            // Single Hand Fallback (Inclusive for seated or single-arm players)
            let hand = validHands[0]
            if hand.indexTip.y < liftLine && singleIsDown {
                singleIsDown = false
                triggerPump(at: CGPoint(x: (1.0 - hand.indexTip.x) * geoSize.width, y: hand.indexTip.y * geoSize.height), arm: "PUMP! 🔥")
            } else if hand.indexTip.y > resetLine && !singleIsDown {
                singleIsDown = true
            }
        }
    }
    
    // MARK: - Mouse / Trackpad Drag Fallback
    private func handleMouseDrag(location: CGPoint, size: CGSize) {
        guard size.height > 0 else { return }
        let normY = location.y / size.height
        
        if normY < liftLine && mouseIsDown {
            mouseIsDown = false
            triggerPump(at: location, arm: "PUMP! ⚡️")
        } else if normY > resetLine && !mouseIsDown {
            mouseIsDown = true
        }
    }
    
    // MARK: - Pump Execution & Visual Spark
    private func triggerPump(at pos: CGPoint, arm: String) {
        AudioManager.shared.playSFX("whoosh")
        
        pumps += 1
        score += 30
        lastPumpArm = arm
        progressText = "67 PUMPS: \(pumps)"
        
        // Milestone audio fanfare every 5 pumps
        if pumps % 5 == 0 {
            AudioManager.shared.playSFX("win_8bit")
        }
        
        // Flash aura
        flashOpacity = 0.35
        withAnimation(.easeOut(duration: 0.25)) {
            flashOpacity = 0.0
        }
        
        // Pulse badge scale
        withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
            pulsePumps = 1.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.2)) {
                pulsePumps = 1.0
            }
        }
        
        // Spawn energetic burst particles
        spawnBursts(at: pos)
    }
    
    private func spawnBursts(at pos: CGPoint) {
        let options = ["67!", "+30", "🔥", "💪", "⚡️"]
        let chosen = options.randomElement() ?? "67!"
        
        var burst = PumpBurst(
            x: pos.x + CGFloat.random(in: -20...20),
            y: pos.y + CGFloat.random(in: -10...10),
            text: chosen,
            scale: 0.6,
            opacity: 1.0,
            color: [.yellow, .orange, .green, .cyan].randomElement() ?? .yellow
        )
        bursts.append(burst)
        
        let burstId = burst.id
        withAnimation(.easeOut(duration: 0.55)) {
            if let idx = bursts.firstIndex(where: { $0.id == burstId }) {
                bursts[idx].y -= 60
                bursts[idx].scale = 1.2
                bursts[idx].opacity = 0.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            bursts.removeAll { $0.id == burstId }
        }
    }
}

// 🔧 PREVIEW
struct BonusScene_Previews: PreviewProvider {
    static var previews: some View {
        BonusScene(
            engine: TrackingEngine(),
            score: .constant(500),
            progressText: .constant("67 PUMPS: 0"),
            onComplete: { _ in }
        )
        .background(Color.black)
    }
}
