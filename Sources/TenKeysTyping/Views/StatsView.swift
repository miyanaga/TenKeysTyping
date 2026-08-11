import Charts
import SwiftUI

struct StatsView: View {
    @EnvironmentObject var history: HistoryStore
    let onBack: () -> Void

    @State private var mode: GameMode = .standard
    @State private var confirmDelete = false

    private var records: [SessionRecord] { history.records(for: mode) }

    /// 表示用に連番を振った系列
    private var series: [(index: Int, record: SessionRecord)] {
        records.enumerated().map { ($0.offset + 1, $0.element) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            Divider()

            if records.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        summary
                        chart(title: "キー正確率の推移", unit: "%",
                              values: series.map { (index: $0.index, value: $0.record.keyAccuracy * 100) },
                              tint: .green, domainPadding: 5)
                        chart(title: "打鍵速度 (KPM) の推移", unit: "キー/分",
                              values: series.map { (index: $0.index, value: $0.record.kpm) },
                              tint: .blue, domainPadding: 20)
                        chart(title: "1問あたりの平均解答時間", unit: "秒",
                              values: series.map { (index: $0.index, value: $0.record.avgSolveSeconds) },
                              tint: .orange, domainPadding: 1)
                        recentTable
                    }
                    .padding(24)
                }
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 14) {
            Button {
                onBack()
            } label: {
                Label("戻る", systemImage: "chevron.left")
            }
            .buttonStyle(.bordered)

            Picker("", selection: $mode) {
                ForEach(GameMode.allCases) { m in
                    Text("\(m.title)（\(m.durationLabel)）").tag(m)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 460)

            Spacer()

            Button("このモードの記録を消す", role: .destructive) { confirmDelete = true }
                .buttonStyle(.bordered)
                .disabled(records.isEmpty)
                .confirmationDialog("\(mode.title)の記録をすべて削除しますか？", isPresented: $confirmDelete) {
                    Button("削除する", role: .destructive) { history.deleteAll(for: mode) }
                    Button("やめる", role: .cancel) {}
                }
        }
        .padding(16)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("\(mode.title)の記録はまだありません")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var summary: some View {
        let bestScore = records.map(\.score).max() ?? 0
        let bestAccuracy = records.map(\.keyAccuracy).max() ?? 0
        let bestKpm = records.map(\.kpm).max() ?? 0
        let bestTime = records.filter { $0.solved > 0 }.map(\.avgSolveSeconds).min() ?? 0
        let recent = Array(records.suffix(5))
        let recentAccuracy = recent.isEmpty ? 0 : recent.map(\.keyAccuracy).reduce(0, +) / Double(recent.count)

        return VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                StatTile(title: "プレイ回数", value: "\(records.count)")
                StatTile(title: "ベストスコア", value: "\(bestScore)")
                StatTile(title: "最高キー正確率", value: bestAccuracy.percentText, tint: .green)
                StatTile(title: "最高 KPM", value: "\(Int(bestKpm))", tint: .blue)
                StatTile(title: "最短平均解答", value: bestTime > 0 ? bestTime.secondsText() : "—", tint: .orange)
            }
            Text("直近5回の平均キー正確率 \(recentAccuracy.percentText)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// 実測値の折れ線＋5回移動平均（傾向線）
    private func chart(title: String, unit: String,
                       values: [(index: Int, value: Double)],
                       tint: Color, domainPadding: Double) -> some View {
        let averages = movingAverage(values.map(\.value), window: 5)
        let lo = (values.map(\.value).min() ?? 0) - domainPadding
        let hi = (values.map(\.value).max() ?? 1) + domainPadding

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.headline)
                Text("（\(unit)）").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("破線: 5回移動平均").font(.caption2).foregroundStyle(.secondary)
            }

            Chart {
                ForEach(values, id: \.index) { point in
                    LineMark(
                        x: .value("回", point.index),
                        y: .value(unit, point.value)
                    )
                    .foregroundStyle(tint.opacity(0.55))
                    .interpolationMethod(.monotone)

                    PointMark(
                        x: .value("回", point.index),
                        y: .value(unit, point.value)
                    )
                    .foregroundStyle(tint)
                    .symbolSize(28)
                }

                ForEach(Array(averages.enumerated()), id: \.offset) { offset, value in
                    LineMark(
                        x: .value("回", offset + 1),
                        y: .value("移動平均", value),
                        series: .value("系列", "avg")
                    )
                    .foregroundStyle(tint)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    .interpolationMethod(.monotone)
                }
            }
            .chartYScale(domain: max(0, lo)...max(hi, lo + 1))
            .chartXAxisLabel("プレイ回数")
            .frame(height: 170)
        }
        .padding(16)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: Theme.cardCorner))
    }

    private func movingAverage(_ values: [Double], window: Int) -> [Double] {
        guard !values.isEmpty else { return [] }
        return values.indices.map { i in
            let start = Swift.max(0, i - window + 1)
            let slice = values[start...i]
            return slice.reduce(0, +) / Double(slice.count)
        }
    }

    private var recentTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最近のプレイ").font(.headline)

            VStack(spacing: 0) {
                headerRow
                ForEach(records.suffix(15).reversed()) { record in
                    Divider()
                    row(record)
                }
            }
            .padding(.vertical, 4)
            .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: Theme.cardCorner))
        }
    }

    private var headerRow: some View {
        HStack {
            cell("日時", width: 150, alignment: .leading)
            cell("スコア", width: 70)
            cell("正解", width: 55)
            cell("正確率", width: 75)
            cell("KPM", width: 65)
            cell("平均解答", width: 80)
            cell("Lv", width: 45)
            cell("コンボ", width: 60)
            Spacer()
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func row(_ record: SessionRecord) -> some View {
        HStack {
            cell(Self.dateFormatter.string(from: record.date), width: 150, alignment: .leading)
            cell("\(record.score)", width: 70)
            cell("\(record.solved)", width: 55)
            cell(record.keyAccuracy.percentText, width: 75)
            cell("\(Int(record.kpm))", width: 65)
            cell(record.avgSolveSeconds.secondsText(), width: 80)
            cell("\(record.maxLevel)", width: 45)
            cell("\(record.maxCombo)", width: 60)
            Spacer()
        }
        .font(.caption.monospacedDigit())
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func cell(_ text: String, width: CGFloat, alignment: Alignment = .trailing) -> some View {
        Text(text).frame(width: width, alignment: alignment)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d(E) HH:mm"
        return f
    }()
}
