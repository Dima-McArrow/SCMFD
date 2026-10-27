import Foundation

/// A key combination as the Windows server will press it, e.g. `Alt+N` or `Backspace`.
/// Codable so it can travel over the wire unchanged.
nonisolated struct KeyChord: Hashable, Codable, Sendable, CustomStringConvertible {
    enum Modifier: String, Codable, Sendable, CaseIterable {
        // Declaration order is the display order: Ctrl+Shift+Alt+RAlt+Key.
        // Plain names are the left-hand keys; Star Citizen tells left and right Alt apart.
        case ctrl
        case shift
        case alt
        case ralt

        var displayName: String {
            switch self {
            case .ctrl: "Ctrl"
            case .shift: "Shift"
            case .alt: "Alt"
            case .ralt: "RAlt"
            }
        }
    }

    let modifiers: Set<Modifier>
    /// Lowercase key name in the server's vocabulary: "n", "b", "backspace", "f5"...
    /// Mouse buttons use "mouse1" (left), "mouse2" (right) and "mouse3" (middle).
    let key: String

    init(_ key: String, _ modifiers: Modifier...) {
        self.key = key.lowercased()
        self.modifiers = Set(modifiers)
    }

    var description: String {
        let mods = Modifier.allCases.filter(modifiers.contains).map(\.displayName)
        return (mods + [Self.displayName(for: key)]).joined(separator: "+")
    }

    private static func displayName(for key: String) -> String {
        switch key {
        case "mouse1": "LMB"
        case "mouse2": "RMB"
        case "mouse3": "MMB"
        default: key.count == 1 ? key.uppercased() : key.capitalized
        }
    }
}
