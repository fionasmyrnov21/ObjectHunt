import SwiftUI

struct FailureView: View {
    let color: GameColor

    var body: some View {
        VStack(spacing: 14) {
            Text(String(localized: "Too slow!"))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(String(localized: "The target was:"))
                .font(.headline)
                .foregroundColor(.white.opacity(0.7))
            HStack(spacing: 10) {
                Circle()
                    .fill(color.swatch)
                    .frame(width: 28, height: 28)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                Text(color.displayName)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
            }
        }
        .padding(28)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(String(localized: "Too slow!")) \(color.displayName)")
    }
}
