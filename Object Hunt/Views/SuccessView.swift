import SwiftUI

struct SuccessView: View {
    let points: Int

    var body: some View {
        VStack(spacing: 12) {
            Text(String(localized: "Found!"))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("+\(points)")
                .font(.title.weight(.semibold).monospacedDigit())
                .foregroundColor(Color(red: 0.55, green: 0.95, blue: 0.62))
        }
        .padding(28)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .scaleEffect(1)
        .accessibilityElement(children: .combine)
    }
}
