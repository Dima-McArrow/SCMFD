import Foundation

/// A family of emote chat commands. `/wave` plays a random variant; `/wave2` a specific one.
nonisolated struct EmoteGroup: Identifiable, Sendable {
    /// Command stem without the slash, e.g. "wave" or "asl_thanks".
    let stem: String
    /// Number of numbered variants; 0 means the command has no number.
    let variants: Int
    /// Display name; commands are English in game, so the name is not localized.
    let title: String

    var id: String { stem }

    var command: String { "/\(stem)" }

    func command(variant: Int) -> String { "/\(stem)\(variant)" }

    init(_ stem: String, variants: Int = 0, title: String? = nil) {
        self.stem = stem
        self.variants = variants
        self.title = title ?? stem.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

/// Emotes grouped for the tablet. Source: starcitizen.tools/Emotes (command table from 3.7 PTU).
nonisolated enum EmoteCategory: String, CaseIterable, Identifiable, Sendable {
    case greetings
    case gestures
    case reactions
    case poses
    case signLanguage

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .greetings: "Greetings"
        case .gestures: "Gestures"
        case .reactions: "Reactions"
        case .poses: "Poses"
        case .signLanguage: "Sign language"
        }
    }

    var groups: [EmoteGroup] {
        switch self {
        case .greetings:
            [
                EmoteGroup("wave", variants: 2),
                EmoteGroup("greet", variants: 2),
                EmoteGroup("salute", variants: 2),
                EmoteGroup("bow", variants: 6),
                EmoteGroup("atease", title: "At ease"),
                EmoteGroup("attention"),
            ]
        case .gestures:
            [
                EmoteGroup("come", variants: 4),
                EmoteGroup("point", variants: 4),
                EmoteGroup("wait", variants: 2),
                EmoteGroup("agree"),
                EmoteGroup("threaten", variants: 2),
                EmoteGroup("rude", variants: 3),
                EmoteGroup("flirt"),
                EmoteGroup("chicken"),
            ]
        case .reactions:
            [
                EmoteGroup("cheer", variants: 8),
                EmoteGroup("clap", variants: 7),
                EmoteGroup("laugh", variants: 3),
                EmoteGroup("gasp", variants: 5),
                EmoteGroup("gloat", variants: 4),
                EmoteGroup("flex", variants: 3),
                EmoteGroup("angry", variants: 3),
                EmoteGroup("bored", variants: 2),
                EmoteGroup("blah", variants: 2),
                EmoteGroup("cry"),
                EmoteGroup("failure"),
                EmoteGroup("burp"),
                EmoteGroup("smell", variants: 2),
                EmoteGroup("whistle", variants: 2),
            ]
        case .poses:
            [
                EmoteGroup("dance", variants: 6),
                EmoteGroup("sit"),
                EmoteGroup("stand"),
                EmoteGroup("sleep"),
            ]
        case .signLanguage:
            [
                EmoteGroup("asl_hello", title: "Hello"),
                EmoteGroup("asl_goodbye", title: "Goodbye"),
                EmoteGroup("asl_meetyou", title: "Nice to meet you"),
                EmoteGroup("asl_thanks", variants: 2, title: "Thanks"),
                EmoteGroup("asl_yes", variants: 2, title: "Yes"),
                EmoteGroup("asl_no", variants: 2, title: "No"),
                EmoteGroup("asl_loveyou", title: "Love you"),
                EmoteGroup("asl_canthear", title: "Can't hear"),
                EmoteGroup("asl_sitdown", variants: 2, title: "Sit down"),
                EmoteGroup("asl_blah", variants: 2, title: "Blah"),
                EmoteGroup("asl_bored", title: "Bored"),
                EmoteGroup("asl_exhausted", title: "Exhausted"),
                EmoteGroup("asl_sad", title: "Sad"),
                EmoteGroup("asl_upset", title: "Upset"),
                EmoteGroup("asl_angry", title: "Angry"),
                EmoteGroup("asl_bullshit", title: "Bullshit"),
            ]
        }
    }
}
