import SwiftUI

struct HomeView: View {
    @ObservedObject var game: GameViewModel
    let onStart: () -> Void

    var body: some View {
        ZStack {
            HomeBackdrop()
            ScrollView {
                VStack(spacing: 16) {
                    Text(String(localized: "OBJECT"))
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(4)
                    Text(String(localized: "HUNT"))
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(16)
                    Text(String(localized: "Can you find it?"))
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.72))
                    VStack(spacing: 4) {
                        Text(String(localized: "Best Score"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white.opacity(0.6))
                        Text("\(game.bestScore)")
                            .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundColor(.white)
                    }
                    .padding(.top, 8)
                    Button(action: onStart) {
                        Text(String(localized: "Start Game"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.white)
                            .foregroundColor(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityHint(String(localized: "Starts a color hunt with the camera"))
                    VStack(spacing: 10) {
                        menuLink(String(localized: "How to Play"), route: .guide)
                        menuLink(String(localized: "Settings"), route: .settings)
                        menuLink(String(localized: "Badges"), route: .badges)
                        menuLink(String(localized: "Records"), route: .records)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 36)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            game.appearHome()
        }
    }

    private func menuLink(_ title: String, route: HomeRoute) -> some View {
        NavigationLink(value: route) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded { game.tap() })
    }
}

struct HomeBackdrop: View {
    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.06, blue: 0.10)
            Circle()
                .fill(Color.red.opacity(0.32))
                .frame(width: 260, height: 260)
                .offset(x: -120, y: -220)
                .blur(radius: 24)
            Circle()
                .fill(Color.blue.opacity(0.30))
                .frame(width: 280, height: 280)
                .offset(x: 140, y: -40)
                .blur(radius: 28)
            Circle()
                .fill(Color.yellow.opacity(0.22))
                .frame(width: 220, height: 220)
                .offset(x: 20, y: 260)
                .blur(radius: 20)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

extension View {
    func huntMenuBar() -> some View {
        toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(red: 0.07, green: 0.06, blue: 0.10), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
