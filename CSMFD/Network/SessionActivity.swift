import Foundation

/// Bounded replay page from the PC's existing log reader. This is not wallet telemetry.
nonisolated struct ServerActivityPage: Decodable, Sendable, Equatable {
    let sessionId: UUID
    let streamId: UUID
    let startedAt: Date
    let firstSeq: Int64
    let latestSeq: Int64
    let ended: Bool
    let events: [SessionActivityEvent]

    var isValid: Bool {
        guard firstSeq >= 1, latestSeq >= 0, latestSeq <= 9_007_199_254_740_991,
              firstSeq <= latestSeq + 1, events.count <= 4,
              !events.isEmpty || latestSeq == 0 else { return false }
        var previous: Int64?
        for event in events {
            guard event.seq >= firstSeq, event.seq <= latestSeq,
                  previous.map({ event.seq == $0 + 1 }) ?? true, event.isValid else { return false }
            previous = event.seq
        }
        return true
    }
}

nonisolated struct SessionActivityEvent: Codable, Sendable, Equatable, Identifiable {
    let seq: Int64
    let kind: String
    let at: Date
    let text: String
    let missionId: UUID?
    let objectiveId: String?
    let amount: Int64?
    let currency: String?

    var id: Int64 { seq }

    var isValid: Bool {
        guard seq > 0, text.unicodeScalars.count <= 160,
              !text.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              (objectiveId?.unicodeScalars.count ?? 0) <= 96,
              !(objectiveId?.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) ?? false) else { return false }
        if kind == "reward" {
            guard let amount, amount > 0, amount <= 1_000_000_000,
                  currency == "aUEC" || currency == "UEC" else { return false }
        } else if amount != nil || currency != nil {
            return false
        }
        if Self.contractKinds.contains(kind), missionId == nil { return false }
        return true
    }

    static let contractKinds: Set<String> = [
        "contractAccepted", "contractComplete", "contractWithdrawn", "contractFailed",
        "newObjective", "objectiveComplete",
    ]
}
