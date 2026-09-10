import SwiftUI
import AVKit

struct LoopingVideoPlayer: NSViewRepresentable {
    let filename: String
    let ext: String = "mov"
    
    class Coordinator {
        var player: AVPlayer?
        var playerLayer: AVPlayerLayer?
        var currentFilename: String?
        var loopObserver: Any?
        
        deinit {
            cleanup()
        }
        
        func cleanup() {
            if let obs = loopObserver {
                NotificationCenter.default.removeObserver(obs)
                loopObserver = nil
            }
            player?.pause()
            player = nil
            playerLayer?.removeFromSuperlayer()
            playerLayer = nil
            currentFilename = nil
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        
        setupPlayer(for: view, coordinator: context.coordinator)
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if context.coordinator.currentFilename != filename {
            setupPlayer(for: nsView, coordinator: context.coordinator)
        }
    }
    
    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.cleanup()
    }
    
    private func setupPlayer(for view: NSView, coordinator: Coordinator) {
        coordinator.cleanup()
        
        guard let url = Bundle.main.url(forResource: filename, withExtension: ext) else {
            print("❌ Could not find \(filename).\(ext)")
            return
        }
        
        let player = AVPlayer(url: url)
        player.isMuted = true
        player.actionAtItemEnd = .none
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        playerLayer.frame = view.bounds
        
        view.layer?.addSublayer(playerLayer)
        
        coordinator.player = player
        coordinator.playerLayer = playerLayer
        coordinator.currentFilename = filename
        
        coordinator.loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }
        
        player.play()
    }
}
