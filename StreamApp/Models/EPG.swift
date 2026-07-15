import Foundation

struct EPGProgram: Identifiable, Hashable {
    let channelID: String
    let title: String
    let desc: String?
    let start: Date
    let end: Date

    var id: String { "\(channelID)-\(start.timeIntervalSince1970)" }

    var timeRangeText: String {
        "\(Self.timeFormatter.string(from: start)) – \(Self.timeFormatter.string(from: end))"
    }

    func progress(at date: Date = .now) -> Double {
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        return min(1, max(0, date.timeIntervalSince(start) / total))
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

/// Immutable snapshot of a parsed EPG, keyed by lowercased XMLTV channel id.
struct EPGSnapshot {
    var programsByChannel: [String: [EPGProgram]] = [:]
    var updatedAt: Date?

    static let empty = EPGSnapshot()

    var isEmpty: Bool { programsByChannel.isEmpty }

    var programCount: Int {
        programsByChannel.values.reduce(0) { $0 + $1.count }
    }

    func programs(for channelID: String?) -> [EPGProgram] {
        guard let channelID else { return [] }
        return programsByChannel[channelID.lowercased()] ?? []
    }

    func current(for channelID: String?, at date: Date = .now) -> EPGProgram? {
        programs(for: channelID).first { $0.start <= date && date < $0.end }
    }

    func next(for channelID: String?, at date: Date = .now) -> EPGProgram? {
        programs(for: channelID).first { $0.start > date }
    }
}
