import SwiftUI

/// 次に押すキーを光らせるテンキーの見取り図。
struct NumpadGuide: View {
    /// 次に打つべき文字（nil なら Enter 待ち）
    let nextChar: Character?
    let awaitingEnter: Bool

    private let cell: CGFloat = 42
    private let gap: CGFloat = 6

    var body: some View {
        VStack(spacing: gap) {
            HStack(spacing: gap) {
                key("clear", label: "clr", width: cell)
                key("/", label: "/", width: cell)
                key("*", label: "*", width: cell)
                key("-", label: "−", width: cell)
            }
            HStack(alignment: .top, spacing: gap) {
                VStack(spacing: gap) {
                    HStack(spacing: gap) { key("7"); key("8"); key("9") }
                    HStack(spacing: gap) { key("4"); key("5"); key("6") }
                    HStack(spacing: gap) { key("1"); key("2"); key("3") }
                    HStack(spacing: gap) {
                        key("0", label: "0", width: cell * 2 + gap)
                        key(".", label: ".", width: cell)
                    }
                }
                VStack(spacing: gap) {
                    key("+", label: "+", width: cell, height: cell * 2 + gap)
                    key("enter", label: "⏎", width: cell, height: cell * 2 + gap)
                }
            }
        }
    }

    private func key(_ id: String, label: String? = nil, width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        let text = label ?? id
        let active = isActive(id)
        return RoundedRectangle(cornerRadius: 8)
            .fill(active ? Color.accentColor : Color.secondary.opacity(0.12))
            .frame(width: width ?? cell, height: height ?? cell)
            .overlay(
                Text(text)
                    .font(.system(size: id == "enter" ? 17 : 15, weight: active ? .bold : .medium, design: .rounded))
                    .foregroundStyle(active ? Color.white : Color.secondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(active ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.08), value: active)
    }

    private func isActive(_ id: String) -> Bool {
        if awaitingEnter { return id == "enter" }
        guard let nextChar else { return false }
        return id == String(nextChar)
    }
}
