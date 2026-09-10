import SwiftUI

struct ResultsPageView: View {
    // 🔧 SUSTAINABLE DATA INJECTION
    let p1Score: Int
    let p2Score: Int
    let isMultiplayer: Bool
    
    // Callbacks to let the parent view handle the navigation
    let onRematch: () -> Void
    let onMainMenu: () -> Void
    
    // 🎬 Animation States
    @State private var displayedP1Score: Int = 0
    @State private var displayedP2Score: Int = 0
    @State private var showButtons: Bool = false
    @State private var logoImage: NSImage? = MainMenuView.loadLogo()
    
    var body: some View {
        ZStack {
            // 1. FIX: Semi-transparent background so the camera shows through!
            Color.black.opacity(0.8).ignoresSafeArea()
            
            VStack(spacing: 30) {
                
                // 2. Header
                VStack(spacing: 8) {
                    if let logo = logoImage {
                        Image(nsImage: logo)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 190, maxHeight: 100)
                            .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
                    }
                    
                    Text("GAME OVER!")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .red, radius: 10)
                    
                    Text(getWinnerText())
                        .font(.title2.bold())
                        .foregroundColor(.yellow)
                }
                .padding(.top, 25)
                
                Spacer()
                
                // 3. The Scoreboard (Adapts to Solo or VS Mode!)
                HStack(spacing: 40) {
                    ScoreCardView(
                        title: isMultiplayer ? "PLAYER 1" : "FINAL SCORE",
                        score: displayedP1Score,
                        color: .blue,
                        rank: calculateRank(score: p1Score)
                    )
                    
                    if isMultiplayer {
                        ScoreCardView(
                            title: "PLAYER 2",
                            score: displayedP2Score,
                            color: .red,
                            rank: calculateRank(score: p2Score)
                        )
                    }
                }
                
                Spacer()
                
                // 4. FIX: Use Opacity instead of an 'if' statement.
                // This guarantees the button hitboxes work perfectly every time.
                VStack(spacing: 20) {
                    Button(action: onRematch) {
                        Text("🔄 PLAY AGAIN")
                            .font(.title.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: 300)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(15)
                    }
                    
                    Button(action: onMainMenu) {
                        Text("🏠 MAIN MENU")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: 300)
                            .padding()
                            .background(Color.gray.opacity(0.5))
                            .cornerRadius(15)
                    }
                }
                .opacity(showButtons ? 1.0 : 0.0)
                .offset(y: showButtons ? 0 : 20) // Slides up smoothly
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showButtons)
                
                Spacer()
            }
        }
        .onAppear {
            animateScores()
        }
    }
    
    private func getWinnerText() -> String {
        if !isMultiplayer { return "GREAT GAME!" }
        if p1Score > p2Score { return "PLAYER 1 WINS!" }
        if p2Score > p1Score { return "PLAYER 2 WINS!" }
        return "IT'S A TIE! BOTH PLAYERS ROCK!"
    }
    
    private func calculateRank(score: Int) -> String {
        switch score {
        case 0...200: return "Rookie Groover 🌟"
        case 201...500: return "Rhythm Master ✨"
        case 501...1000: return "Super Star 💫"
        default: return "SIDE BY SIDE CHAMPION 👑"
        }
    }
    
    private func animateScores() {
        AudioManager.shared.playSFX("drumroll")
        
        withAnimation(.easeOut(duration: 2.0)) {
            displayedP1Score = p1Score
            displayedP2Score = p2Score
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            showButtons = true
            AudioManager.shared.playSFX("cymbals")
        }
    }
}

struct ScoreCardView: View {
    let title: String
    let score: Int
    let color: Color
    let rank: String
    
    var body: some View {
        VStack(spacing: 15) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
            
            Text("\(score)")
                .font(.system(size: 70, weight: .black, design: .monospaced))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.5), radius: 10)
            
            Text(rank)
                .font(.title3.bold())
                .foregroundColor(.white)
                .padding(.top, 10)
        }
        .padding(30)
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(color, lineWidth: 4)
        )
    }
}

struct ResultsPageView_Previews: PreviewProvider {
    static var previews: some View {
        ResultsPageView(
            p1Score: 1250,
            p2Score: 840,
            isMultiplayer: true,
            onRematch: { print("Rematch hit") },
            onMainMenu: { print("Menu hit") }
        )
    }
}
