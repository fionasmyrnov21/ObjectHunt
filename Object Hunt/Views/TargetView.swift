import SwiftUI

struct TargetView: View {
    let color: GameColor
    var compact: Bool = false

    var body: some View {
        VStack(spacing: compact ? 8 : 12) {
            Text(String(localized: "Find something"))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.7))
                .textCase(.uppercase)
                .tracking(1.4)
            Text(color.displayName)
                .font(compact ? .title.weight(.bold) : .largeTitle.weight(.bold))
                .foregroundColor(.white)
                .minimumScaleFactor(0.7)
            Circle()
                .fill(color.swatch)
                .frame(width: compact ? 42 : 56, height: compact ? 42 : 56)
                .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 3))
                .shadow(color: color.swatch.opacity(0.55), radius: 12)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(String(localized: "Find something")) \(color.displayName)")
        .accessibilityAddTraits(.isHeader)
    }
}
