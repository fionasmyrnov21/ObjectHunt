import SwiftUI

struct GameView: View {
    @ObservedObject var game: GameViewModel

    var body: some View {
        GeometryReader { proxy in
            let sideChrome = proxy.size.width > proxy.size.height
            ZStack {
                CameraPreview(layer: game.camera.previewLayer)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                Color.black.opacity(game.freezePreview ? 0.55 : 0.18)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.2), value: game.freezePreview)
                if sideChrome {
                    HStack(spacing: 16) {
                        playSurface
                        sidePanel
                            .frame(width: min(280, proxy.size.width * 0.34))
                    }
                    .padding(16)
                } else {
                    VStack(spacing: 12) {
                        topBar
                        if let color = game.challenge?.targetColor, game.state != .gameOver {
                            TargetView(color: color)
                                .transition(.opacity.combined(with: .scale))
                        }
                        cameraWell
                        bottomBar
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
                overlays
                if let badge = game.toastBadge, game.state != .gameOver, game.state != .paused {
                    VStack {
                        Text(badge.title)
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .accessibilityLabel("\(String(localized: "Badge Unlocked")) \(badge.title)")
                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack {
            ScoreView(score: game.score)
            Spacer(minLength: 12)
            lives
            if game.state == .playing || game.state == .countdown {
                Button(action: game.pauseGame) {
                    Image(systemName: "pause.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.16))
                        .clipShape(Circle())
                }
                .accessibilityLabel(String(localized: "Pause"))
            }
        }
    }

    private var lives: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index < game.failedCount ? Color.white.opacity(0.2) : Color.white)
                    .frame(width: 10, height: 10)
            }
        }
        .accessibilityLabel("\(game.livesLeft)")
    }

    private var cameraWell: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
            ScanOverlay(progress: game.detectionProgress, active: game.state == .playing)
                .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(String(localized: "Scan area"))
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            Text("\(String(format: "%02d", game.remainingSeconds)) \(String(localized: "seconds"))")
                .font(.title2.weight(.semibold).monospacedDigit())
                .foregroundColor(.white)
                .opacity(game.state == .playing || game.state == .countdown ? 1 : 0.55)
            ScanStatus(progress: game.detectionProgress, active: game.state == .playing)
        }
    }

    private var playSurface: some View {
        VStack(spacing: 12) {
            if let color = game.challenge?.targetColor, game.state != .gameOver {
                TargetView(color: color, compact: true)
            }
            cameraWell
        }
    }

    private var sidePanel: some View {
        VStack(spacing: 18) {
            ScoreView(score: game.score)
            lives
            if game.state == .playing || game.state == .countdown {
                Button(String(localized: "Pause"), action: game.pauseGame)
                    .buttonStyle(GhostHuntButtonStyle())
            }
            Spacer()
            Text("\(String(format: "%02d", game.remainingSeconds)) \(String(localized: "seconds"))")
                .font(.headline.monospacedDigit())
                .foregroundColor(.white)
            ScanStatus(progress: game.detectionProgress, active: game.state == .playing)
        }
        .padding(16)
        .background(Color.black.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private var overlays: some View {
        switch game.state {
        case .countdown:
            CountdownView(value: game.countdownValue)
                .animation(.spring(response: 0.32, dampingFraction: 0.68), value: game.countdownValue)
        case .detected:
            SuccessView(points: game.lastAward)
                .transition(.scale.combined(with: .opacity))
        case .failed:
            if let color = game.challenge?.targetColor {
                FailureView(color: color)
                    .transition(.opacity)
            }
        case .paused:
            Color.black.opacity(0.45).ignoresSafeArea()
            PauseView(onResume: game.resumeGame, onRestart: game.startGame, onHome: game.goHome)
        case .gameOver:
            Color.black.opacity(0.45).ignoresSafeArea()
            GameOverView(game: game)
        default:
            EmptyView()
        }
    }
}

struct ScanOverlay: View {
    let progress: Double
    let active: Bool
    @State private var sweep = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(active ? 0.95 : 0.45), lineWidth: 3)
                cornerMarks
                if active {
                    Rectangle()
                        .fill(Color.white.opacity(0.85))
                        .frame(height: 2)
                        .offset(y: sweep ? proxy.size.height / 2 - 10 : -proxy.size.height / 2 + 10)
                }
            }
        }
        .onAppear { sweep = true }
        .onChange(of: active) { isActive in
            sweep = isActive
        }
        .animation(active ? .easeInOut(duration: 1.35).repeatForever(autoreverses: true) : .default, value: sweep)
        .accessibilityHidden(true)
    }

    private var cornerMarks: some View {
        ZStack {
            AlignMark(corner: .topLeading)
            AlignMark(corner: .topTrailing)
            AlignMark(corner: .bottomLeading)
            AlignMark(corner: .bottomTrailing)
        }
    }
}

private enum ScanCorner {
    case topLeading, topTrailing, bottomLeading, bottomTrailing
}

private struct AlignMark: View {
    let corner: ScanCorner

    var body: some View {
        VStack {
            if corner == .bottomLeading || corner == .bottomTrailing { Spacer() }
            HStack {
                if corner == .topTrailing || corner == .bottomTrailing { Spacer() }
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: 22, height: 4)
                if corner == .topLeading || corner == .bottomLeading { Spacer() }
            }
            if corner == .topLeading || corner == .topTrailing { Spacer() }
        }
        .padding(6)
    }
}

struct ScanStatus: View {
    let progress: Double
    let active: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(String(localized: "Scanning..."))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(active ? 0.9 : 0.45))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.16))
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(10, proxy.size.width * progress))
                        .animation(.easeInOut(duration: 0.15), value: progress)
                }
            }
            .frame(height: 10)
            Text("\(Int((progress * 100).rounded()))%")
                .font(.caption.monospacedDigit())
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Detection progress"))
        .accessibilityValue("\(Int((progress * 100).rounded()))%")
    }
}
