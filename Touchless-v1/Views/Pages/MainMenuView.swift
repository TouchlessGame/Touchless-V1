import SwiftUI

struct MainMenuView: View {
    @ObservedObject var engine: TrackingEngine
    var onPlaySolo: (Int) -> Void
    var onPlayVS: (Int) -> Void
    var onDebug: () -> Void
    
    @State private var isPulsing = false
    @State private var selectedRounds: Int = 5
    
    // 🔊 Volume State
    @State private var volume: Float = 0.5
    @State private var isMuted: Bool = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            
            HStack(spacing: 0) {
                
                // 👈 LEFT COLUMN (Main Content, Left Aligned)
                VStack(alignment: .leading, spacing: 30) {
                    Spacer()
                    
                    // --- 1. INTEGRATED, ANIMATED ANGER EMBLEM ---
                    ZStack(alignment: .center) {
                        // Base tilted house element
                        Text("🏠")
                            .font(.system(size: 110))
                            .offset(x: -200, y: -100)
                            .rotationEffect(.degrees(-15))
                            .shadow(color: .red.opacity(0.4), radius: 10)
                        
                        // The Title
                        VStack(alignment: .leading, spacing: -25) {
                            Text("NOISY")
                                .font(.system(size: 110, weight: .black, design: .rounded))
                                .foregroundColor(.red)
                                .shadow(color: .red.opacity(0.6), radius: isPulsing ? 20 : 10)
                                .zIndex(1)
                            
                            Text("NEIGHBOR")
                                .font(.system(size: 85, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .black, radius: 3)
                                .zIndex(0)
                        }
                        .rotationEffect(.degrees(-4))
                        .offset(x: 20)

                        // 😡 NEAT ACCENT EMOJIS (Just 3 for flavor)
                        Text("💢") // Anger vein symbol
                            .font(.system(size: 45))
                            .offset(x: 150, y: -80) // Top right
                            .rotationEffect(.degrees(15))
                        
                        Text("🔊") // Noise
                            .font(.system(size: 40))
                            .offset(x: -220, y: 70) // Bottom left
                            .rotationEffect(.degrees(-10))
                        
                        Text("😡") // Annoyed neighbor
                            .font(.system(size: 35))
                            .offset(x: 130, y: 40) // Bottom right
                    }
                    // The entire integrated emblem pulses
                    .rotationEffect(.degrees(isPulsing ? -2 : 1))
                    .scaleEffect(isPulsing ? 1.03 : 0.97)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
                    
                    // --- 2. UPGRADED GOAL MISSION CARD ---
                    HStack(alignment: .center, spacing: 15) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 35))
                            .foregroundColor(.yellow)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MISSION OBJECTIVE")
                                .font(.system(.caption, design: .monospaced).bold())
                                .foregroundColor(.yellow)
                            
                            Text("MASTER THE CHALLENGES. RACK UP COMPLAINTS.")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Be the worst tenant on the floor.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(15)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.yellow.opacity(0.6), lineWidth: 2)
                            .background(Color.yellow.opacity(0.05).cornerRadius(15))
                    )
                    
                    // --- 3. ROUND SELECTOR HUD ---
                    VStack(alignment: .leading, spacing: 10) {
                        Text("GAME DURATION (ROUNDS)")
                            .font(.caption.bold())
                            .foregroundColor(.yellow)
                            .tracking(2)
                        
                        HStack(spacing: 20) {
                            Button(action: { if selectedRounds > 4 { selectedRounds -= 1 } }) {
                                Image(systemName: "minus.square.fill").font(.title)
                            }
                            Text("\(selectedRounds) ROUNDS")
                                .font(.system(size: 24, weight: .black, design: .monospaced))
                                .frame(width: 140, alignment: .leading)
                            
                            Button(action: { if selectedRounds < 10 { selectedRounds += 1 } }) {
                                Image(systemName: "plus.square.fill").font(.title)
                            }
                        }
                        .foregroundColor(.white)
                        
                        Text("+ 1 REDEMPTION ROUND (67)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                    }

                    // --- 4. NAVIGATION BUTTONS (Solid filled) ---
                    VStack(alignment: .leading, spacing: 15) {
                        Button(action: { onPlaySolo(selectedRounds) }) {
                            MenuButtonView(title: "🧍‍♂️ SOLO CHAOS", color: .blue)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { onPlayVS(selectedRounds) }) {
                            MenuButtonView(title: "⚔️ VS MODE", color: .red)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { onDebug() }) {
                            MenuButtonView(title: "🛠️ PRACTICE GYM", color: .gray)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                    
                    Text("⚠️ Best played in full screen")
                        .font(.headline.bold())
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.bottom, 20)
                }
                .padding(.leading, 60)
                
                Spacer()
                
                // 👉 RIGHT COLUMN (Audio Controls)
                VStack {
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 5) {
                        Text("ADJUST BACKGROUND MUSIC")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                        
                        HStack(spacing: 10) {
                            Button(action: {
                                isMuted.toggle()
                                AudioManager.shared.masterVolume = isMuted ? 0 : volume
                            }) {
                                Image(systemName: isMuted || volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(isMuted ? .red : .white)
                            }

                            Slider(value: $volume, in: 0...1)
                                .tint(.red)
                                .frame(width: 120)
                                .onChange(of: volume) { oldValue, newValue in
                                    isMuted = false
                                    AudioManager.shared.masterVolume = newValue
                                }
                            
                            Text("\(Int(volume * 100))%")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(width: 35, alignment: .trailing)
                        }
                    }
                    .padding(.trailing, 40)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear { isPulsing = true }
    }
}

// 🏗️ HELPER: Solid Fill Button
struct MenuButtonView: View {
    var title: String
    var color: Color
    
    var body: some View {
        Text(title)
            .font(.title2.bold())
            .foregroundColor(.white)
            .frame(width: 300, alignment: .center)
            .padding(.vertical, 15)
            .background(color)
            .cornerRadius(15)
            .shadow(color: color.opacity(0.6), radius: 8, y: 5)
    }
}
