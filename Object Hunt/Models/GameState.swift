import Foundation

enum GameState: Equatable {
    case idle
    case countdown
    case playing
    case detected
    case failed
    case paused
    case gameOver
}
