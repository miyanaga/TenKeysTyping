import SwiftUI

enum Theme {
    static let cardCorner: CGFloat = 14
    static let good = Color.green
    static let bad = Color.red
}

/// ミス時に左右へ揺らす。
struct Shake: GeometryEffect {
    var amount: CGFloat = 9
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let dx = amount * sin(animatableData * .pi * shakes)
        return ProjectionTransform(CGAffineTransform(translationX: dx, y: 0))
    }
}

/// 数値をラベルとセットで見せる小さなカード。
struct StatTile: View {
    let title: String
    let value: String
    var caption: String? = nil
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: Theme.cardCorner))
    }
}

extension Double {
    var percentText: String { String(format: "%.1f%%", self * 100) }
    func secondsText(digits: Int = 2) -> String { String(format: "%.\(digits)f秒", self) }
}
