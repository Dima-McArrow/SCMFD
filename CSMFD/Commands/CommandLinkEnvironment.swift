import SwiftUI

nonisolated private struct CommandLinkKey: EnvironmentKey {
    static let defaultValue: any CommandLink = ConsoleCommandLink()
}

extension EnvironmentValues {
    var commandLink: any CommandLink {
        get { self[CommandLinkKey.self] }
        set { self[CommandLinkKey.self] = newValue }
    }
}
