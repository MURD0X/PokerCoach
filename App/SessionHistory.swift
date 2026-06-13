import Foundation
import PokerEngine

/// One completed table session: seat taken → seat left (buy-backs at the
/// same table extend the session rather than starting a new one).
struct SessionRecord: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let bigBlind: Int
    let buyInTotal: Int
    let cashOut: Int
    let hands: Int
    let decisionsTotal: Int
    let decisionsFollowed: Int
    /// Bankroll right after settling this session — the chart's y-value.
    let balanceAfter: Int
    /// Optional; absent on cash records persisted before tournaments existed.
    var isTournament: Bool? = nil

    var net: Int { cashOut - buyInTotal }
    var stakesName: String {
        TableStakes.all.first { $0.bigBlind == bigBlind }?.name ?? "\(bigBlind / 2)/\(bigBlind)"
    }
    /// Header shown in the ledger: a tournament label or the cash stakes.
    var displayName: String {
        isTournament == true ? "Sit & Go tournament" : "Blinds \(stakesName)"
    }
    var adherencePercent: Int? {
        guard decisionsTotal > 0 else { return nil }
        return Int((Double(decisionsFollowed) / Double(decisionsTotal) * 100).rounded())
    }
}

enum SessionHistoryStore {
    static let key = "sessionHistory"
    static let maxRecords = 200

    static func load() -> [SessionRecord] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let records = try? JSONDecoder().decode([SessionRecord].self, from: data)
        else { return [] }
        return records
    }

    static func append(_ record: SessionRecord) {
        var records = load()
        records.append(record)
        if records.count > maxRecords { records.removeFirst(records.count - maxRecords) }
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

/// Live snapshot of the in-progress session, persisted continuously so a
/// killed app still produces an accurate record on the next launch.
struct SessionSnapshot: Codable {
    var startDate: Date
    var bigBlind: Int
    var buyInTotal: Int
    var hands: Int
    var decisionsTotal: Int
    var decisionsFollowed: Int

    static let key = "currentSessionSnapshot"

    static func load() -> SessionSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SessionSnapshot.self, from: data)
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: SessionSnapshot.key)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
