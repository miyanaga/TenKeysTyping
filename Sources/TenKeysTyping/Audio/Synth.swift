import Foundation

/// 単純な波形合成。効果音をファイル無しで作るための最小限のシンセ。
enum Wave {
    case sine
    case triangle
    /// tanh で角を丸めた矩形波（耳に痛くない程度の倍音）
    case softSquare
    case noise
}

struct Voice {
    var freq: Double
    /// 指定するとその周波数へグライドする
    var endFreq: Double?
    var start: Double
    var duration: Double
    var amp: Double
    var wave: Wave = .sine
    var attack: Double = 0.006
    /// 減衰の速さ。大きいほど短く切れる。
    var decay: Double = 4.5
}

enum Synth {
    static let sampleRate: Double = 44_100

    /// 複数のボイスを重ねて 1 チャンネル分の波形を作る。
    static func render(_ voices: [Voice], tail: Double = 0.05) -> [Float] {
        guard let end = voices.map({ $0.start + $0.duration }).max() else { return [] }
        let total = end + tail
        let count = Int(total * sampleRate)
        var out = [Double](repeating: 0, count: count)
        var rng: UInt64 = 0x2545F491_4F6CDD1D

        for voice in voices {
            let startSample = Int(voice.start * sampleRate)
            let voiceSamples = Int(voice.duration * sampleRate)
            guard voiceSamples > 0 else { continue }
            var phase = 0.0

            for i in 0..<voiceSamples {
                let index = startSample + i
                guard index >= 0, index < count else { continue }
                let t = Double(i) / sampleRate
                let progress = Double(i) / Double(voiceSamples)

                let freq = voice.endFreq.map { voice.freq + ($0 - voice.freq) * progress } ?? voice.freq
                phase += 2 * .pi * freq / sampleRate
                if phase > 2 * .pi { phase -= 2 * .pi }

                let sample: Double
                switch voice.wave {
                case .sine:
                    sample = sin(phase)
                case .triangle:
                    sample = 2 / .pi * asin(sin(phase))
                case .softSquare:
                    sample = tanh(2.5 * sin(phase))
                case .noise:
                    rng = rng &* 6364136223846793005 &+ 1442695040888963407
                    sample = Double(Int64(bitPattern: rng >> 11)) / Double(Int64.max) * 0.5
                }

                // アタック → 指数減衰 → 末尾フェード（プチノイズ防止）
                let attackEnv = voice.attack <= 0 ? 1 : min(1, t / voice.attack)
                let decayEnv = exp(-voice.decay * progress)
                let fadeOut = progress > 0.9 ? (1 - progress) / 0.1 : 1
                out[index] += sample * voice.amp * attackEnv * decayEnv * fadeOut
            }
        }

        // 全体のピークを揃えてクリップを避ける
        let peak = out.map(abs).max() ?? 0
        let gain = peak > 0.95 ? 0.95 / peak : 1
        return out.map { Float($0 * gain) }
    }

    /// 平均律。A4 = 440Hz を基準に半音数で指定する。
    static func note(_ semitonesFromA4: Int) -> Double {
        440 * pow(2, Double(semitonesFromA4) / 12)
    }
}
