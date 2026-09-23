import AudioToolbox
import Foundation

final class SoundManager {
    func playSuccess(enabled: Bool) {
        guard enabled else { return }
        AudioServicesPlaySystemSound(1057)
    }

    func playFailure(enabled: Bool) {
        guard enabled else { return }
        AudioServicesPlaySystemSound(1053)
    }

    func playCountdown(enabled: Bool) {
        guard enabled else { return }
        AudioServicesPlaySystemSound(1103)
    }
}
