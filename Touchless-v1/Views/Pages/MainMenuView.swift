import SwiftUI
import AppKit

struct MainMenuView: View {
    @ObservedObject var engine: TrackingEngine
    var onPlaySolo: (Int) -> Void
    var onPlayVS: (Int) -> Void
    var onDebug: () -> Void
    
    @State private var isPulsing = false
    @State private var selectedRounds: Int = 5
    @State private var logoImage: NSImage? = MainMenuView.loadLogo()
    
    // 🔊 Volume State
    @State private var volume: Float = 0.5
    @State private var isMuted: Bool = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            
            HStack(spacing: 0) {
                
                // 👈 LEFT COLUMN (Main Content, Left Aligned)
                VStack(alignment: .leading, spacing: 24) {
                    Spacer()
                    
                    // --- 1. SIDE BY SIDE LOGO ---
                    ZStack(alignment: .leading) {
                        if let logo = logoImage {
                            Image(nsImage: logo)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 360, maxHeight: 200, alignment: .leading)
                                .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
                        } else {
                            VStack(alignment: .leading, spacing: -8) {
                                Text("Side")
                                    .font(.system(size: 80, weight: .black, design: .rounded))
                                    .foregroundColor(Color(red: 0.1, green: 0.45, blue: 0.95))
                                Text("by Side")
                                    .font(.system(size: 70, weight: .black, design: .rounded))
                                    .foregroundColor(Color(red: 0.95, green: 0.2, blue: 0.2))
                            }
                        }
                    }
                    .scaleEffect(isPulsing ? 1.02 : 0.98)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: isPulsing)
                    
                    // --- 2. MISSION CARD ---
                    HStack(alignment: .center, spacing: 15) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 32))
                            .foregroundColor(.yellow)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TOUCHLESS FAMILY PARTY")
                                .font(.system(.caption, design: .monospaced).bold())
                                .foregroundColor(.yellow)
                                .tracking(1.5)
                            
                            Text("MOVE TOGETHER. PLAY TOGETHER.")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Controller-free gesture games for all generations.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                        }
                    }
                    .padding(15)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                            )
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
                            MenuButtonView(title: "🧍‍♂️ SOLO PLAY", color: .blue)
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
            .onAppear {
                isPulsing = true
                logoImage = MainMenuView.loadLogo()
            }
        }
    }
    
    static func loadLogo() -> NSImage? {
        // 1. Try bundled high-DPI cropped PNG
        if let url = Bundle.main.url(forResource: "SideBySide - Logo", withExtension: "png") ??
                     Bundle.main.url(forResource: "SideBySide - Logo", withExtension: "png", subdirectory: "game-assets") {
            if let img = NSImage(contentsOf: url) {
                return img
            }
        }
        
        // 2. Direct file paths for PNG
        let pngPaths = [
            "Touchless-V1/Touchless-v1/Assets/game-assets/SideBySide - Logo.png",
            "Touchless-v1/Assets/game-assets/SideBySide - Logo.png",
            "/Users/clarissaaditjakra/Documents/GitHub/TouchlessGame/Touchless-V1/Touchless-v1/Assets/game-assets/SideBySide - Logo.png"
        ]
        for path in pngPaths {
            if let img = NSImage(contentsOf: URL(fileURLWithPath: path)) {
                return img
            }
        }
        
        // 3. Fallback to bundled SVG
        if let url = Bundle.main.url(forResource: "SideBySide - Logo", withExtension: "svg") ??
                     Bundle.main.url(forResource: "SideBySide - Logo", withExtension: "svg", subdirectory: "game-assets") {
            if let img = NSImage(contentsOf: url) {
                return img
            }
        }
        
        let svgPaths = [
            "Touchless-V1/Touchless-v1/Assets/game-assets/SideBySide - Logo.svg",
            "Touchless-v1/Assets/game-assets/SideBySide - Logo.svg",
            "/Users/clarissaaditjakra/Documents/GitHub/TouchlessGame/Touchless-V1/Touchless-v1/Assets/game-assets/SideBySide - Logo.svg"
        ]
        for path in svgPaths {
            if let img = NSImage(contentsOf: URL(fileURLWithPath: path)) {
                return img
            }
        }
        return nil
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
