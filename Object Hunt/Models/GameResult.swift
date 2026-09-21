import Foundation

struct GameResult: Equatable {
    let score: Int
    let awardedPoints: Int
    let remainingSeconds: Int
    let targetColor: GameColor
}
