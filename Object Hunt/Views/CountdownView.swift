import SwiftUI

struct CountdownView: View {
    let value: Int

    var body: some View {
        Text("\(value)")
            .font(.system(size: 96, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.4), radius: 12)
            .scaleEffect(1)
            .id(value)
            .transition(.scale.combined(with: .opacity))
            .accessibilityLabel("\(value)")
    }
}
