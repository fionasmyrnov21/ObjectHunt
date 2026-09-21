import Foundation

struct Difficulty: Equatable {
    let timeLimit: Int
    let detectionThreshold: Double
    let confirmationFrames: Int

    static func forRound(_ round: Int) -> Difficulty {
        switch round {
        case ...3:
            return Difficulty(timeLimit: 10, detectionThreshold: 0.12, confirmationFrames: 3)
        case 4...7:
            return Difficulty(timeLimit: 8, detectionThreshold: 0.16, confirmationFrames: 4)
        default:
            return Difficulty(timeLimit: 6, detectionThreshold: 0.20, confirmationFrames: 4)
        }
    }
}
