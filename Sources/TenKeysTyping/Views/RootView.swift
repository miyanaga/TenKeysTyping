import SwiftUI

struct RootView: View {
    @EnvironmentObject var history: HistoryStore
    @EnvironmentObject var sound: SoundEngine
    @ObservedObject var engine: GameEngine

    enum Screen: Equatable {
        case home
        case game
        case result(SessionRecord)
        case stats
    }

    @State private var screen: Screen = .home
    @State private var lastMode: GameMode = .standard
    @State private var previousRecord: SessionRecord?
    @State private var previousBestScore: Int?

    @AppStorage("numpadOnly") private var numpadOnly = false
    @AppStorage("showGuide") private var showGuide = true
    @AppStorage("groupDigits") private var groupDigits = true

    var body: some View {
        Group {
            switch screen {
            case .home:
                HomeView(numpadOnly: $numpadOnly,
                         showGuide: $showGuide,
                         groupDigits: $groupDigits,
                         onStart: start,
                         onShowStats: { screen = .stats })

            case .game:
                GameView(engine: engine,
                         numpadOnly: numpadOnly,
                         showGuide: showGuide,
                         onQuit: {
                             engine.abort()
                             screen = .home
                         })

            case .result(let record):
                ResultView(record: record,
                           previous: previousRecord,
                           previousBestScore: previousBestScore,
                           onRetry: { start(lastMode) },
                           onHome: { screen = .home },
                           onShowStats: { screen = .stats })

            case .stats:
                StatsView(onBack: { screen = .home })
            }
        }
        .animation(.easeInOut(duration: 0.18), value: screen)
        .onAppear {
            engine.onFinish = { record in
                // 保存前のベスト・直前回を控えて、結果画面で比較に使う
                previousBestScore = history.best(for: record.mode)?.score
                previousRecord = history.records(for: record.mode).last
                history.append(record)
                if let best = previousBestScore, record.score > best {
                    sound.play(.newRecord)
                } else if previousBestScore == nil, record.score > 0 {
                    sound.play(.newRecord)
                }
                screen = .result(record)
            }

            // 動作確認用: TKT_AUTOSTART=sprint|standard|endurance で即開始、stats で記録画面を開く
            switch ProcessInfo.processInfo.environment["TKT_AUTOSTART"] {
            case "stats": screen = .stats
            case let raw?: if let mode = GameMode(rawValue: raw) { start(mode) }
            case nil: break
            }
        }
    }

    private func start(_ mode: GameMode) {
        lastMode = mode
        screen = .game
        engine.start(mode: mode, groupDigits: groupDigits)
    }
}
