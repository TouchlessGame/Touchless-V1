import SwiftUI

// 🏗️ HELPER VIEW: The Instruction Pop-up with Video Demo and Tap-to-Skip
struct InstructionOverlay: View {
    let actionWord: String
    let description: String
    
    // Optional video filename. If nil, it just shows text!
    var videoFilename: String? = nil
    
    // Callback when player taps anywhere to skip
    var onSkip: (() -> Void)? = nil
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    @State private var isPulsing: Bool = false

    var body: some View {
        ZStack {
            // Dark Backdrop covering the entire window
            Color.black.opacity(0.88)
                .ignoresSafeArea()
            
            VStack(spacing: 22) {
                // 1. THE ACTION WORD (Top)
                Text(actionWord)
                    .font(.system(size: 76, weight: .black, design: .rounded))
                    .foregroundColor(.yellow)
                    .shadow(color: .yellow.opacity(0.6), radius: 16)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                // 2. THE VIDEO PLAYER (Middle - Only appears if a filename was passed in)
                if let filename = videoFilename {
                    LoopingVideoPlayer(filename: filename)
                        .id(filename)
                        .frame(width: 420, height: 300)
                        .cornerRadius(22)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.cyan, lineWidth: 4)
                                .shadow(color: .cyan.opacity(0.8), radius: 12)
                        )
                }
                
                // 3. THE INSTRUCTION TEXT
                Text(description)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                // 4. TAP TO SKIP PROMPT
                HStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill")
                        .font(.title3)
                    Text("TAP ANYWHERE TO SKIP")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .tracking(1.2)
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                )
                .shadow(color: .white.opacity(isPulsing ? 0.4 : 0.0), radius: 8)
                .scaleEffect(isPulsing ? 1.05 : 0.98)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
                .padding(.top, 10)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        // Entire area intercepts clicks/taps to skip immediately
        .contentShape(Rectangle())
        .onTapGesture {
            onSkip?()
        }
        .onAppear {
            isPulsing = true
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65, blendDuration: 0)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}
