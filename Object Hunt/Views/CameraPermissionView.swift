import SwiftUI

struct CameraPermissionView: View {
    @ObservedObject var game: GameViewModel
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.06, blue: 0.10).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .accessibilityLabel(String(localized: "Home"))
                Spacer()
                content
                Spacer()
            }
            .padding(28)
            .frame(maxWidth: 520, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            game.appearHome()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch game.cameraAccess {
        case .denied:
            Text(String(localized: "Camera Access Denied"))
                .font(.largeTitle.weight(.bold))
                .foregroundColor(.white)
            Text(String(localized: "Please enable camera access in Settings."))
                .font(.title3)
                .foregroundColor(.white.opacity(0.74))
            Button(String(localized: "Open Settings"), action: game.openSettings)
                .buttonStyle(PrimaryHuntButtonStyle())
                .accessibilityHint(String(localized: "Opens system settings for camera access"))
        case .missing:
            Text(String(localized: "Camera Access Required"))
                .font(.largeTitle.weight(.bold))
                .foregroundColor(.white)
            Text(String(localized: "Camera is not available on this device."))
                .font(.title3)
                .foregroundColor(.white.opacity(0.74))
        default:
            Text(String(localized: "Camera Access Required"))
                .font(.largeTitle.weight(.bold))
                .foregroundColor(.white)
            Text(String(localized: "Object Hunt needs access to your camera to find objects around you."))
                .font(.title3)
                .foregroundColor(.white.opacity(0.74))
            Button(String(localized: "Allow Camera"), action: game.requestCamera)
                .buttonStyle(PrimaryHuntButtonStyle())
                .accessibilityHint(String(localized: "Asks for camera access"))
        }
    }
}

struct PrimaryHuntButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white)
            .foregroundColor(.black)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
