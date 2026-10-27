import Foundation

/// `CommandLink` over the paired Windows server. Each command gets its own UUID and a
/// receipt that resolves with the server's ack (or a local reason it never left).
@MainActor
final class NetworkCommandLink: CommandLink {
    private let connection: ServerConnection
    private var waiters: [UUID: AsyncStream<CommandOutcome>.Continuation] = [:]
    private var interruptionWaiters: [UUID: AsyncStream<String?>.Continuation] = [:]

    init(connection: ServerConnection) {
        self.connection = connection
        connection.onCommandFinished = { [weak self] id, outcome in
            self?.finish(id, with: outcome)
        }
        connection.onInputEnded = { [weak self] id, reason in
            self?.interrupt(id, reason: reason)
        }
    }

    func interruptions(of commandId: UUID) -> AsyncStream<String?> {
        let (stream, continuation) = AsyncStream.makeStream(of: String?.self)
        interruptionWaiters[commandId] = continuation
        // The subscriber cancels when the hold ends normally; drop the entry then.
        continuation.onTermination = { [weak self] _ in
            let link = self
            Task { @MainActor in link?.interruptionWaiters.removeValue(forKey: commandId) }
        }
        return stream
    }

    func send(_ event: KeyEvent) -> CommandTicket {
        submit(.key(event))
    }

    func send(chat event: ChatEvent) -> CommandTicket {
        submit(.chat(event.text))
    }

    /// Lets go of everything this iPad holds, e.g. before the app leaves the screen.
    @discardableResult
    func releaseAll() -> CommandTicket {
        submit(.releaseAll)
    }

    private func submit(_ command: SessionCommand) -> CommandTicket {
        let id = UUID()
        // Register first: a command that cannot be sent finishes synchronously inside `send`.
        let (stream, continuation) = AsyncStream.makeStream(of: CommandOutcome.self)
        waiters[id] = continuation
        connection.send(command, id: id)
        let outcome = Task {
            for await value in stream {
                return value
            }
            return CommandOutcome.unknown
        }
        return CommandTicket(id: id, outcome: outcome)
    }

    private func interrupt(_ id: UUID, reason: String?) {
        guard let continuation = interruptionWaiters.removeValue(forKey: id) else { return }
        continuation.yield(reason)
        continuation.finish()
    }

    private func finish(_ id: UUID, with outcome: CommandOutcome) {
        guard let continuation = waiters.removeValue(forKey: id) else { return }
        continuation.yield(outcome)
        continuation.finish()
    }
}
