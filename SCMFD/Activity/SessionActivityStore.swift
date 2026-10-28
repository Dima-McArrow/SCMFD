import Foundation
import Observation

nonisolated struct ObservedObjective: Codable, Sendable, Equatable, Identifiable {
    let id: String
    var text: String
    var completed: Bool
}

nonisolated struct ObservedContract: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    var title: String?
    var status = "observed"
    var updatedAt: Date
    var objectives: [ObservedObjective] = []
}

nonisolated struct RecordedSession: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    let streamId: UUID
    let startedAt: Date
    var lastSeq: Int64 = 0
    var ended = false
    var incomplete = false
    var rewards: [String: Int64] = [:]
    var rewardCount = 0
    var recentEvents: [SessionActivityEvent] = []
    var contracts: [ObservedContract] = []

    mutating func apply(_ event: SessionActivityEvent) {
        guard event.seq > lastSeq else { return }
        if event.seq != lastSeq + 1 { incomplete = true }
        lastSeq = event.seq
        recentEvents.insert(event, at: 0)
        recentEvents = Array(recentEvents.prefix(128))
        if event.kind == "reward", let amount = event.amount, let currency = event.currency {
            let (total, overflow) = rewards[currency, default: 0].addingReportingOverflow(amount)
            if overflow { incomplete = true } else { rewards[currency] = total }
            rewardCount += 1
        } else if event.kind == "sessionEnded" {
            ended = true
        } else if SessionActivityEvent.contractKinds.contains(event.kind), let mission = event.missionId {
            var contract = contracts.first(where: { $0.id == mission })
                ?? ObservedContract(id: mission, updatedAt: event.at)
            contract.updatedAt = event.at
            switch event.kind {
            case "contractAccepted":
                contract.title = event.text
                if contract.status == "observed" { contract.status = "accepted" }
            case "contractComplete", "contractWithdrawn", "contractFailed":
                contract.title = event.text.isEmpty ? contract.title : event.text
                contract.status = event.kind
            case "newObjective", "objectiveComplete":
                // Objective IDs are preferred; text is only a fallback within this mission.
                let identity = event.objectiveId ?? "text:\(event.text)"
                if let index = contract.objectives.firstIndex(where: { $0.id == identity }) {
                    contract.objectives[index].text = event.text
                    contract.objectives[index].completed = contract.objectives[index].completed || event.kind == "objectiveComplete"
                } else {
                    contract.objectives.append(ObservedObjective(id: identity, text: event.text, completed: event.kind == "objectiveComplete"))
                }
                if contract.objectives.count > 32 {
                    contract.objectives.removeFirst(contract.objectives.count - 32)
                    incomplete = true
                }
            default: break
            }
            contracts.removeAll { $0.id == mission }
            contracts.insert(contract, at: 0)
            if contracts.count > 128 {
                contracts = Array(contracts.prefix(128))
                incomplete = true
            }
        } else if event.kind != "shipChannelJoined" && event.kind != "shipChannelLeft" {
            incomplete = true
        }
    }
}

/// FE-owned ledger/history. Replayed pages cannot double-count rewards or reset sessions on reconnect.
@Observable
final class SessionActivityStore {
    private(set) var sessions: [RecordedSession] = []
    private(set) var storageFailed = false
    private(set) var receivedLiveFeed = false
    private(set) var isConnected = false
    private(set) var isCaughtUp = false
    @ObservationIgnored private let fileURL: URL?
    @ObservationIgnored private var canSave = true

    nonisolated static var defaultFileURL: URL {
        URL.applicationSupportDirectory.appending(path: "CSMFD/session-history.json")
    }

    init(fileURL: URL? = SessionActivityStore.defaultFileURL) {
        self.fileURL = fileURL
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let size = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 16 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
            let saved = try JSONDecoder().decode([RecordedSession].self, from: Data(contentsOf: fileURL))
            guard saved.count <= 12, saved.allSatisfy({ record in
                record.lastSeq >= 0 && record.lastSeq <= 9_007_199_254_740_991 && record.rewardCount >= 0
                && record.rewards.allSatisfy({ entry in (entry.key == "aUEC" || entry.key == "UEC") && entry.value >= 0 })
                && record.contracts.count <= 128 && record.recentEvents.count <= 128
                && record.recentEvents.allSatisfy({ $0.isValid })
                && record.contracts.allSatisfy({ $0.objectives.count <= 32 })
            }) else { throw CocoaError(.fileReadCorruptFile) }
            sessions = saved
        } catch {
            storageFailed = true
            // Preserve an unreadable history instead of overwriting it with an empty ledger.
            canSave = false
        }
    }

    func receive(_ page: ServerActivityPage) {
        guard page.isValid else { return }
        receivedLiveFeed = true
        isConnected = true
        var index: Int
        if let existing = sessions.firstIndex(where: { $0.streamId == page.streamId }) {
            index = existing
        } else {
            if !sessions.isEmpty, !sessions[0].ended {
                sessions[0].ended = true
                sessions[0].incomplete = true
            }
            sessions.insert(RecordedSession(id: UUID(), streamId: page.streamId, startedAt: page.startedAt), at: 0)
            sessions = Array(sessions.prefix(12))
            index = 0
        }
        var record = sessions[index]
        if page.firstSeq > record.lastSeq + 1 { record.incomplete = true }
        for event in page.events { record.apply(event) }
        if page.ended && record.lastSeq >= page.latestSeq { record.ended = true }
        let changed = sessions[index] != record
        if changed { sessions[index] = record }
        isCaughtUp = record.lastSeq >= page.latestSeq
        if changed || sessions[index].lastSeq == 0 { save() }
    }

    func setConnected(_ connected: Bool) {
        isConnected = connected
        if !connected { isCaughtUp = false }
    }

    /// A local boundary: no game command, no BE restart and no replay of pre-boundary events.
    func startNewSession(at now: Date = .now) {
        guard var previous = sessions.first, !previous.ended, isConnected, isCaughtUp else { return }
        previous.ended = true
        sessions[0] = previous
        var next = RecordedSession(id: UUID(), streamId: previous.streamId, startedAt: now)
        next.lastSeq = previous.lastSeq
        sessions.insert(next, at: 0)
        sessions = Array(sessions.prefix(12))
        save()
    }

    private func save() {
        guard let fileURL, canSave else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            var data = try JSONEncoder().encode(sessions)
            while data.count > 16 * 1024 * 1024, sessions.count > 1 {
                sessions.removeLast()
                data = try JSONEncoder().encode(sessions)
            }
            try data.write(to: fileURL, options: .atomic)
            storageFailed = false
        } catch {
            storageFailed = true
        }
    }
}
