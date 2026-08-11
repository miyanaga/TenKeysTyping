import Foundation

/// 出題に使う演算子。表示記号と打鍵すべき文字を分けて持つ。
enum Op: Character, CaseIterable, Codable {
    case add = "+"
    case sub = "-"
    case mul = "*"
    case div = "/"

    /// 画面表示用の記号（打鍵対象は rawValue のほう）
    var symbol: String {
        switch self {
        case .add: return "+"
        case .sub: return "−"
        case .mul: return "×"
        case .div: return "÷"
        }
    }
}

/// 1レベル分の出題パラメータ。
struct LevelSpec {
    let minDigits: Int
    let maxDigits: Int
    /// 項の数（2 なら `a + b`、3 なら `a + b - c`）
    let terms: Int
    let ops: [Op]

    var label: String {
        let digits = minDigits == maxDigits ? "\(minDigits)桁" : "\(minDigits)〜\(maxDigits)桁"
        let opText = ops.map(\.symbol).joined()
        return "\(digits) / \(terms)項 / \(opText)"
    }
}

/// プレイ時間＝難易度。時間が長いモードほど到達レベルが高い。
enum GameMode: String, CaseIterable, Codable, Identifiable {
    case sprint     // 30秒
    case standard   // 60秒
    case endurance  // 120秒

    var id: String { rawValue }

    var duration: TimeInterval {
        switch self {
        case .sprint: return 30
        case .standard: return 60
        case .endurance: return 120
        }
    }

    var title: String {
        switch self {
        case .sprint: return "スプリント"
        case .standard: return "スタンダード"
        case .endurance: return "エンデュランス"
        }
    }

    var durationLabel: String {
        switch self {
        case .sprint: return "30秒"
        case .standard: return "60秒"
        case .endurance: return "2分"
        }
    }

    var caption: String {
        switch self {
        case .sprint: return "3〜6桁 / 加減算中心。軽く指をならす"
        case .standard: return "3〜7桁 / 四則すべて。実戦想定の基本練習"
        case .endurance: return "4〜9桁 / 長い連続式まで。持久力と精度"
        }
    }

    /// 経過時間に応じて上がっていくレベル表。
    var levels: [LevelSpec] {
        switch self {
        case .sprint:
            return [
                LevelSpec(minDigits: 3, maxDigits: 3, terms: 2, ops: [.add]),
                LevelSpec(minDigits: 3, maxDigits: 4, terms: 2, ops: [.add, .sub]),
                LevelSpec(minDigits: 4, maxDigits: 4, terms: 2, ops: [.add, .sub]),
                LevelSpec(minDigits: 4, maxDigits: 5, terms: 3, ops: [.add, .sub]),
                LevelSpec(minDigits: 5, maxDigits: 5, terms: 3, ops: [.add, .sub, .mul]),
                LevelSpec(minDigits: 5, maxDigits: 6, terms: 3, ops: [.add, .sub, .mul]),
            ]
        case .standard:
            return [
                LevelSpec(minDigits: 3, maxDigits: 4, terms: 2, ops: [.add, .sub]),
                LevelSpec(minDigits: 4, maxDigits: 4, terms: 2, ops: [.add, .sub]),
                LevelSpec(minDigits: 4, maxDigits: 5, terms: 2, ops: [.add, .sub]),
                LevelSpec(minDigits: 4, maxDigits: 5, terms: 3, ops: [.add, .sub]),
                LevelSpec(minDigits: 5, maxDigits: 6, terms: 3, ops: [.add, .sub, .mul]),
                LevelSpec(minDigits: 5, maxDigits: 6, terms: 3, ops: [.add, .sub, .mul, .div]),
                LevelSpec(minDigits: 6, maxDigits: 7, terms: 3, ops: [.add, .sub, .mul, .div]),
                LevelSpec(minDigits: 6, maxDigits: 7, terms: 4, ops: [.add, .sub, .mul, .div]),
            ]
        case .endurance:
            return [
                LevelSpec(minDigits: 4, maxDigits: 4, terms: 2, ops: [.add, .sub]),
                LevelSpec(minDigits: 4, maxDigits: 5, terms: 2, ops: [.add, .sub]),
                LevelSpec(minDigits: 5, maxDigits: 5, terms: 2, ops: [.add, .sub]),
                LevelSpec(minDigits: 5, maxDigits: 6, terms: 3, ops: [.add, .sub]),
                LevelSpec(minDigits: 5, maxDigits: 6, terms: 3, ops: [.add, .sub, .mul]),
                LevelSpec(minDigits: 6, maxDigits: 7, terms: 3, ops: [.add, .sub, .mul, .div]),
                LevelSpec(minDigits: 6, maxDigits: 7, terms: 4, ops: [.add, .sub, .mul, .div]),
                LevelSpec(minDigits: 7, maxDigits: 8, terms: 4, ops: [.add, .sub, .mul, .div]),
                LevelSpec(minDigits: 7, maxDigits: 8, terms: 4, ops: [.add, .sub, .mul, .div]),
                LevelSpec(minDigits: 8, maxDigits: 9, terms: 5, ops: [.add, .sub, .mul, .div]),
            ]
        }
    }

    var maxLevel: Int { levels.count }

    /// 経過割合(0...1)から現在レベル(1始まり)を求める。
    func level(atProgress progress: Double) -> Int {
        let clamped = min(max(progress, 0), 0.9999)
        return Int(clamped * Double(maxLevel)) + 1
    }

    func spec(forLevel level: Int) -> LevelSpec {
        levels[min(max(level, 1), maxLevel) - 1]
    }
}
