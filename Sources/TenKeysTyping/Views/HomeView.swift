import SwiftUI

struct HomeView: View {
    @EnvironmentObject var history: HistoryStore
    @EnvironmentObject var sound: SoundEngine

    @Binding var numpadOnly: Bool
    @Binding var showGuide: Bool
    @Binding var groupDigits: Bool

    let onStart: (GameMode) -> Void
    let onShowStats: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                headline

                HStack(alignment: .top, spacing: 14) {
                    ForEach(GameMode.allCases) { mode in
                        modeCard(mode)
                    }
                }

                settings

                HStack {
                    Button {
                        onShowStats()
                    } label: {
                        Label("記録と上達グラフ", systemImage: "chart.xyaxis.line")
                    }
                    .controlSize(.large)
                    Spacer()
                    Text("総プレイ \(history.records.count) 回")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(28)
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TenKeysTyping")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text("表示された式をテンキーでそのまま打ち、Enter で確定します。時間が経つほど桁数と演算子が増えていきます。")
                .foregroundStyle(.secondary)
        }
    }

    private func modeCard(_ mode: GameMode) -> some View {
        let best = history.best(for: mode)
        let levels = mode.levels

        return Button {
            onStart(mode)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(mode.title)
                        .font(.title3.weight(.bold))
                    Spacer()
                    Text(mode.durationLabel)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.18), in: Capsule())
                }

                Text(mode.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                VStack(alignment: .leading, spacing: 3) {
                    Label("Lv1 \(levels.first?.label ?? "")", systemImage: "arrow.up.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Label("Lv\(mode.maxLevel) \(levels.last?.label ?? "")", systemImage: "flag.checkered")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Divider()

                if let best {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ベスト \(best.score) 点")
                            .font(.callout.weight(.semibold))
                        Text("正確率 \(best.keyAccuracy.percentText) / \(Int(best.kpm)) キー毎分")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("記録なし")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: Theme.cardCorner))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCorner)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("設定")
                .font(.headline)

            HStack(alignment: .top, spacing: 30) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("テンキーのみ受け付ける", isOn: $numpadOnly)
                        .help("オフにすると、テンキーの無いキーボードの数字・記号キーでも入力できます")
                    Toggle("テンキーの見取り図を表示", isOn: $showGuide)
                    Toggle("3桁区切りで表示", isOn: $groupDigits)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("効果音", isOn: $sound.enabled)
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                        Slider(value: $sound.volume, in: 0...1)
                            .frame(width: 160)
                            .disabled(!sound.enabled)
                        Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                    }
                    Button("音を試す") { sound.play(.correct(3)) }
                        .buttonStyle(.link)
                        .disabled(!sound.enabled)
                }
            }

            Text("プレイ中: Enter=確定 / delete=1文字戻る / テンキーclear=全消し / esc=中断")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: Theme.cardCorner))
    }
}
