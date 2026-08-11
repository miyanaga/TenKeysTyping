import Foundation

/// 表示用の1文字分。`targetIndex` が nil の要素は装飾（空白・桁区切り）で、打鍵対象ではない。
struct DisplayUnit {
    let text: String
    let targetIndex: Int?
}

struct Problem {
    /// 実際に打鍵すべき文字列（例: "12345+678"）。空白や桁区切りは含まない。
    let target: [Character]
    /// 画面表示用の並び。
    let display: [DisplayUnit]
    /// 参考解（×÷を優先した通常の演算順序で評価）
    let answer: Double

    var length: Int { target.count }

    var answerText: String { Problem.format(answer) }

    static func format(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.groupingSeparator = ","
        if abs(value.rounded() - value) < 1e-9 {
            fmt.maximumFractionDigits = 0
        } else {
            fmt.minimumFractionDigits = 2
            fmt.maximumFractionDigits = 2
        }
        return fmt.string(from: NSNumber(value: value)) ?? String(value)
    }
}

enum ProblemGenerator {
    /// 桁区切りに使う細いスペース（表示専用）
    private static let groupSeparator = "\u{2009}"

    static func make(spec: LevelSpec, groupDigits: Bool) -> Problem {
        var numbers: [String] = [randomNumber(min: spec.minDigits, max: spec.maxDigits)]
        var ops: [Op] = []

        for _ in 1..<spec.terms {
            let op = spec.ops.randomElement() ?? .add
            ops.append(op)
            switch op {
            case .mul, .div:
                // 電卓実務に寄せて、乗除の相手は小さめの数にする
                numbers.append(randomNumber(min: 1, max: min(3, max(1, spec.maxDigits))))
            case .add, .sub:
                numbers.append(randomNumber(min: spec.minDigits, max: spec.maxDigits))
            }
        }

        var target: [Character] = []
        var display: [DisplayUnit] = []

        for (i, number) in numbers.enumerated() {
            if i > 0 {
                let op = ops[i - 1]
                display.append(DisplayUnit(text: " ", targetIndex: nil))
                display.append(DisplayUnit(text: op.symbol, targetIndex: target.count))
                target.append(op.rawValue)
                display.append(DisplayUnit(text: " ", targetIndex: nil))
            }
            append(number: number, groupDigits: groupDigits, target: &target, display: &display)
        }

        return Problem(target: target, display: display, answer: evaluate(numbers: numbers, ops: ops))
    }

    private static func append(number: String,
                               groupDigits: Bool,
                               target: inout [Character],
                               display: inout [DisplayUnit]) {
        let digits = Array(number)
        for (i, digit) in digits.enumerated() {
            let remaining = digits.count - i
            if groupDigits, i > 0, remaining % 3 == 0 {
                display.append(DisplayUnit(text: groupSeparator, targetIndex: nil))
            }
            display.append(DisplayUnit(text: String(digit), targetIndex: target.count))
            target.append(digit)
        }
    }

    private static func randomNumber(min minDigits: Int, max maxDigits: Int) -> String {
        let digits = Int.random(in: max(1, minDigits)...max(1, maxDigits))
        var s = String(Int.random(in: 1...9))
        for _ in 1..<max(1, digits) {
            s.append(String(Int.random(in: 0...9)))
        }
        return s
    }

    /// ×÷を先に畳んでから ＋− を左から評価する（通常の演算子優先順位）。
    private static func evaluate(numbers: [String], ops: [Op]) -> Double {
        var values = numbers.map { Double($0) ?? 0 }
        var operators = ops

        var i = 0
        while i < operators.count {
            switch operators[i] {
            case .mul:
                values[i] = values[i] * values[i + 1]
                values.remove(at: i + 1)
                operators.remove(at: i)
            case .div:
                let divisor = values[i + 1]
                values[i] = divisor == 0 ? values[i] : values[i] / divisor
                values.remove(at: i + 1)
                operators.remove(at: i)
            case .add, .sub:
                i += 1
            }
        }

        var result = values.first ?? 0
        for (i, op) in operators.enumerated() {
            let rhs = values[i + 1]
            result = op == .add ? result + rhs : result - rhs
        }
        return result
    }
}
