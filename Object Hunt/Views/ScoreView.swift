import SwiftUI

struct ScoreView: View {
    let score: Int

    var body: some View {
        HStack {
            Text(String(localized: "Score"))
                .font(.headline)
                .foregroundColor(.white.opacity(0.72))
            Spacer()
            Text("\(score)")
                .font(.title.weight(.bold).monospacedDigit())
                .foregroundColor(.white)
                .animation(.easeInOut(duration: 0.25), value: score)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(String(localized: "Score")) \(score)")
    }
}
