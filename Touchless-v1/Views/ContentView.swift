import SwiftUI

// 💡 TOP-LEVEL DEFINITION: This prevents the "Cannot find type AppState" error.
enum AppState {
    case intro
    case playingSolo
    case playingVS
    case debug
}

struct ContentView: View {
    @StateObject private var engine = TrackingEngine()
    @State private var selectedRounds: Int = 5
    @State private var currentState: AppState = .intro
    
    var body: some View {
        GeometryReader { outerGeo in
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    
                    ZStack {
                        // LAYER 1: The Camera
                        CameraView(session: engine.session)
                        
                        // LAYER 2: The Page Router
                        Group {
                            switch currentState {
                            case .intro:
                                MainMenuView(
                                    engine: engine,
                                    onPlaySolo: { rounds in
                                        self.selectedRounds = rounds
                                        self.currentState = .playingSolo
                                    },
                                    onPlayVS: { rounds in
                                        self.selectedRounds = rounds
                                        self.currentState = .playingVS
                                    },
                                    onDebug: { self.currentState = .debug }
                                )
                            case .playingSolo:
                                GamePageView(engine: engine, isMultiplayer: false, rounds: selectedRounds, onReturnToMenu: { currentState = .intro })
                            case .playingVS:
                                GamePageView(engine: engine, isMultiplayer: true, rounds: selectedRounds, onReturnToMenu: { currentState = .intro })
                            case .debug:
                                DebugTrackerView(engine: engine) { currentState = .intro }
                            }
                        }
                        
                        // 🟢 LAYER 3: THE AR DOTS (HAND TRACKING SKELETON IN TACT)
                        Canvas { context, size in
                            for hand in engine.hands {
                                for point in hand.allPoints {
                                    // Mirror the X coordinate to match the camera
                                    let x = (1 - point.x) * size.width
                                    let y = (1 - point.y) * size.height
                                    let dot = Path(ellipseIn: CGRect(x: x-4, y: y-4, width: 8, height: 8))
                                    context.fill(dot, with: .color(.green))
                                }
                            }
                        }
                        .drawingGroup()
                        .allowsHitTesting(false) // Don't block buttons!
                    }
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipped()
                    
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
            }
            .background(Color.black)
        }
        // Mac specific frame support (Optional but good for Academy testing)
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            engine.start()
            // 🎻 Start the classy lobby music immediately
            AudioManager.shared.playMusic("Divertissement")
        }
        .onChange(of: currentState) { newState in
            // 🎼 THE CROSSFADE DIRECTOR
            switch newState {
            case .playingSolo, .playingVS:
                // High-stakes chaos music
                AudioManager.shared.playMusic("Carmen Strings", fadeDuration: 1.0)
            case .intro, .debug:
                // Return to sophisticated lobby music
                AudioManager.shared.playMusic("Divertissement", fadeDuration: 1.2)
            }
        }
    }
}
