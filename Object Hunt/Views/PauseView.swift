import SwiftUI

struct PauseView: View {
    let onResume: () -> Void
    let onRestart: () -> Void
    let onHome: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text(String(localized: "Paused"))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Button(String(localized: "Resume"), action: onResume)
                .buttonStyle(PrimaryHuntButtonStyle())
            Button(String(localized: "Restart"), action: onRestart)
                .buttonStyle(GhostHuntButtonStyle())
            Button(String(localized: "Home"), action: onHome)
                .buttonStyle(GhostHuntButtonStyle())
        }
        .padding(28)
        .frame(maxWidth: 420)
        .background(Color.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(24)
        .accessibilityElement(children: .contain)
    }
}

struct GhostHuntButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.14))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
