import Foundation

enum ScanFeel: String, Codable, CaseIterable, Identifiable {
    case calm
    case steady
    case sharp

    var id: String { rawValue }

    var multiplier: Double {
        switch self {
        case .calm: return 0.85
        case .steady: return 1
        case .sharp: return 1.2
        }
    }

    var title: String {
        switch self {
        case .calm: return String(localized: "Calm")
        case .steady: return String(localized: "Steady")
        case .sharp: return String(localized: "Sharp")
        }
    }
}

struct GameSettings: Codable, Equatable {
    var soundEnabled: Bool
    var hapticsEnabled: Bool
    var scanFeel: ScanFeel

    static let standard = GameSettings(soundEnabled: true, hapticsEnabled: true, scanFeel: .steady)
}
