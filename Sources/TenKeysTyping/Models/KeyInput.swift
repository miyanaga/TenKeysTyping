import AppKit

/// ゲームが解釈する入力の種類。
enum KeyInput: Equatable {
    case char(Character)   // 0-9 と + - * /
    case enter
    case clear             // 入力中の式をすべて消す
    case backspace         // 1文字戻る
    case escape            // 中断
}

enum KeyMapper {
    /// テンキーの keyCode → 文字
    private static let numpadChars: [UInt16: Character] = [
        82: "0", 83: "1", 84: "2", 85: "3", 86: "4",
        87: "5", 88: "6", 89: "7", 91: "8", 92: "9",
        67: "*", 69: "+", 75: "/", 78: "-",
    ]

    private static let numpadEnter: Set<UInt16> = [76, 81]  // enter, =
    private static let numpadClear: UInt16 = 71

    static func isNumpadKey(_ event: NSEvent) -> Bool {
        if numpadChars[event.keyCode] != nil { return true }
        if numpadEnter.contains(event.keyCode) { return true }
        return event.keyCode == numpadClear
    }

    /// - Parameter numpadOnly: true ならテンキー以外の数字・記号を受け付けない。
    static func input(from event: NSEvent, numpadOnly: Bool) -> KeyInput? {
        // ⌘ ショートカットは横取りしない
        if event.modifierFlags.contains(.command) { return nil }

        switch event.keyCode {
        case 53: return .escape          // esc
        case 51: return .backspace       // delete
        case numpadClear: return .clear  // テンキー clear
        case 36: return .enter           // return
        default: break
        }

        if numpadEnter.contains(event.keyCode) { return .enter }
        if let c = numpadChars[event.keyCode] { return .char(c) }

        guard !numpadOnly else { return nil }

        // メインキーボードからの入力（テンキーが無い環境向けフォールバック）
        guard let typed = event.characters?.first else { return nil }
        if typed.isNumber && typed.isASCII { return .char(typed) }
        switch typed {
        case "+", "-", "*", "/": return .char(typed)
        case "x", "X": return .char("*")
        case "\r", "\n", "=": return .enter
        default: return nil
        }
    }
}
