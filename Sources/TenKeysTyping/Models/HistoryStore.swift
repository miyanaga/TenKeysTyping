import Foundation

/// プレイ記録を Application Support 配下の JSON に永続化する。
@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var records: [SessionRecord] = []

    private let fileURL: URL

    init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("TenKeysTyping", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("history.json")
        load()
    }

    /// 指定モードの記録を古い順で返す。
    func records(for mode: GameMode) -> [SessionRecord] {
        records.filter { $0.mode == mode }.sorted { $0.date < $1.date }
    }

    func best(for mode: GameMode) -> SessionRecord? {
        records(for: mode).max { $0.score < $1.score }
    }

    func append(_ record: SessionRecord) {
        records.append(record)
        save()
    }

    func deleteAll(for mode: GameMode) {
        records.removeAll { $0.mode == mode }
        save()
    }

    func deleteAll() {
        records.removeAll()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        records = (try? decoder.decode([SessionRecord].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
