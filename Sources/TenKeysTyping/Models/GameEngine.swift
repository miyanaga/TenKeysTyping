import Foundation
import SwiftUI

@MainActor
final class GameEngine: ObservableObject {
    enum Phase: Equatable {
        case idle
        case countdown(Int)   // 3, 2, 1
        case playing
        case finished
    }

    /// 直近の結果を短く出すトースト。
    struct Toast: Equatable {
        enum Kind { case correct, miss }
        let kind: Kind
        let text: String
        let id: Int
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var problem: Problem?
    @Published private(set) var typedCount = 0
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var level = 1
    @Published private(set) var score = 0
    @Published private(set) var combo = 0
    @Published private(set) var toast: Toast?
    /// ミス時に振動させるためのカウンタ
    @Published private(set) var shakeToken = 0
    /// レベルアップ表示用のトリガ
    @Published private(set) var levelUpToken = 0

    private(set) var mode: GameMode = .standard
    private var solved = 0
    private var failed = 0
    private var keyCorrect = 0
    private var keyMiss = 0
    private var maxCombo = 0
    private var maxLevel = 1
    private var solveDurations: [TimeInterval] = []

    private var startedAt: Date?
    private var problemStartedAt: Date?
    private var timer: Timer?
    private var countdownTimer: Timer?
    private var toastCounter = 0

    private let sound: SoundEngine
    private var groupDigits: Bool = true

    /// セッション終了時に結果を通知する。
    var onFinish: ((SessionRecord) -> Void)?

    init(sound: SoundEngine) {
        self.sound = sound
    }

    // MARK: - 進行

    func start(mode: GameMode, groupDigits: Bool) {
        stopTimers()
        self.mode = mode
        self.groupDigits = groupDigits
        solved = 0
        failed = 0
        keyCorrect = 0
        keyMiss = 0
        maxCombo = 0
        maxLevel = 1
        solveDurations = []
        score = 0
        combo = 0
        level = 1
        typedCount = 0
        problem = nil
        toast = nil
        remaining = mode.duration
        phase = .countdown(3)
        sound.play(.countdown)

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickCountdown() }
        }
    }

    private func tickCountdown() {
        guard case .countdown(let n) = phase else { return }
        if n > 1 {
            phase = .countdown(n - 1)
            sound.play(.countdown)
        } else {
            countdownTimer?.invalidate()
            countdownTimer = nil
            sound.play(.go)
            beginPlaying()
        }
    }

    private func beginPlaying() {
        phase = .playing
        startedAt = Date()
        remaining = mode.duration
        nextProblem()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard phase == .playing, let startedAt else { return }
        let elapsed = Date().timeIntervalSince(startedAt)
        remaining = max(0, mode.duration - elapsed)

        let newLevel = mode.level(atProgress: elapsed / mode.duration)
        if newLevel != level {
            level = newLevel
            maxLevel = max(maxLevel, newLevel)
            levelUpToken += 1
            sound.play(.levelUp)
        }

        if remaining <= 0 { finish() }
    }

    func abort() {
        stopTimers()
        phase = .idle
        problem = nil
    }

    private func finish() {
        stopTimers()
        phase = .finished
        problem = nil
        sound.play(.finish)

        let avg = solveDurations.isEmpty
            ? 0
            : solveDurations.reduce(0, +) / Double(solveDurations.count)

        onFinish?(SessionRecord(
            date: Date(),
            mode: mode,
            score: score,
            solved: solved,
            failed: failed,
            keyCorrect: keyCorrect,
            keyMiss: keyMiss,
            maxLevel: maxLevel,
            maxCombo: maxCombo,
            avgSolveSeconds: avg
        ))
    }

    private func stopTimers() {
        timer?.invalidate()
        timer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func nextProblem() {
        problem = ProblemGenerator.make(spec: mode.spec(forLevel: level), groupDigits: groupDigits)
        typedCount = 0
        problemStartedAt = Date()
    }

    // MARK: - 入力

    func handle(_ input: KeyInput) {
        guard phase == .playing, let problem else { return }

        switch input {
        case .char(let c):
            guard typedCount < problem.length else {
                registerMiss()
                return
            }
            if c == problem.target[typedCount] {
                typedCount += 1
                keyCorrect += 1
                sound.play(.tick)
            } else {
                registerMiss()
            }

        case .enter:
            if typedCount == problem.length {
                registerSolved(problem)
            } else {
                // 途中で確定しようとしたらミス扱い（入力は消さずに続行できる）
                registerMiss(enterTooEarly: true)
            }

        case .backspace:
            if typedCount > 0 { typedCount -= 1 }

        case .clear:
            typedCount = 0

        case .escape:
            abort()
        }
    }

    private func registerSolved(_ problem: Problem) {
        let elapsed = problemStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        solveDurations.append(elapsed)
        solved += 1
        combo += 1
        maxCombo = max(maxCombo, combo)

        // 打鍵数・レベル・コンボ・速さでスコアを積む
        let base = problem.length * 10
        let levelBonus = level * 5
        let comboBonus = min(combo, 20) * 5
        let par = Double(problem.length) * 0.55
        let speedBonus = max(0, Int((par - elapsed) * 25))
        score += base + levelBonus + comboBonus + speedBonus

        toastCounter += 1
        toast = Toast(kind: .correct, text: "= \(problem.answerText)", id: toastCounter)
        sound.play(.correct(sound.comboTier(for: combo)))
        nextProblem()
    }

    private func registerMiss(enterTooEarly: Bool = false) {
        keyMiss += 1
        if enterTooEarly { failed += 1 }
        combo = 0
        score = max(0, score - (enterTooEarly ? 30 : 8))
        shakeToken += 1
        toastCounter += 1
        toast = Toast(kind: .miss, text: enterTooEarly ? "まだ途中です" : "ミス", id: toastCounter)
        sound.play(.miss)
    }

    // MARK: - 表示補助

    /// 次に打つべき文字。全部打ち終わっていれば Enter を促すため nil。
    var nextChar: Character? {
        guard let problem, typedCount < problem.length else { return nil }
        return problem.target[typedCount]
    }

    var isAwaitingEnter: Bool {
        guard let problem else { return false }
        return typedCount == problem.length
    }

    var progress: Double {
        guard mode.duration > 0 else { return 0 }
        return 1 - remaining / mode.duration
    }

    var liveKeyAccuracy: Double {
        let total = keyCorrect + keyMiss
        return total == 0 ? 1 : Double(keyCorrect) / Double(total)
    }

    var solvedCount: Int { solved }
}
