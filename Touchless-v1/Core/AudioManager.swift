import AVFoundation

class AudioManager {
    static let shared = AudioManager()
    
    private var sfxPlayers: [AVAudioPlayer] = []
    private var scrapePlayer: AVAudioPlayer?
    private var musicPlayer: AVAudioPlayer?
    
    // 🔊 Master volume setting (0.0 to 1.0)
    var masterVolume: Float = 0.5 {
        didSet {
            musicPlayer?.volume = masterVolume * 0.8 // Music is always slightly quieter
            scrapePlayer?.volume = masterVolume
        }
    }

    private init() { setupScrapePlayer() }
    
    func playMusic(_ soundName: String, ext: String = "mp3", fadeDuration: TimeInterval = 0.8) {
        guard let url = Bundle.main.url(forResource: soundName, withExtension: ext) else { return }
        if musicPlayer?.url == url && musicPlayer?.isPlaying == true { return }
        if let currentPlayer = musicPlayer, currentPlayer.isPlaying { fadeVolumeAndStop(player: currentPlayer, duration: fadeDuration) }
        
        do {
            musicPlayer = try AVAudioPlayer(contentsOf: url)
            musicPlayer?.numberOfLoops = -1
            musicPlayer?.volume = 0
            musicPlayer?.play()
            musicPlayer?.setVolume(masterVolume * 0.8, fadeDuration: fadeDuration)
        } catch { print("Music error") }
    }

    private func fadeVolumeAndStop(player: AVAudioPlayer, duration: TimeInterval) {
        player.setVolume(0, fadeDuration: duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { player.stop() }
    }

    func playSFX(_ soundName: String, ext: String = "mp3") {
        guard let url = Bundle.main.url(forResource: soundName, withExtension: ext) else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = masterVolume // Follow master volume
            player.play()
            sfxPlayers.append(player)
            sfxPlayers.removeAll { !$0.isPlaying }
        } catch { print("SFX error") }
    }
    
    private func setupScrapePlayer() {
        guard let url = Bundle.main.url(forResource: "scrape", withExtension: "mp3") else { return }
        try? scrapePlayer = AVAudioPlayer(contentsOf: url)
    }
    
    func playScrapeOnce() {
        if scrapePlayer?.isPlaying == false {
            scrapePlayer?.volume = masterVolume
            scrapePlayer?.currentTime = 0
            scrapePlayer?.play()
        }
    }
    func forceStopScrape() { scrapePlayer?.stop() }
}
