import SwiftUI

struct GameOverView: View {
    @ObservedObject var game: GameViewModel

    var body: some View {
        VStack(spacing: 18) {
            Text(String(localized: "Game Over"))
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            VStack(spacing: 6) {
                Text(String(localized: "Score"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white.opacity(0.62))
                Text("\(game.score)")
                    .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundColor(.white)
            }
            VStack(spacing: 4) {
                Text(String(localized: "Best Score"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white.opacity(0.62))
                Text("\(game.bestScore)")
                    .font(.title.weight(.semibold).monospacedDigit())
                    .foregroundColor(.white)
            }
            if let badge = game.runBadge {
                VStack(spacing: 4) {
                    Text(String(localized: "Badge Unlocked"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white.opacity(0.62))
                    Text(badge.title)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 8)
            }
            Button(String(localized: "Play Again"), action: game.playAgain)
                .buttonStyle(PrimaryHuntButtonStyle())
            Button(String(localized: "Home"), action: game.goHome)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.14))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .buttonStyle(PressScaleStyle())
        }
        .padding(28)
        .frame(maxWidth: 420)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .padding(24)
        .accessibilityElement(children: .contain)
    }
}
