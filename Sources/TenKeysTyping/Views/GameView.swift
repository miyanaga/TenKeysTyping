import AppKit
import SwiftUI

struct GameView: View {
    @ObservedObject var engine: GameEngine
    let numpadOnly: Bool
    let showGuide: Bool
    let onQuit: () -> Void

    @State private var monitor: Any?
    @State private var shakeAmount: CGFloat = 0
    @State private var visibleToast: GameEngine.Toast?
    @State private var levelBannerVisible = false

    var body: some View {
        VStack(spacing: 18) {
            header
            timeBar
            expressionCard
            footer
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay { countdownOverlay }
        .onAppear(perform: installMonitor)
        .onDisappear(perform: removeMonitor)
        .onChange(of: engine.shakeToken) { _, _ in
            withAnimation(.linear(duration: 0.32)) { shakeAmount += 1 }
        }
        .onChange(of: engine.toast) { _, newValue in
            withAnimation(.easeOut(duration: 0.12)) { visibleToast = newValue }
        }
        .onChange(of: engine.levelUpToken) { _, _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { levelBannerVisible = true }
        }
        .task(id: visibleToast?.id) {
            guard visibleToast != nil else { return }
            try? await Task.sleep(nanoseconds: 850_000_000)
            withAnimation(.easeOut(duration: 0.25)) { visibleToast = nil }
        }
        .task(id: engine.levelUpToken) {
            guard levelBannerVisible else { return }
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            withAnimation(.easeOut(duration: 0.3)) { levelBannerVisible = false }
        }
    }

    // MARK: - 上部

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(engine.mode.title)
                    .font(.headline)
                Text(engine.mode.spec(forLevel: engine.level).label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            compactStat("残り", String(format: "%.1f", engine.remaining), tint: engine.remaining <= 5 ? Theme.bad : .primary)
            compactStat("スコア", "\(engine.score)")
            compactStat("正解", "\(engine.solvedCount)")
            compactStat("コンボ", "\(engine.combo)", tint: engine.combo >= 5 ? .orange : .primary)
            compactStat("正確率", engine.liveKeyAccuracy.percentText)

            Button("中断") { onQuit() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    private func compactStat(_ title: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
        .frame(minWidth: 62)
    }

    /// 経過バー。レベルの区切りを目盛りで示す。
    private var timeBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(engine.remaining <= 5 ? Theme.bad.gradient : Color.accentColor.gradient)
                    .frame(width: max(0, geo.size.width * engine.progress))
                HStack(spacing: 0) {
                    ForEach(0..<engine.mode.maxLevel, id: \.self) { index in
                        Rectangle()
                            .fill(.background.opacity(index == 0 ? 0 : 0.9))
                            .frame(width: 1)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .frame(height: 8)
        .overlay(alignment: .topLeading) {
            Text("LEVEL \(engine.level) / \(engine.mode.maxLevel)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .offset(y: 12)
        }
        .padding(.bottom, 14)
    }

    // MARK: - 出題

    private var expressionCard: some View {
        VStack(spacing: 14) {
            ZStack {
                if levelBannerVisible {
                    Text("LEVEL \(engine.level)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                        .transition(.scale.combined(with: .opacity))
                } else if let toast = visibleToast {
                    Text(toast.text)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(toast.kind == .correct ? Theme.good : Theme.bad)
                        .transition(.opacity)
                }
            }
            .frame(height: 28)

            Group {
                if let problem = engine.problem {
                    Text(attributed(problem))
                        .font(.system(size: 54, weight: .semibold, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.35)
                } else {
                    Text("—")
                        .font(.system(size: 54, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .padding(.horizontal, 24)
            .background(cardBackground)
            .modifier(Shake(animatableData: shakeAmount))

            Text(engine.isAwaitingEnter ? "Enter で確定" : "テンキーで式をそのまま入力")
                .font(.callout)
                .foregroundStyle(engine.isAwaitingEnter ? Color.accentColor : .secondary)
                .animation(.easeOut(duration: 0.15), value: engine.isAwaitingEnter)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(.quaternary.opacity(0.35))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(borderColor, lineWidth: 2)
            )
    }

    private var borderColor: Color {
        guard let toast = visibleToast else { return .clear }
        return (toast.kind == .correct ? Theme.good : Theme.bad).opacity(0.7)
    }

    /// 打鍵済み・現在位置・未入力を色分けした式。
    private func attributed(_ problem: Problem) -> AttributedString {
        var result = AttributedString()
        for unit in problem.display {
            var piece = AttributedString(unit.text)
            if let index = unit.targetIndex {
                if index < engine.typedCount {
                    piece.foregroundColor = .secondary
                } else if index == engine.typedCount {
                    piece.foregroundColor = .white
                    piece.backgroundColor = .accentColor
                } else {
                    piece.foregroundColor = .primary
                }
            }
            result.append(piece)
        }
        return result
    }

    // MARK: - 下部

    @ViewBuilder
    private var footer: some View {
        if showGuide {
            NumpadGuide(nextChar: engine.nextChar, awaitingEnter: engine.isAwaitingEnter)
                .padding(.top, 4)
        } else {
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var countdownOverlay: some View {
        if case .countdown(let n) = engine.phase {
            ZStack {
                Rectangle().fill(.regularMaterial)
                VStack(spacing: 10) {
                    Text("\(n)")
                        .font(.system(size: 96, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("テンキーの準備はいいですか")
                        .foregroundStyle(.secondary)
                }
            }
            .transition(.opacity)
        }
    }

    // MARK: - キー入力

    private func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            guard let input = KeyMapper.input(from: event, numpadOnly: numpadOnly) else {
                return event
            }
            MainActor.assumeIsolated {
                if input == .escape {
                    onQuit()
                } else {
                    engine.handle(input)
                }
            }
            return nil  // 消費したイベントはシステムに渡さない（ビープ防止）
        }
    }

    private func removeMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
