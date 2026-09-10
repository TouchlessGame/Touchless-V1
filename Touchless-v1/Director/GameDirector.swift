import SwiftUI
import Combine

// 1. THE DATABASE: Centralized Metadata for all games
enum MiniGame: CaseIterable {
    case stomp, drill, party, dj, cymbals, furniture, bonus, wipe
    
    static var normalGames: [MiniGame] {
        return [.stomp, .drill, .party, .dj, .cymbals, .furniture, .wipe]
    }
    var timeLimit: Double {
        switch self {
        case .drill, .wipe: return 7.0
        case .bonus: return 9.0
        default: return 5.0
        }
    }
}

// 2. THE REFEREE: Manages the clock and the game flow
class GameDirector: ObservableObject {
    @Published var currentGame: MiniGame = .stomp
    @Published var timeRemaining: Double = 5.0
    
    // 🔧 SEQUENCE SETTINGS
    @Published var isSequenceComplete: Bool = false
    @Published var isPaused: Bool = false
    
    // 📊 THE MISSING PIECES: UI Tracking Variables for the Progress Bars
    @Published var totalRounds: Int = 8
    @Published var currentRoundIndex: Int = 0
    
    private var timerCancellable: AnyCancellable?
    
    func start(rounds: Int = 5) {
        self.totalRounds = rounds
        self.currentRoundIndex = 0
        self.isSequenceComplete = false
        self.isPaused = false
        pickNextActivity(isFirstRound: true)
    }
    
    // ⏸️ Pause functionality
    func pauseTimer() {
        isPaused = true
        timerCancellable?.cancel()
    }
    
    // ▶️ Resume functionality
    func resumeTimer() {
        isPaused = false
        startTimer()
    }
    
    // 🛑 Forces the game to end and jump to the scoreboard
    func forceEndGame() {
        timerCancellable?.cancel()
        isPaused = false
        isSequenceComplete = true
    }
    
    func resetToMenu() {
        timerCancellable?.cancel()
        currentRoundIndex = 0
        isSequenceComplete = false
        isPaused = false
    }

    func nextRound(success: Bool) {
        timerCancellable?.cancel()
        currentRoundIndex += 1 // ⬅️ THIS MOVES THE YELLOW PROGRESS BAR!
        pickNextActivity()
    }

    func pickNextActivity(isFirstRound: Bool = false) {
        // If we have played all the rounds, end the game!
        if currentRoundIndex >= totalRounds {
            isSequenceComplete = true
            timerCancellable?.cancel()
            return
        }
        
        // If it is the very last round, ALWAYS play the bonus game!
        if currentRoundIndex == (totalRounds - 1) {
            currentGame = .bonus
            timeRemaining = currentGame.timeLimit
            startTimer()
            return
        }
        
        // Otherwise, pick a random normal game
        var nextGame = MiniGame.normalGames.randomElement() ?? .stomp
        if !isFirstRound {
            while nextGame == currentGame {
                nextGame = MiniGame.normalGames.randomElement() ?? .stomp
            }
        }
        
        currentGame = nextGame
        timeRemaining = nextGame.timeLimit
        startTimer()
    }

    private func startTimer() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.timeRemaining -= 0.1
                if self.timeRemaining <= 0 {
                    self.nextRound(success: false)
                }
            }
    }
}
