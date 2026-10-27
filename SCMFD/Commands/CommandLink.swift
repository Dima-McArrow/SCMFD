import Foundation
import OSLog

nonisolated struct KeyEvent: Sendable, Equatable {
    enum Phase: Sendable, Equatable {
        case down
        case up
        /// Press and keep the key down for a fixed time, then release.
        /// The server times the release itself, so network hiccups can't stretch or cut the hold.
        case hold(milliseconds: Int)

        var label: String {
            switch self {
            case .down: "DOWN"
            case .up: "UP"
            case .hold(let milliseconds): "HOLD \(milliseconds)ms"
            }
        }
    }

    let action: ShipAction
    let chord: KeyChord
    let phase: Phase
    let timestamp: Date

    init(action: ShipAction, phase: Phase, chord: KeyChord? = nil, timestamp: Date = .now) {
        self.action = action
        self.chord = chord ?? action.defaultChord
        self.phase = phase
        self.timestamp = timestamp
    }
}

/// A line typed into the in-game chat, e.g. an emote like `/wave2`.
/// The server opens the chat, types the text and presses Enter, so the chat key
/// stays a server-side setting.
nonisolated struct ChatEvent: Sendable {
    let text: String
    let timestamp: Date

    init(text: String, timestamp: Date = .now) {
        self.text = text
        self.timestamp = timestamp
    }
}

/// What became of one sent command. `send` returns at once so presses keep their order;
/// the server's answer arrives later through `outcome`.
nonisolated struct CommandTicket: Sendable {
    let id: UUID
    let outcome: Task<CommandOutcome, Never>

    /// For links that know the result immediately, like the console stub.
    static func immediate(_ outcome: CommandOutcome) -> CommandTicket {
        CommandTicket(id: UUID(), outcome: Task { outcome })
    }
}

/// Transport for key and chat events. The deck only talks to this protocol, so the console
/// stub and the network link to the Windows server are interchangeable.
nonisolated protocol CommandLink: Sendable {
    @MainActor @discardableResult func send(_ event: KeyEvent) -> CommandTicket
    @MainActor @discardableResult func send(chat event: ChatEvent) -> CommandTicket
    /// Yields once if input that was already `sent` ends early on the server
    /// (`input_cancelled`, `auto_released`), with the server's reason. Subscribe right after
    /// `send` and cancel the consuming task when the input ends normally.
    @MainActor func interruptions(of commandId: UUID) -> AsyncStream<String?>
}

extension CommandLink {
    /// Links without a server never interrupt input.
    @MainActor func interruptions(of commandId: UUID) -> AsyncStream<String?> {
        AsyncStream { $0.finish() }
    }
}

nonisolated enum InterruptionReason {
    /// Text for the server's `reason` of `input_cancelled` / `auto_released`.
    /// Unknown or missing reasons fall back to "Cancelled".
    static func label(for reason: String?) -> LocalizedStringResource {
        guard let known = reason.flatMap(CancelReason.init(rawValue:)) else { return "Cancelled" }
        // Exhaustive on purpose: a new CancelReason case must get its own label.
        switch known {
        case .focusLost: return "Game lost focus"
        case .sessionLocked: return "PC locked"
        case .gameEnded: return "Game ended"
        case .shipContextChanged: return "Ship changed"
        case .paused: return "Input paused"
        case .clientReplaced: return "Another device took over"
        case .revoked: return "iPad unpaired"
        case .disconnected: return "Connection lost"
        case .watchdog: return "Auto-released"
        case .shutdown: return "Server stopped"
        case .releaseAll: return "Released"
        }
    }
}

nonisolated extension CommandOutcome {
    /// Short reason shown on a key when the command did not take effect; nil when it did.
    var failureLabel: LocalizedStringResource? {
        switch self {
        case .sent, .ignored:
            nil
        case .rejected(let reason):
            switch reason.flatMap(RejectReason.init(rawValue:)) {
            case .busy: "Busy"
            case .gameNotFocused: "Game not focused"
            case .gameNotRunning: "Game not running"
            case .rateLimited: "Too fast"
            case .expired: "Expired"
            case .inputPaused: "Input paused"
            case .inputFailed: "Input failed"
            // The PC's emotes.txt does not list the emote; the user can fix that on the PC.
            case .invalid: "Not allowed on PC"
            default: "Rejected"
            }
        case .unknown:
            "Result unknown"
        case .notSent(.notConnected):
            "No server link"
        case .notSent(.tooManyPending):
            "Too fast"
        }
    }
}

/// Prints every press and release to the Xcode console. No network, no side effects.
nonisolated final class ConsoleCommandLink: CommandLink {
    private let logger = Logger(subsystem: "com.csmfd.app", category: "Keys")

    func send(_ event: KeyEvent) -> CommandTicket {
        let chord = event.chord.description.padding(toLength: 10, withPad: " ", startingAt: 0)
        let phase = event.phase.label.padding(toLength: 12, withPad: " ", startingAt: 0)
        let line = "⌨️ \(phase)  \(chord) · \(event.action.rawValue)"
        logger.notice("\(line, privacy: .public)")
        return .immediate(.sent)
    }

    func send(chat event: ChatEvent) -> CommandTicket {
        logger.notice("💬 CHAT          \(event.text, privacy: .public)")
        return .immediate(.sent)
    }
}
