import SwiftUI

struct ResultView: View {
    let record: SessionRecord
    let previous: SessionRecord?
    let previousBestScore: Int?
    let onRetry: () -> Void
    let onHome: () -> Void
    let onShowStats: () -> Void

    private var isNewRecord: Bool {
        guard let previousBestScore else { return record.score > 0 }
        return record.score > previousBestScore
    }

    /// 1問も打っていないセッションでは 0% や 0.00秒 は誤解を招くので伏せる
    private var hasAttempts: Bool { record.solved + record.failed > 0 || record.keyCorrect + record.keyMiss > 0 }

    var body: some View {
        VStack(spacing: 20) {
            header

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                tile("問題正答率", hasAttempts ? record.problemAccuracy.percentText : "—",
                     delta: delta(record.problemAccuracy, previous?.problemAccuracy, style: .percent))
                tile("キー正確率", hasAttempts ? record.keyAccuracy.percentText : "—",
                     delta: delta(record.keyAccuracy, previous?.keyAccuracy, style: .percent))
                tile("キー毎分 (KPM)", "\(Int(record.kpm))",
                     delta: delta(record.kpm, previous?.kpm, style: .number))
                tile("平均解答時間", record.solved > 0 ? record.avgSolveSeconds.secondsText() : "—",
                     delta: record.solved > 0
                        ? delta(record.avgSolveSeconds, previous?.avgSolveSeconds, style: .seconds, lowerIsBetter: true)
                        : nil)
                tile("正解した問題", "\(record.solved)",
                     delta: delta(Double(record.solved), previous.map { Double($0.solved) }, style: .number))
                tile("打鍵ミス", "\(record.keyMiss)",
                     delta: delta(Double(record.keyMiss), previous.map { Double($0.keyMiss) }, style: .number, lowerIsBetter: true))
                tile("到達レベル", "\(record.maxLevel) / \(record.mode.maxLevel)", delta: nil)
                tile("最大コンボ", "\(record.maxCombo)",
                     delta: delta(Double(record.maxCombo), previous.map { Double($0.maxCombo) }, style: .number))
            }

            advice

            HStack(spacing: 12) {
                Button("もう一度（\(record.mode.durationLabel)）", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                Button("モードを選ぶ", action: onHome)
                    .controlSize(.large)
                Button("記録を見る", action: onShowStats)
                    .controlSize(.large)
            }
            .padding(.top, 4)
        }
        .padding(28)
        .frame(maxWidth: 860)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("\(record.mode.title)（\(record.mode.durationLabel)）")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("\(record.score)")
                .font(.system(size: 68, weight: .bold, design: .rounded))
                .monospacedDigit()

            if isNewRecord {
                Label("自己ベスト更新", systemImage: "trophy.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.orange)
            } else if let previousBestScore {
                Text("自己ベスト \(previousBestScore) 点まであと \(max(0, previousBestScore - record.score)) 点")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 弱点に応じた一言。
    private var advice: some View {
        let text: String
        if record.solved == 0 {
            text = "まずは 1 問完走してみましょう。Enter を押すのは式を全部打ち終えてからです。"
        } else if record.keyAccuracy < 0.9 {
            text = "正確率が \(record.keyAccuracy.percentText)。速さより正確さが先です。ホームポジション（4・5・6）から指を離さない意識で。"
        } else if record.failed > record.solved / 4 {
            text = "打ち終わる前の Enter が \(record.failed) 回。確定前に画面の残り桁を確認する癖をつけましょう。"
        } else if record.avgSolveSeconds > 6 {
            text = "正確率は十分。次は数字を 3 桁ずつのかたまりで捉えて、視線の移動を減らしてみましょう。"
        } else {
            text = "正確率・速度とも良好です。ひとつ長いモードに挑戦して桁数を上げていきましょう。"
        }
        return Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: Theme.cardCorner))
    }

    private func tile(_ title: String, _ value: String, delta: (text: String, better: Bool)?) -> some View {
        StatTile(title: title, value: value, caption: delta.map { "前回比 \($0.text)" },
                 tint: delta.map { $0.better ? Theme.good : .primary } ?? .primary)
    }

    private enum DeltaStyle { case percent, number, seconds }

    private func delta(_ current: Double, _ previous: Double?, style: DeltaStyle, lowerIsBetter: Bool = false)
        -> (text: String, better: Bool)? {
        guard let previous else { return nil }
        let diff = current - previous
        guard abs(diff) > 0.0001 else { return ("±0", false) }
        let sign = diff > 0 ? "+" : "−"
        let magnitude = abs(diff)
        let text: String
        switch style {
        case .percent: text = sign + String(format: "%.1fpt", magnitude * 100)
        case .number: text = sign + String(format: "%.0f", magnitude)
        case .seconds: text = sign + String(format: "%.2f秒", magnitude)
        }
        return (text, lowerIsBetter ? diff < 0 : diff > 0)
    }
}
