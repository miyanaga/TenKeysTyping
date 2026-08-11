import AVFoundation
import Foundation

enum SoundID: Hashable {
    case tick
    /// コンボの段階（0〜7）で音程が上がる
    case correct(Int)
    case miss
    case levelUp
    case countdown
    case go
    case finish
    case newRecord
}

@MainActor
final class SoundEngine: ObservableObject {
    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "soundEnabled")
            applyVolume()
        }
    }

    @Published var volume: Double {
        didSet {
            UserDefaults.standard.set(volume, forKey: "soundVolume")
            applyVolume()
        }
    }

    static let maxComboTier = 7

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var buffers: [SoundID: AVAudioPCMBuffer] = [:]
    private var ready = false

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: ["soundEnabled": true, "soundVolume": 0.7])
        enabled = defaults.bool(forKey: "soundEnabled")
        volume = defaults.double(forKey: "soundVolume")

        setUpEngine()
        buildBuffers()
        applyVolume()

        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.restart() }
        }
    }

    // MARK: - 再生

    func play(_ id: SoundID) {
        guard ready, enabled, let buffer = buffers[id] else { return }
        if !engine.isRunning { restart() }

        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.scheduleBuffer(buffer, at: nil, options: [.interrupts], completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    func comboTier(for combo: Int) -> Int {
        min(max(combo - 1, 0) / 3, Self.maxComboTier)
    }

    // MARK: - セットアップ

    private func setUpEngine() {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: Synth.sampleRate, channels: 2) else { return }
        for _ in 0..<8 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
        engine.prepare()
        do {
            try engine.start()
            ready = true
        } catch {
            ready = false
        }
    }

    private func restart() {
        guard ready else { return }
        try? engine.start()
    }

    private func applyVolume() {
        engine.mainMixerNode.outputVolume = enabled ? Float(volume) : 0
    }

    private func buildBuffers() {
        var table: [SoundID: [Voice]] = [
            .tick: Self.tickVoices,
            .miss: Self.missVoices,
            .levelUp: Self.levelUpVoices,
            .countdown: Self.countdownVoices,
            .go: Self.goVoices,
            .finish: Self.finishVoices,
            .newRecord: Self.newRecordVoices,
        ]
        for tier in 0...Self.maxComboTier {
            table[.correct(tier)] = Self.correctVoices(tier: tier)
        }
        for (id, voices) in table {
            buffers[id] = Self.buffer(from: Synth.render(voices))
        }
    }

    private static func buffer(from samples: [Float]) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
              let format = AVAudioFormat(standardFormatWithSampleRate: Synth.sampleRate, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channels = buffer.floatChannelData
        else { return nil }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in
            channels[0].update(from: src.baseAddress!, count: samples.count)
            channels[1].update(from: src.baseAddress!, count: samples.count)
        }
        return buffer
    }

    // MARK: - 効果音の設計

    /// 打鍵音。短いクリック。
    private static var tickVoices: [Voice] {
        [
            Voice(freq: 2200, start: 0, duration: 0.012, amp: 0.10, wave: .noise, attack: 0.001, decay: 9),
            Voice(freq: 1500, start: 0, duration: 0.030, amp: 0.16, wave: .sine, attack: 0.001, decay: 7),
        ]
    }

    /// 正解音。長三和音のアルペジオ＋オクターブの残響。コンボが伸びるほど高くなる。
    private static func correctVoices(tier: Int) -> [Voice] {
        let root = -9 + tier   // C5 起点で半音ずつ上げる
        let steps = [0, 4, 7]
        var voices: [Voice] = []
        for (i, step) in steps.enumerated() {
            voices.append(Voice(freq: Synth.note(root + step + 12),
                                start: Double(i) * 0.045,
                                duration: 0.26,
                                amp: 0.34,
                                wave: .triangle,
                                decay: 4.2))
        }
        // 最後にオクターブ上を薄く重ねて "きらり" とさせる
        voices.append(Voice(freq: Synth.note(root + 24),
                            start: 0.135,
                            duration: 0.34,
                            amp: 0.16,
                            wave: .sine,
                            decay: 3.4))
        return voices
    }

    /// ミス音。低くうなって下降する不協和音。
    private static var missVoices: [Voice] {
        [
            Voice(freq: 196, endFreq: 132, start: 0, duration: 0.30, amp: 0.30, wave: .softSquare, decay: 3.0),
            Voice(freq: 185, endFreq: 124, start: 0, duration: 0.30, amp: 0.24, wave: .softSquare, decay: 3.0),
            Voice(freq: 900, start: 0, duration: 0.05, amp: 0.14, wave: .noise, attack: 0.001, decay: 8),
        ]
    }

    /// レベルアップ。上昇する4音。
    private static var levelUpVoices: [Voice] {
        [0, 4, 7, 12].enumerated().map { i, step in
            Voice(freq: Synth.note(-5 + step + 12),
                  start: Double(i) * 0.055,
                  duration: 0.24,
                  amp: 0.30,
                  wave: .triangle,
                  decay: 4.0)
        }
    }

    private static var countdownVoices: [Voice] {
        [Voice(freq: 660, start: 0, duration: 0.12, amp: 0.28, wave: .sine, decay: 5)]
    }

    private static var goVoices: [Voice] {
        [
            Voice(freq: 880, start: 0, duration: 0.14, amp: 0.30, wave: .triangle, decay: 5),
            Voice(freq: 1320, start: 0.09, duration: 0.30, amp: 0.30, wave: .triangle, decay: 4),
        ]
    }

    /// 終了ファンファーレ。
    private static var finishVoices: [Voice] {
        var voices: [Voice] = []
        let melody: [(Int, Double)] = [(0, 0), (7, 0.12), (12, 0.24), (16, 0.36)]
        for (step, start) in melody {
            voices.append(Voice(freq: Synth.note(-9 + step + 12), start: start, duration: 0.5,
                                amp: 0.30, wave: .triangle, decay: 3.0))
        }
        voices.append(Voice(freq: Synth.note(-9), start: 0.36, duration: 0.9,
                            amp: 0.18, wave: .sine, decay: 2.2))
        return voices
    }

    /// 自己ベスト更新。少し派手に。
    private static var newRecordVoices: [Voice] {
        var voices: [Voice] = []
        for (i, step) in [0, 4, 7, 12, 16, 19, 24].enumerated() {
            voices.append(Voice(freq: Synth.note(-9 + step + 12),
                                start: Double(i) * 0.06,
                                duration: 0.45,
                                amp: 0.26,
                                wave: .triangle,
                                decay: 3.2))
        }
        return voices
    }
}
