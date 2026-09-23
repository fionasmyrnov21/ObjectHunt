import Foundation

enum BadgeID: String, Codable, CaseIterable, Identifiable {
    case firstFind
    case score500
    case score1000
    case instantFind
    case fiveRounds
    case everyColor
    case cleanThree
    case tenGames

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstFind: return String(localized: "First Find")
        case .score500: return String(localized: "Score 500")
        case .score1000: return String(localized: "Score 1000")
        case .instantFind: return String(localized: "Instant Find")
        case .fiveRounds: return String(localized: "Five Rounds")
        case .everyColor: return String(localized: "Every Color")
        case .cleanThree: return String(localized: "Clean Three")
        case .tenGames: return String(localized: "Ten Games")
        }
    }

    var detail: String {
        switch self {
        case .firstFind: return String(localized: "Find a target once.")
        case .score500: return String(localized: "Reach 500 in one run.")
        case .score1000: return String(localized: "Reach 1000 in one run.")
        case .instantFind: return String(localized: "Find a target with the full timer left.")
        case .fiveRounds: return String(localized: "Reach round five in one run.")
        case .everyColor: return String(localized: "Find each color at least once.")
        case .cleanThree: return String(localized: "Find three targets before a miss.")
        case .tenGames: return String(localized: "Finish ten runs.")
        }
    }

    var target: Int {
        switch self {
        case .firstFind, .instantFind: return 1
        case .score500: return 500
        case .score1000: return 1000
        case .fiveRounds: return 5
        case .everyColor: return GameColor.allCases.count
        case .cleanThree: return 3
        case .tenGames: return 10
        }
    }
}

struct Badge: Identifiable, Equatable {
    let id: BadgeID
    let progress: Int
    let target: Int

    var title: String { id.title }
    var detail: String { id.detail }
    var isUnlocked: Bool { progress >= target }
}

struct PlayerStats: Codable, Equatable {
    var gamesPlayed: Int
    var finds: Int
    var bestStreak: Int
    var colorsFound: [String]
    var totalScore: Int
    var bestScore: Int
    var instantFinds: Int
    var bestCleanFinds: Int
    var bestRound: Int
    var unlocked: [String]

    static let empty = PlayerStats(
        gamesPlayed: 0,
        finds: 0,
        bestStreak: 0,
        colorsFound: [],
        totalScore: 0,
        bestScore: 0,
        instantFinds: 0,
        bestCleanFinds: 0,
        bestRound: 0,
        unlocked: []
    )
}
