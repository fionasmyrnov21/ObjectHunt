import Combine
import CoreImage
import Foundation

final class GameViewModel: ObservableObject {
    @Published var state: GameState = .idle
    @Published var score = 0
    @Published var bestScore = 0
    @Published var remainingSeconds = 10
    @Published var countdownValue = 3
    @Published var round = 1
    @Published var failedCount = 0
    @Published var detectionProgress: Double = 0
    @Published var lastAward: Int = 0
    @Published var freezePreview = false
    @Published var challenge: Challenge?
    @Published var cameraAccess: CameraAccess = .unknown
    @Published var toastBadge: Badge?
    @Published var runBadge: Badge?

    let camera = CameraService()
    let detector = ColorDetectionService()
    let sound = SoundManager()
    let progress = ProgressStore()

    var difficulty: Difficulty { Difficulty.forRound(round) }
    var livesLeft: Int { max(0, 3 - failedCount) }

    private let playLock = NSLock()
    private var playColor: GameColor?
    private var playThreshold: Double = 0.15
    private var ticker: AnyCancellable?
    private var accessWatcher: AnyCancellable?
    private var consecutiveHits = 0
    private var lastColor: GameColor?
    private var roundToken = UUID()
    private var resumePhase: GameState = .playing
    private var runFinds = 0
    private var runStreak = 0
    private var countedRun = false

    init() {
        bestScore = progress.stats.bestScore
        cameraAccess = camera.access
        accessWatcher = camera.$access
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.cameraAccess = value
            }
        camera.onFrame = { [weak self] image in
            self?.handleFrame(image)
        }
    }

    func appearHome() {
        camera.refreshAccess()
        cameraAccess = camera.access
        bestScore = progress.stats.bestScore
    }

    func tap() {
        HapticService.impact(enabled: progress.settings.hapticsEnabled)
    }

    func requestCamera() {
        tap()
        camera.requestAccess()
    }

    func openSettings() {
        tap()
        camera.openSystemSettings()
    }

    func startGame() {
        if shouldCountExit {
            countedRun = true
            _ = progress.recordGameEnd(score: score)
        }
        tap()
        camera.refreshAccess()
        cameraAccess = camera.access
        guard cameraAccess == .allowed else { return }
        score = 0
        failedCount = 0
        round = 1
        lastColor = nil
        lastAward = 0
        freezePreview = false
        runFinds = 0
        runStreak = 0
        countedRun = false
        toastBadge = nil
        runBadge = nil
        beginCountdown()
    }

    func playAgain() {
        startGame()
    }

    func pauseGame() {
        guard state == .playing || state == .countdown else { return }
        resumePhase = state
        ticker?.cancel()
        setPlayColor(nil)
        camera.stop()
        state = .paused
        tap()
    }

    func resumeGame() {
        guard state == .paused else { return }
        tap()
        camera.start()
        if resumePhase == .countdown {
            state = .countdown
            ticker = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.tickCountdown()
                }
        } else {
            armDetection()
            state = .playing
            ticker = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.tickPlay()
                }
        }
    }

    func goHome() {
        if shouldCountExit {
            countedRun = true
            accept(progress.recordGameEnd(score: score))
        }
        ticker?.cancel()
        setPlayColor(nil)
        camera.stop()
        state = .idle
        freezePreview = false
        detectionProgress = 0
        challenge = nil
        toastBadge = nil
        bestScore = progress.stats.bestScore
    }

    func handleBackground() {
        guard state == .playing || state == .countdown else { return }
        resumePhase = state
        ticker?.cancel()
        setPlayColor(nil)
        camera.stop()
        state = .paused
    }

    func handleForeground() {
        camera.refreshAccess()
        cameraAccess = camera.access
    }

    private var shouldCountExit: Bool {
        guard !countedRun else { return false }
        return state == .paused || state == .playing || state == .countdown || state == .detected || state == .failed
    }

    private func beginCountdown() {
        ticker?.cancel()
        setPlayColor(nil)
        consecutiveHits = 0
        detectionProgress = 0
        freezePreview = false
        lastAward = 0
        toastBadge = nil
        makeChallenge()
        countdownValue = 3
        state = .countdown
        camera.start()
        sound.playCountdown(enabled: progress.settings.soundEnabled)
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tickCountdown()
            }
    }

    private func tickCountdown() {
        guard state == .countdown else { return }
        if countdownValue <= 1 {
            beginPlaying()
        } else {
            countdownValue -= 1
            sound.playCountdown(enabled: progress.settings.soundEnabled)
        }
    }

    private func beginPlaying() {
        ticker?.cancel()
        remainingSeconds = difficulty.timeLimit
        consecutiveHits = 0
        detectionProgress = 0
        freezePreview = false
        armDetection()
        state = .playing
        camera.start()
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tickPlay()
            }
    }

    private func armDetection() {
        playLock.lock()
        playColor = challenge?.targetColor
        playThreshold = difficulty.detectionThreshold * progress.settings.scanFeel.multiplier
        playLock.unlock()
    }

    private func tickPlay() {
        guard state == .playing else { return }
        if remainingSeconds <= 1 {
            remainingSeconds = 0
            failRound()
        } else {
            remainingSeconds -= 1
        }
    }

    private func handleFrame(_ image: CIImage) {
        playLock.lock()
        let color = playColor
        let threshold = playThreshold
        playLock.unlock()
        guard let color else { return }
        let ratio = detector.matchRatio(in: image, color: color)
        DispatchQueue.main.async { [weak self] in
            self?.applyDetection(ratio: ratio, threshold: threshold)
        }
    }

    private func applyDetection(ratio: Double, threshold: Double) {
        guard state == .playing else { return }
        if ratio >= threshold {
            consecutiveHits += 1
            let needed = max(1, difficulty.confirmationFrames)
            detectionProgress = min(1, Double(consecutiveHits) / Double(needed))
            if consecutiveHits >= needed {
                succeedRound()
            }
        } else {
            consecutiveHits = 0
            detectionProgress = 0
        }
    }

    private func succeedRound() {
        guard state == .playing, let challenge else { return }
        ticker?.cancel()
        setPlayColor(nil)
        freezePreview = true
        let bonus = remainingSeconds * 10
        lastAward = 100 + bonus
        score += lastAward
        runFinds += 1
        runStreak += 1
        let fresh = progress.recordFind(
            color: challenge.targetColor,
            remaining: remainingSeconds,
            limit: challenge.timeLimit,
            runFinds: runFinds,
            streak: runStreak,
            misses: failedCount,
            score: score,
            round: round
        )
        accept(fresh)
        bestScore = progress.stats.bestScore
        state = .detected
        sound.playSuccess(enabled: progress.settings.soundEnabled)
        HapticService.success(enabled: progress.settings.hapticsEnabled)
        camera.stop()
        let token = UUID()
        roundToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            guard let self, self.roundToken == token, self.state == .detected else { return }
            self.round += 1
            self.beginCountdown()
        }
    }

    private func failRound() {
        guard state == .playing else { return }
        ticker?.cancel()
        setPlayColor(nil)
        freezePreview = true
        failedCount += 1
        runStreak = 0
        lastAward = 0
        detectionProgress = 0
        state = .failed
        sound.playFailure(enabled: progress.settings.soundEnabled)
        HapticService.failure(enabled: progress.settings.hapticsEnabled)
        camera.stop()
        let token = UUID()
        roundToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let self, self.roundToken == token, self.state == .failed else { return }
            if self.failedCount >= 3 {
                self.finishGame()
            } else {
                self.round += 1
                self.beginCountdown()
            }
        }
    }

    private func finishGame() {
        accept(progress.recordGameEnd(score: score))
        countedRun = true
        bestScore = progress.stats.bestScore
        state = .gameOver
        freezePreview = false
        camera.stop()
    }

    private func accept(_ badge: Badge?) {
        guard let badge else { return }
        runBadge = badge
        toastBadge = badge
    }

    private func makeChallenge() {
        let options = GameColor.allCases.filter { $0 != lastColor }
        let color = options.randomElement() ?? GameColor.allCases.randomElement() ?? .red
        lastColor = color
        let limit = difficulty.timeLimit
        challenge = Challenge(id: UUID(), targetColor: color, timeLimit: limit)
        remainingSeconds = limit
    }

    private func setPlayColor(_ color: GameColor?) {
        playLock.lock()
        playColor = color
        playLock.unlock()
    }
}
