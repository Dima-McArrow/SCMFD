import Foundation

nonisolated struct ChannelThemeChange: Equatable, Sendable {
    let streamId: UUID
    let seq: Int64
    let theme: AppTheme
}

/// Channel membership is independent of the pilot-seat context. Replayed pages cannot replay a theme change.
nonisolated struct ShipChannelThemeTracker: Sendable {
    private var streamId: UUID?
    private var lastSeq: Int64 = 0
    private var activeChannel: String?
    private var pendingChange: ChannelThemeChange?
    private(set) var hasEvidence = false

    mutating func receive(_ page: ServerActivityPage) -> ChannelThemeChange? {
        guard page.isValid else { return nil }
        if streamId != page.streamId {
            streamId = page.streamId
            lastSeq = 0
            activeChannel = nil
            pendingChange = nil
            hasEvidence = false
        }
        for event in page.events where event.seq > lastSeq {
            if lastSeq > 0, event.seq != lastSeq + 1 {
                activeChannel = nil
                pendingChange = nil
                hasEvidence = false
            }
            lastSeq = event.seq
            if event.kind == "shipChannelJoined", let channel = event.channelId,
               let manufacturer = Manufacturer(channelName: event.text) {
                activeChannel = channel
                hasEvidence = true
                pendingChange = ChannelThemeChange(streamId: page.streamId, seq: event.seq, theme: .manufacturer(manufacturer))
            } else if event.kind == "shipChannelLeft", event.channelId == activeChannel, activeChannel != nil {
                activeChannel = nil
                hasEvidence = true
                pendingChange = ChannelThemeChange(streamId: page.streamId, seq: event.seq, theme: .standard)
            } else if event.kind == "sessionEnded" {
                activeChannel = nil
                hasEvidence = true
                pendingChange = ChannelThemeChange(streamId: page.streamId, seq: event.seq, theme: .standard)
            }
        }
        // Apply the final result of a paginated replay, not every historical join along the way.
        guard lastSeq >= page.latestSeq, let change = pendingChange else { return nil }
        pendingChange = nil
        return change
    }
}

nonisolated extension Manufacturer {
    init?(channelName: String) {
        let brands: [(String, Manufacturer)] = [
            ("Consolidated Outland", .consolidatedOutland), ("CNOU", .consolidatedOutland),
            ("RSI", .rsi), ("Drake", .drake), ("Aegis", .aegis), ("Anvil", .anvil),
            ("Origin", .origin), ("Argo", .argo), ("Crusader", .crusader), ("MISC", .misc),
            ("Mirai", .mirai), ("Greycat", .greycat), ("Tumbril", .tumbril), ("Kruger", .kruger),
            ("Aopoa", .aopoa), ("Banu", .banu), ("Esperia", .esperia), ("Gatac", .gatac), ("Vanduul", .vanduul),
        ]
        let name = channelName.lowercased()
        guard let match = brands.first(where: { name == $0.0.lowercased() || name.hasPrefix($0.0.lowercased() + " ") }) else { return nil }
        self = match.1
    }
}
