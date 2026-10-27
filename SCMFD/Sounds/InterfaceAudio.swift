import AVFAudio
import Foundation
import OSLog

/// Local feedback only; sounds do not indicate acknowledgement from the game.
@MainActor
final class InterfaceAudio {
    static let shared = InterfaceAudio()
    static let enabledKey = "interfaceSoundsEnabled"
    static let volumeKey = "interfaceSoundsVolume"

    private var players: [String: AVAudioPlayer] = [:]
    private let logger = Logger(subsystem: "com.csmfd.app", category: "Audio")

    private init() {
        #if os(iOS) || os(visionOS)
        do {
            // Respect silent mode and let music from other apps continue.
            try AVAudioSession.sharedInstance().setCategory(.ambient)
        } catch {
            logger.error("Audio session setup failed: \(error.localizedDescription)")
        }
        #endif
    }

    func play(for action: ShipAction) {
        let name: String
        switch action {
        case .quantumEngage: name = "engageQT"
        case .masterMode: name = "SCMNAV"
        case .operatorMode: name = "operatorMode"
        case .requestLanding: name = "requestLanding"
        default: name = "mainClick"
        }
        play(name)
    }

    func click() {
        play("mainClick")
    }

    func updateSettings() {
        let enabled = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
        let volume = UserDefaults.standard.object(forKey: Self.volumeKey) as? Double ?? 0.5
        for player in players.values {
            player.volume = Float(min(max(volume, 0), 1))
            if !enabled { player.stop() }
        }
    }

    private func play(_ name: String) {
        guard UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true else { return }
        do {
            let player: AVAudioPlayer
            if let cached = players[name] {
                player = cached
            } else {
                guard let url = Bundle.main.url(forResource: name, withExtension: "wav")
                    ?? Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Sounds") else {
                    logger.error("Missing bundled sound: \(name)")
                    return
                }
                player = try AVAudioPlayer(contentsOf: url)
                players[name] = player
            }
            updateSettings()
            // Restart repeated taps instead of stacking copies of the same sound.
            player.currentTime = 0
            player.play()
        } catch {
            logger.error("Sound playback failed: \(error.localizedDescription)")
        }
    }
}
