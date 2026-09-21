import Combine
import SwiftUI

struct RootView: View {
    @StateObject private var game = GameViewModel()
    @State private var showPermission = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if game.state == .idle {
                NavigationStack {
                    if showPermission {
                        CameraPermissionView(game: game) {
                            showPermission = false
                        }
                    } else {
                        HomeView(game: game, onStart: begin)
                            .navigationDestination(for: HomeRoute.self) { route in
                                switch route {
                                case .guide:
                                    HowToPlayView()
                                case .settings:
                                    SettingsView(store: game.progress)
                                case .badges:
                                    BadgesView(store: game.progress)
                                case .records:
                                    RecordsView(store: game.progress)
                                }
                            }
                    }
                }
                .tint(.white)
                .toolbarColorScheme(.dark, for: .navigationBar)
            } else {
                GameView(game: game)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.25), value: game.state)
        .onChange(of: game.cameraAccess) { access in
            if showPermission, access == .allowed {
                showPermission = false
                game.startGame()
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                game.handleBackground()
            } else if phase == .active {
                game.handleForeground()
            }
        }
    }

    private func begin() {
        game.appearHome()
        if game.cameraAccess == .allowed {
            game.startGame()
        } else {
            showPermission = true
        }
    }
}
