import Foundation

/// 1プレイ分の記録。
struct SessionRecord: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var date: Date
    var mode: GameMode
    var score: Int
    /// 正解した問題数
    var solved: Int
    /// 未完成のまま Enter を押した回数
    var failed: Int
    /// 正しく打てたキー数
    var keyCorrect: Int
    /// 打ち間違えたキー数
    var keyMiss: Int
    var maxLevel: Int
    var maxCombo: Int
    /// 1問あたりの平均解答秒数
    var avgSolveSeconds: Double

    /// キー正確率（0...1）
    var keyAccuracy: Double {
        let total = keyCorrect + keyMiss
        return total == 0 ? 0 : Double(keyCorrect) / Double(total)
    }

    /// 問題正答率（0...1）
    var problemAccuracy: Double {
        let total = solved + failed
        return total == 0 ? 0 : Double(solved) / Double(total)
    }

    /// 1分あたりの正打鍵数
    var kpm: Double {
        let minutes = mode.duration / 60
        return minutes == 0 ? 0 : Double(keyCorrect) / minutes
    }
}

extension Array where Element == SessionRecord {
    func best(by key: (SessionRecord) -> Double) -> SessionRecord? {
        self.max { key($0) < key($1) }
    }
}
