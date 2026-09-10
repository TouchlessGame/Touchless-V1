import SwiftUI
import AVKit

struct LoopingVideoPlayer: NSViewRepresentable {
    let filename: String
    let ext: String = "mov"
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        
        // 💻 Mac-specific: We have to explicitly tell the view it's allowed to have layers
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        
        guard let url = Bundle.main.url(forResource: filename, withExtension: ext) else {
            print("❌ Could not find \(filename).\(ext)")
            return view
        }
        
        let player = AVPlayer(url: url)
        player.isMuted = true
        player.actionAtItemEnd = .none // Prevents it from stopping
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        
        // 💻 Mac-specific: Auto-resize the video to fill the SwiftUI frame
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        
        view.layer?.addSublayer(playerLayer)
        
        // The Loop Magic
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        
        player.play()
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // macOS handles the resizing automatically via the autoresizingMask above!
    }
}
