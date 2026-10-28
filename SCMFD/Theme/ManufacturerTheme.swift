import CoreText
import SwiftUI

// MARK: - Manufacturer

nonisolated enum Manufacturer: String, CaseIterable, Identifiable, Codable, Sendable {
    case rsi
    case drake
    case aegis
    case anvil
    case origin
    case argo
    case crusader
    case misc
    case mirai
    case consolidatedOutland
    case greycat
    case tumbril
    case kruger
    case aopoa
    case banu
    case esperia
    case gatac
    case vanduul

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rsi: "Roberts Space Industries"
        case .drake: "Drake Interplanetary"
        case .aegis: "Aegis Dynamics"
        case .anvil: "Anvil Aerospace"
        case .origin: "Origin Jumpworks"
        case .argo: "Argo Astronautics"
        case .crusader: "Crusader Industries"
        case .misc: "Musashi Industrial and Starflight Concern"
        case .mirai: "Mirai"
        case .consolidatedOutland: "Consolidated Outland"
        case .greycat: "Greycat Industrial"
        case .tumbril: "Tumbril Land Systems"
        case .kruger: "Kruger Intergalactic"
        case .aopoa: "Aopoa"
        case .banu: "Banu"
        case .esperia: "Esperia"
        case .gatac: "Gatac Manufacture"
        case .vanduul: "Vanduul"
        }
    }

    var shortName: String {
        switch self {
        case .rsi: "RSI"
        case .drake: "DRAKE"
        case .aegis: "AEGIS"
        case .anvil: "ANVIL"
        case .origin: "ORIGIN"
        case .argo: "ARGO"
        case .crusader: "CRUSADER"
        case .misc: "MISC"
        case .mirai: "MIRAI"
        case .consolidatedOutland: "C. OUTLAND"
        case .greycat: "GREYCAT"
        case .tumbril: "TUMBRIL"
        case .kruger: "KRUGER"
        case .aopoa: "AOPOA"
        case .banu: "BANU"
        case .esperia: "ESPERIA"
        case .gatac: "GATAC"
        case .vanduul: "VANDUUL"
        }
    }

    /// The server's `manufacturerPrefix` (41.9): the log prefix without the underscore, e.g. `"DRAK"`.
    /// Exact match only; anything else, including `"DRAK_"`, is unknown.
    init?(logPrefix: String) {
        guard let match = Self.allCases.first(where: { $0.logEntityPrefix.dropLast() == logPrefix }) else {
            return nil
        }
        self = match
    }

    /// Ship entity prefix as it appears in Game.log (e.g. `AEGS_Gladius`).
    var logEntityPrefix: String {
        switch self {
        case .rsi: "RSI_"
        case .drake: "DRAK_"
        case .aegis: "AEGS_"
        case .anvil: "ANVL_"
        case .origin: "ORIG_"
        case .argo: "ARGO_"
        case .crusader: "CRUS_"
        case .misc: "MISC_"
        case .mirai: "MRAI_"
        case .consolidatedOutland: "CNOU_"
        case .greycat: "GRIN_"
        case .tumbril: "TMBL_"
        case .kruger: "KRIG_"
        case .aopoa: "XIAN_"
        case .banu: "BANU_"
        case .esperia: "ESPR_"
        case .gatac: "GAMA_"
        case .vanduul: "VNCL_"
        }
    }

    var theme: ManufacturerTheme {
        switch self {
        case .rsi: .rsi
        case .drake: .drake
        case .aegis: .aegis
        case .anvil: .anvil
        case .origin: .origin
        case .argo: .argo
        case .crusader: .crusader
        case .misc: .misc
        case .mirai: .mirai
        case .consolidatedOutland: .consolidatedOutland
        case .greycat: .greycat
        case .tumbril: .tumbril
        case .kruger: .kruger
        case .aopoa: .aopoa
        case .banu: .banu
        case .esperia: .esperia
        case .gatac: .gatac
        case .vanduul: .vanduul
        }
    }
}

// MARK: - App theme choice

/// The theme the user picked: the neutral SCMFD theme or a manufacturer's.
/// Stored as a string under the old `manufacturer` key: `"standard"` or a manufacturer raw value, so a saved
/// `"rsi"` keeps meaning RSI.
nonisolated enum AppTheme: Hashable, Identifiable, Sendable, RawRepresentable {
    case standard
    case manufacturer(Manufacturer)

    /// `@AppStorage` key of the Auto theme setting (on by default): ship-context transitions pick the theme.
    static let autoThemeKey = "autoTheme"

    /// The theme after a ship-context transition: the requested one with Auto theme on, otherwise unchanged.
    static func after(_ change: ThemeChange, current: AppTheme, autoTheme: Bool) -> AppTheme {
        autoTheme ? change.theme : current
    }

    /// Picker order: SCMFD first, then every manufacturer.
    static let all: [AppTheme] = [.standard] + Manufacturer.allCases.map(AppTheme.manufacturer)

    init?(rawValue: String) {
        if rawValue == "standard" {
            self = .standard
        } else if let manufacturer = Manufacturer(rawValue: rawValue) {
            self = .manufacturer(manufacturer)
        } else {
            return nil
        }
    }

    var rawValue: String {
        switch self {
        case .standard: "standard"
        case .manufacturer(let manufacturer): manufacturer.rawValue
        }
    }

    var id: String { rawValue }

    var theme: ManufacturerTheme {
        switch self {
        case .standard: .standard
        case .manufacturer(let manufacturer): manufacturer.theme
        }
    }
}

// MARK: - Theme tokens

nonisolated struct ManufacturerTheme: Sendable {
    struct Palette: Sendable {
        let background: Color
        let panel: Color
        let panelHighlight: Color
        let line: Color
        let lineHighlight: Color
        let text: Color
        let dim: Color
        let accent: Color
        let green: Color
        let amber: Color
        let red: Color
        let blue: Color
    }

    struct Typography: Sendable {
        let display: ThemeFont
        let body: ThemeFont
        let labelUppercased: Bool
        /// Letter spacing in em, same unit as the CSS reference.
        let labelTrackingEm: CGFloat
        let labelWeight: Font.Weight
    }

    struct Key: Sendable {
        let corners: KeyCorners
        let fillTop: Color
        let fillBottom: Color
        /// Gradient direction in CSS degrees (0 = to top, 90 = to right, 180 = to bottom).
        let fillAngle: Double
        /// Width of the solid accent edge on the leading side; 0 disables it.
        let edgeWidth: CGFloat
        let topAccent: KeyTopAccent
        let shadow: KeyShadow?
    }

    struct Icons: Sendable {
        let weight: Font.Weight
        /// Glow radius in points; 0 disables the glow.
        let glowRadius: CGFloat
    }

    /// nil for the neutral SCMFD theme, which is not a manufacturer (DEFAULT-THEME-DESIGN.md).
    let manufacturer: Manufacturer?
    let colorScheme: ColorScheme
    let palette: Palette
    let typography: Typography
    let key: Key
    let icons: Icons
    let backdrop: ThemeBackdrop

    /// Brand shown in the top bar and the theme picker. The app name is not translated.
    var shortName: String { manufacturer?.shortName ?? "SCMFD" }
    var displayName: String { manufacturer?.displayName ?? "Star Citizen MFD" }

    /// Applies the letter case to text that is already final (names, localized strings). A literal goes through
    /// `label(_: LocalizedStringResource)` instead; an unlabeled `String` overload would win and skip localization.
    func label(verbatim text: String) -> String {
        typography.labelUppercased ? text.uppercased() : text
    }

    func labelTracking(for size: CGFloat) -> CGFloat {
        typography.labelTrackingEm * size
    }
}

// MARK: - Fonts

nonisolated struct ThemeFont: Sendable {
    /// Font family name as registered by the bundled font file.
    let family: String
    /// Used until the custom font is bundled, or if it fails to load.
    let fallbackDesign: Font.Design
    let fallbackWidth: Font.Width

    var isAvailable: Bool {
        Self.installedFamilies.contains(family)
    }

    /// CoreText works on every platform of the target (iOS, macOS, visionOS), unlike UIKit/AppKit.
    /// Cached once, right after the bundled fonts are registered.
    private static let installedFamilies: Set<String> = {
        _ = FontRegistry.registeredFontCount
        let families = CTFontManagerCopyAvailableFontFamilyNames() as? [String] ?? []
        return Set(families)
    }()

    func font(size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        if isAvailable {
            return .custom(family, size: size, relativeTo: style).weight(weight)
        }
        return .system(size: size, weight: weight, design: fallbackDesign).width(fallbackWidth)
    }
}

// MARK: - Key geometry and decoration

nonisolated enum KeyCorner: Sendable, Equatable {
    case square
    case cut(CGFloat)
    case round(CGFloat)
}

nonisolated struct KeyCorners: Sendable, Equatable {
    let topLeading: KeyCorner
    let topTrailing: KeyCorner
    let bottomTrailing: KeyCorner
    let bottomLeading: KeyCorner

    static func all(_ corner: KeyCorner) -> KeyCorners {
        KeyCorners(topLeading: corner, topTrailing: corner, bottomTrailing: corner, bottomLeading: corner)
    }
}

nonisolated struct KeyTopAccent: Sendable {
    enum Style: Sendable {
        case none
        /// Accent fading to clear at `end` (0...1 of the key width).
        case fade(end: CGFloat)
        /// Accent fading to a weaker accent across the full width.
        case solidFade(endOpacity: Double)
        /// Solid accent segment of fixed length followed by a faint track.
        case segment(length: CGFloat, trackOpacity: Double)
        /// Diagonal accent/dark stripes, Drake "hazard tape".
        case hazard(stripeWidth: CGFloat, dark: Color)
        /// Accent peaking in the middle and fading to both sides.
        case centerFade
    }

    let style: Style
    let height: CGFloat

    static let none = KeyTopAccent(style: .none, height: 0)
}

nonisolated struct KeyShadow: Sendable {
    let color: Color
    let radius: CGFloat
    let y: CGFloat
}

// MARK: - Backdrop

nonisolated struct ThemeBackdrop: Sendable {
    enum Pattern: Sendable {
        case none
        case stars
        case grid(spacing: CGFloat)
        case scanlines
        case diagonalHatch(spacing: CGFloat)
    }

    let glowColor: Color
    /// Glow center; values outside 0...1 put it beyond the edge, like the CSS reference.
    let glowCenter: UnitPoint
    /// Glow ellipse radii as fractions of the view size, CSS `ellipse <w>% <h>%`.
    let glowRadii: CGSize
    let pattern: Pattern
    /// Optional bottom tone for a vertical base gradient (light themes).
    let baseBottom: Color?
}

// MARK: - Presets

nonisolated extension ManufacturerTheme {
    static let rsi = ManufacturerTheme(
        manufacturer: .rsi,
        colorScheme: .dark,
        palette: Palette(
            background: Color(hex: 0x05090F),
            panel: Color(hex: 0x0B1420),
            panelHighlight: Color(hex: 0x122236),
            line: Color(hex: 0x1C2C40),
            lineHighlight: Color(hex: 0x35598A),
            text: Color(hex: 0xE8F2FC),
            dim: Color(hex: 0x7F95AD),
            accent: Color(hex: 0x4FB3FF),
            green: Color(hex: 0x46D79A),
            amber: Color(hex: 0xFFBE55),
            red: Color(hex: 0xFF5F6D),
            blue: Color(hex: 0x4FB3FF)
        ),
        typography: Typography(
            display: ThemeFont(family: "Exo 2", fallbackDesign: .default, fallbackWidth: .standard),
            body: ThemeFont(family: "Exo 2", fallbackDesign: .default, fallbackWidth: .standard),
            labelUppercased: true,
            labelTrackingEm: 0.06,
            labelWeight: .semibold
        ),
        key: Key(
            corners: .all(.round(6)),
            fillTop: Color(hex: 0x0F1C2C),
            fillBottom: Color(hex: 0x08111B),
            fillAngle: 160,
            edgeWidth: 1.5,
            topAccent: KeyTopAccent(style: .fade(end: 0.75), height: 1.5),
            shadow: nil
        ),
        icons: Icons(weight: .light, glowRadius: 6),
        backdrop: ThemeBackdrop(
            glowColor: Color(red: 64 / 255, green: 150 / 255, blue: 1).opacity(0.22),
            glowCenter: UnitPoint(x: 0.75, y: -0.1),
            glowRadii: CGSize(width: 0.9, height: 0.6),
            pattern: .stars,
            baseBottom: nil
        )
    )

    /// Neutral app theme outside a ship: the RSI look under the SCMFD name.
    static let standard = ManufacturerTheme(
        manufacturer: nil,
        colorScheme: rsi.colorScheme,
        palette: rsi.palette,
        typography: rsi.typography,
        key: rsi.key,
        icons: rsi.icons,
        backdrop: rsi.backdrop
    )

    static let drake = ManufacturerTheme(
        manufacturer: .drake,
        colorScheme: .dark,
        palette: Palette(
            background: Color(hex: 0x0B0A08),
            panel: Color(hex: 0x16140F),
            panelHighlight: Color(hex: 0x221E14),
            line: Color(hex: 0x2D281C),
            lineHighlight: Color(hex: 0x6B5820),
            text: Color(hex: 0xF1E8D0),
            dim: Color(hex: 0x9C9176),
            accent: Color(hex: 0xF2C230),
            green: Color(hex: 0xA6D13C),
            amber: Color(hex: 0xF2C230),
            red: Color(hex: 0xEC5A2E),
            blue: Color(hex: 0xD4B77A)
        ),
        typography: Typography(
            display: ThemeFont(family: "Saira Stencil One", fallbackDesign: .default, fallbackWidth: .compressed),
            body: ThemeFont(family: "Saira Condensed", fallbackDesign: .default, fallbackWidth: .condensed),
            labelUppercased: true,
            labelTrackingEm: 0.07,
            labelWeight: .bold
        ),
        key: Key(
            corners: KeyCorners(
                topLeading: .square,
                topTrailing: .square,
                bottomTrailing: .cut(20),
                bottomLeading: .square
            ),
            fillTop: Color(hex: 0x1C1912),
            fillBottom: Color(hex: 0x100E0A),
            fillAngle: 180,
            edgeWidth: 0,
            topAccent: KeyTopAccent(style: .hazard(stripeWidth: 5, dark: Color(hex: 0x0D0C09)), height: 4),
            shadow: nil
        ),
        icons: Icons(weight: .regular, glowRadius: 0),
        backdrop: ThemeBackdrop(
            glowColor: Color(red: 242 / 255, green: 194 / 255, blue: 48 / 255).opacity(0.13),
            glowCenter: UnitPoint(x: 0.15, y: -0.05),
            glowRadii: CGSize(width: 0.7, height: 0.5),
            pattern: .scanlines,
            baseBottom: nil
        )
    )

    static let aegis = ManufacturerTheme(
        manufacturer: .aegis,
        colorScheme: .dark,
        palette: Palette(
            background: Color(hex: 0x06080B),
            panel: Color(hex: 0x0E1217),
            panelHighlight: Color(hex: 0x161C24),
            line: Color(hex: 0x232B35),
            lineHighlight: Color(hex: 0x525E6D),
            text: Color(hex: 0xF3F5F8),
            dim: Color(hex: 0x8691A1),
            accent: Color(hex: 0xFF3B3B),
            green: Color(hex: 0x5FD18A),
            amber: Color(hex: 0xFFB648),
            red: Color(hex: 0xFF3B3B),
            blue: Color(hex: 0x8FB6DC)
        ),
        typography: Typography(
            display: ThemeFont(family: "Rajdhani", fallbackDesign: .default, fallbackWidth: .condensed),
            body: ThemeFont(family: "Rajdhani", fallbackDesign: .default, fallbackWidth: .condensed),
            labelUppercased: true,
            labelTrackingEm: 0.12,
            labelWeight: .bold
        ),
        key: Key(
            corners: KeyCorners(
                topLeading: .cut(16),
                topTrailing: .square,
                bottomTrailing: .cut(16),
                bottomLeading: .square
            ),
            fillTop: Color(hex: 0x151B22),
            fillBottom: Color(hex: 0x0A0D11),
            fillAngle: 135,
            edgeWidth: 0,
            topAccent: KeyTopAccent(style: .segment(length: 40, trackOpacity: 0.1), height: 2),
            shadow: nil
        ),
        icons: Icons(weight: .light, glowRadius: 5),
        backdrop: ThemeBackdrop(
            glowColor: Color(red: 1, green: 59 / 255, blue: 59 / 255).opacity(0.12),
            glowCenter: UnitPoint(x: 0.85, y: 0),
            glowRadii: CGSize(width: 0.6, height: 0.45),
            pattern: .grid(spacing: 44),
            baseBottom: nil
        )
    )

    static let anvil = ManufacturerTheme(
        manufacturer: .anvil,
        colorScheme: .dark,
        palette: Palette(
            background: Color(hex: 0x0A0C08),
            panel: Color(hex: 0x141811),
            panelHighlight: Color(hex: 0x1D2317),
            line: Color(hex: 0x2A3120),
            lineHighlight: Color(hex: 0x5C6B3B),
            text: Color(hex: 0xE5E2CA),
            dim: Color(hex: 0x969279),
            accent: Color(hex: 0xB5CC4A),
            green: Color(hex: 0xB5CC4A),
            amber: Color(hex: 0xE6A93A),
            red: Color(hex: 0xDC573C),
            blue: Color(hex: 0x8FB09E)
        ),
        typography: Typography(
            display: ThemeFont(family: "Black Ops One", fallbackDesign: .default, fallbackWidth: .expanded),
            body: ThemeFont(family: "Chakra Petch", fallbackDesign: .default, fallbackWidth: .standard),
            labelUppercased: true,
            labelTrackingEm: 0.08,
            labelWeight: .semibold
        ),
        key: Key(
            corners: KeyCorners(
                topLeading: .square,
                topTrailing: .cut(16),
                bottomTrailing: .square,
                bottomLeading: .cut(16)
            ),
            fillTop: Color(hex: 0x1A1F15),
            fillBottom: Color(hex: 0x0F120C),
            fillAngle: 180,
            edgeWidth: 0,
            topAccent: KeyTopAccent(style: .solidFade(endOpacity: 0.15), height: 2),
            shadow: nil
        ),
        icons: Icons(weight: .regular, glowRadius: 0),
        backdrop: ThemeBackdrop(
            glowColor: Color(red: 181 / 255, green: 204 / 255, blue: 74 / 255).opacity(0.12),
            glowCenter: UnitPoint(x: 0.5, y: -0.1),
            glowRadii: CGSize(width: 0.7, height: 0.5),
            pattern: .diagonalHatch(spacing: 22),
            baseBottom: nil
        )
    )

    static let origin = ManufacturerTheme(
        manufacturer: .origin,
        colorScheme: .light,
        palette: Palette(
            background: Color(hex: 0xE7EAEE),
            panel: Color(hex: 0xFFFFFF),
            panelHighlight: Color(hex: 0xF7F2E8),
            line: Color(hex: 0xD6DAE0),
            lineHighlight: Color(hex: 0xC7AD7E),
            text: Color(hex: 0x1C222A),
            dim: Color(hex: 0x79818C),
            accent: Color(hex: 0xB08D57),
            green: Color(hex: 0x3D9A73),
            amber: Color(hex: 0xC38A2B),
            red: Color(hex: 0xC4463E),
            blue: Color(hex: 0x4B7EA8)
        ),
        typography: Typography(
            display: ThemeFont(family: "Montserrat", fallbackDesign: .default, fallbackWidth: .standard),
            body: ThemeFont(family: "Montserrat", fallbackDesign: .default, fallbackWidth: .standard),
            labelUppercased: true,
            labelTrackingEm: 0.09,
            labelWeight: .semibold
        ),
        key: Key(
            corners: .all(.round(18)),
            fillTop: Color(hex: 0xFFFFFF),
            fillBottom: Color(hex: 0xF3F4F6),
            fillAngle: 180,
            edgeWidth: 0,
            topAccent: KeyTopAccent(style: .centerFade, height: 1.5),
            shadow: KeyShadow(
                color: Color(red: 30 / 255, green: 40 / 255, blue: 60 / 255).opacity(0.08),
                radius: 22,
                y: 8
            )
        ),
        icons: Icons(weight: .light, glowRadius: 0),
        backdrop: ThemeBackdrop(
            glowColor: .white,
            glowCenter: UnitPoint(x: 0.5, y: -0.2),
            glowRadii: CGSize(width: 0.8, height: 0.6),
            pattern: .none,
            baseBottom: Color(hex: 0xDDE1E6)
        )
    )
}

// MARK: - Environment

nonisolated private struct ManufacturerThemeKey: EnvironmentKey {
    static let defaultValue: ManufacturerTheme = .standard
}

extension EnvironmentValues {
    var manufacturerTheme: ManufacturerTheme {
        get { self[ManufacturerThemeKey.self] }
        set { self[ManufacturerThemeKey.self] = newValue }
    }
}

extension View {
    /// Applies a manufacturer theme to the subtree, including its light/dark scheme.
    func manufacturerTheme(_ theme: ManufacturerTheme) -> some View {
        environment(\.manufacturerTheme, theme)
            .environment(\.colorScheme, theme.colorScheme)
    }
}

// MARK: - Hex colors

nonisolated extension Color {
    /// Creates an sRGB color from a 0xRRGGBB literal.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
