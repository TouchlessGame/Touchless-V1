import SwiftUI

// 🏗️ HELPER VIEW: The 1.5 Second Instruction Pop-up
struct InstructionOverlay: View {
    let actionWord: String
    let description: String
    
    // ⬅️ NEW: Optional video filename. If nil, it just shows text!
    var videoFilename: String? = nil
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 25) { // Increased spacing slightly to give the video room
                
                // 1. THE ACTION WORD (Top)
                Text(actionWord)
                    .font(.system(size: 80, weight: .black, design: .rounded))
                    .foregroundColor(.yellow)
                    .shadow(color: .yellow.opacity(0.5), radius: 15)
                    .multilineTextAlignment(.center)
                
                // 2. THE VIDEO PLAYER (Middle - Only appears if a filename was passed in)
                if let filename = videoFilename {
                    LoopingVideoPlayer(filename: filename)
                        // Adjust these dimensions based on how you cropped your screen recording
                        .frame(width: 400, height: 300)
                        .cornerRadius(20)
                        // Adds a cool glowing border to match the arcade aesthetic
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.cyan, lineWidth: 4)
                                .shadow(color: .cyan, radius: 10)
                        )
                }
                
                // 3. THE INSTRUCTION TEXT (Bottom)
                Text(description)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}
