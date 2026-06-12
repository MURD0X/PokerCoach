import AVFoundation
import SwiftUI

/// Plays the table's sound set and fires haptics, honoring the user's
/// toggles and the device silent switch (.ambient category). Sounds are
/// short synthesized one-shots bundled as WAVs.
@MainActor
final class SoundManager {
    static let shared = SoundManager()

    enum Effect: String, CaseIterable {
        case cardDeal = "card-deal"
        case chipClink = "chip-clink"
        case winChime = "win-chime"
    }

    static let soundsKey = "soundsEnabled"
    static let hapticsKey = "hapticsEnabled"

    private var players: [Effect: AVAudioPlayer] = [:]
    private let impact = UIImpactFeedbackGenerator(style: .light)
    private let notify = UINotificationFeedbackGenerator()

    private init() {
        // Ambient: respects the silent switch and mixes with the user's music.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for effect in Effect.allCases {
            if let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") {
                players[effect] = try? AVAudioPlayer(contentsOf: url)
                players[effect]?.prepareToPlay()
                players[effect]?.volume = 0.7
            }
        }
    }

    private var soundsEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.soundsKey) == nil
            || UserDefaults.standard.bool(forKey: Self.soundsKey)
    }

    private var hapticsEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.hapticsKey) == nil
            || UserDefaults.standard.bool(forKey: Self.hapticsKey)
    }

    func play(_ effect: Effect) {
        guard soundsEnabled, let player = players[effect] else { return }
        player.currentTime = 0
        player.play()
    }

    /// Light tap when the action reaches the hero — easy to miss on Slow speed.
    func heroTurnHaptic() {
        guard hapticsEnabled else { return }
        impact.impactOccurred()
    }

    func winHaptic() {
        guard hapticsEnabled else { return }
        notify.notificationOccurred(.success)
    }
}
