import Combine
import Foundation

final class ProgressStore: ObservableObject {
    @Published private(set) var settings: GameSettings
    @Published private(set) var stats: PlayerStats

    private let settingsKey = "objectHunt.settings"
    private let statsKey = "objectHunt.stats"
    private let legacyBestKey = "objectHunt.bestScore"

    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(GameSettings.self, from: data) {
            settings = decoded
        } else {
            settings = .standard
        }
        if let data = defaults.data(forKey: statsKey),
           let decoded = try? JSONDecoder().decode(PlayerStats.self, from: data) {
            stats = decoded
        } else {
            stats = .empty
        }
        let legacy = defaults.integer(forKey: legacyBestKey)
        if legacy > stats.bestScore {
            stats.bestScore = legacy
            saveStats()
        }
    }

    var badges: [Badge] {
        BadgeID.allCases.map { makeBadge($0) }
    }

    func setSound(_ enabled: Bool) {
        var copy = settings
        copy.soundEnabled = enabled
        settings = copy
        saveSettings()
    }

    func setHaptics(_ enabled: Bool) {
        var copy = settings
        copy.hapticsEnabled = enabled
        settings = copy
        saveSettings()
    }

    func setScanFeel(_ feel: ScanFeel) {
        var copy = settings
        copy.scanFeel = feel
        settings = copy
        saveSettings()
    }

    func recordFind(color: GameColor, remaining: Int, limit: Int, runFinds: Int, streak: Int, misses: Int, score: Int, round: Int) -> Badge? {
        stats.finds += 1
        stats.bestStreak = max(stats.bestStreak, streak)
        stats.bestRound = max(stats.bestRound, round)
        if remaining >= limit {
            stats.instantFinds += 1
        }
        if misses == 0 {
            stats.bestCleanFinds = max(stats.bestCleanFinds, runFinds)
        }
        if !stats.colorsFound.contains(color.rawValue) {
            stats.colorsFound.append(color.rawValue)
        }
        if score > stats.bestScore {
            stats.bestScore = score
            UserDefaults.standard.set(score, forKey: legacyBestKey)
        }
        let fresh = unlockNew()
        saveStats()
        return fresh
    }

    func recordGameEnd(score: Int) -> Badge? {
        stats.gamesPlayed += 1
        stats.totalScore += score
        if score > stats.bestScore {
            stats.bestScore = score
            UserDefaults.standard.set(score, forKey: legacyBestKey)
        }
        let fresh = unlockNew()
        saveStats()
        return fresh
    }

    func foundColors() -> [GameColor] {
        stats.colorsFound.compactMap(GameColor.init(rawValue:))
    }

    private func makeBadge(_ id: BadgeID) -> Badge {
        let progress: Int
        switch id {
        case .firstFind:
            progress = min(id.target, stats.finds)
        case .score500, .score1000:
            progress = min(id.target, stats.bestScore)
        case .instantFind:
            progress = min(id.target, stats.instantFinds)
        case .fiveRounds:
            progress = min(id.target, stats.bestRound)
        case .everyColor:
            progress = min(id.target, stats.colorsFound.count)
        case .cleanThree:
            progress = min(id.target, stats.bestCleanFinds)
        case .tenGames:
            progress = min(id.target, stats.gamesPlayed)
        }
        return Badge(id: id, progress: progress, target: id.target)
    }

    private func unlockNew() -> Badge? {
        let before = Set(stats.unlocked)
        let current = badges.filter(\.isUnlocked).map(\.id.rawValue)
        stats.unlocked = current
        let freshID = BadgeID.allCases.first { current.contains($0.rawValue) && !before.contains($0.rawValue) }
        guard let freshID else { return nil }
        return makeBadge(freshID)
    }

    private func saveSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: settingsKey)
    }

    private func saveStats() {
        guard let data = try? JSONEncoder().encode(stats) else { return }
        UserDefaults.standard.set(data, forKey: statsKey)
    }
}
