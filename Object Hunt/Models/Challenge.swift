import Foundation

struct Challenge: Identifiable, Equatable {
    let id: UUID
    let targetColor: GameColor
    let timeLimit: Int
}
