import Foundation
import Observation

nonisolated enum PartyEventKind: String, Sendable, CaseIterable {
    case created = "partyCreated"
    case joined = "partyJoined"
    case memberJoined = "partyMemberJoined"
    case memberLeft = "partyMemberLeft"
    case leaderChanged = "partyLeaderChanged"
    case disbanded = "partyDisbanded"

    var hasName: Bool {
        self == .memberJoined || self == .memberLeft || self == .leaderChanged
    }
}

nonisolated extension SessionActivityEvent {
    var partyKind: PartyEventKind? { PartyEventKind(rawValue: kind) }

    // Invalid social payloads are skipped by Party, without terminating the shared connection.
    var isUsablePartyObservation: Bool {
        guard let partyKind, missionId == nil, objectiveId == nil,
              amount == nil, currency == nil, channelId == nil else { return false }
        if !partyKind.hasName { return text.isEmpty }
        return !text.isEmpty && text.unicodeScalars.count <= 96
            && text == text.trimmingCharacters(in: .whitespacesAndNewlines)
            && !text.contains("\u{FFFD}")
            && !text.unicodeScalars.contains { scalar in
                CharacterSet.controlCharacters.contains(scalar) || scalar.properties.generalCategory == .format
            }
    }
}

/// Pure FE reducer. It never claims a complete roster or maps display names to entity IDs.
nonisolated struct PartyState: Sendable {
    enum Membership: Sendable { case unknown, observed, disbanded }

    private(set) var streamId: UUID?
    private(set) var lastSeq: Int64 = 0
    private(set) var membership: Membership = .unknown
    private(set) var members: [String] = []
    private(set) var leader: String?
    private(set) var lastObservedAt: Date?
    private(set) var history: [SessionActivityEvent] = []
    private(set) var hasGap = false
    private(set) var isCaughtUp = false
    private(set) var ended = false

    mutating func invalidate() {
        members = []
        leader = nil
        membership = .unknown
        hasGap = true
    }

    mutating func connectionLost() { isCaughtUp = false }

    mutating func receive(_ page: ServerActivityPage) {
        guard page.isValid else { return }
        if streamId != page.streamId {
            self = PartyState()
            streamId = page.streamId
        }
        if page.firstSeq > lastSeq + 1 { invalidate() }
        for event in page.events where event.seq > lastSeq {
            if event.seq != lastSeq + 1 { invalidate() }
            lastSeq = event.seq
            if event.kind == "sessionEnded" {
                ended = true
                continue
            }
            guard let kind = event.partyKind else { continue }
            guard event.isUsablePartyObservation else {
                invalidate()
                continue
            }
            lastObservedAt = event.at
            history.insert(event, at: 0)
            history = Array(history.prefix(128))
            switch kind {
            case .created, .joined:
                members = []
                leader = nil
                membership = .observed
            case .disbanded:
                members = []
                leader = nil
                membership = .disbanded
            case .memberJoined:
                membership = .observed
                observeMember(event.text)
            case .memberLeft:
                members.removeAll { $0 == event.text }
                if leader == event.text { leader = nil }
            case .leaderChanged:
                membership = .observed
                leader = event.text
                observeMember(event.text)
            }
        }
        isCaughtUp = lastSeq >= page.latestSeq
        if page.ended && isCaughtUp { ended = true }
    }

    private mutating func observeMember(_ name: String) {
        guard !members.contains(name) else { return }
        guard members.count < 64 else {
            hasGap = true
            return
        }
        members.append(name)
    }
}

/// Transient observations only. Old saved financial history never becomes a trusted Party roster.
@Observable
final class PartyStore {
    private(set) var state = PartyState()
    private(set) var receivedFeed = false
    private(set) var isConnected = false
    private(set) var sourceAvailable = false
    @ObservationIgnored private var serverSession: UUID?
    @ObservationIgnored private var logGeneration: UUID?

    var isStale: Bool {
        !isConnected || !sourceAvailable || !state.isCaughtUp || state.hasGap || state.ended
    }

    func receive(_ page: ServerActivityPage) {
        guard page.isValid else { return }
        receivedFeed = true
        state.receive(page)
    }

    func setConnected(_ connected: Bool) {
        isConnected = connected
        if !connected { state.connectionLost() }
    }

    func receiveState(_ snapshot: ServerState) {
        if serverSession != snapshot.sessionId {
            state = PartyState()
            receivedFeed = false
            sourceAvailable = false
            logGeneration = nil
            serverSession = snapshot.sessionId
        }
        if case .value(let log) = snapshot.log {
            if let logGeneration, logGeneration != log.generation {
                state = PartyState()
                receivedFeed = false
            }
            logGeneration = log.generation
            if state.streamId != nil && (log.status == .missing || log.status == .unreadable) {
                state.invalidate()
            }
            sourceAvailable = log.status == .ready
        }
        if case .value(let game) = snapshot.game, !game.running { sourceAvailable = false }
    }
}
