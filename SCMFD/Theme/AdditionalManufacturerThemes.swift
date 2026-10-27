import SwiftUI

// Custom manufacturer-inspired skins using the deck's shared design tokens and bundled fonts.
nonisolated extension ManufacturerTheme {
    static let argo = ManufacturerTheme(
        manufacturer: .argo,
        colorScheme: .dark,
        palette: Palette(
            background: Color(hex: 0x0B1118),
            panel: Color(hex: 0x25313B),
            panelHighlight: Color(hex: 0x344552),
            line: Color(hex: 0x455560),
            lineHighlight: Color(hex: 0xFF861F).opacity(0.6),
            text: Color(hex: 0xF0F3F5),
            dim: Color(hex: 0xA5AFBA),
            accent: Color(hex: 0xFF861F),
            green: Color(hex: 0x75DEA2),
            amber: Color(hex: 0xFFD079),
            red: Color(hex: 0xFF7979),
            blue: Color(hex: 0x7FC5FF)
        ),
        typography: Typography(
            display: ThemeFont(family: "Chakra Petch", fallbackDesign: .default, fallbackWidth: .standard),
            body: ThemeFont(family: "Chakra Petch", fallbackDesign: .default, fallbackWidth: .standard),
            labelUppercased: true,
            labelTrackingEm: 0.02,
            labelWeight: .bold
        ),
        key: Key(
            corners: .all(.round(3)),
            fillTop: Color(hex: 0x25313B),
            fillBottom: Color(hex: 0x0B1118),
            fillAngle: 180,
            edgeWidth: 5,
            topAccent: .none,
            shadow: nil
        ),
        icons: Icons(weight: .bold, glowRadius: 0),
        backdrop: ThemeBackdrop(
            glowColor: Color(hex: 0x7FC5FF).opacity(0.10),
            glowCenter: UnitPoint(x: 0.75, y: -0.1),
            glowRadii: CGSize(width: 0.8, height: 0.6),
            pattern: .grid(spacing: 32),
            baseBottom: nil
        )
    )

    static let crusader = ManufacturerTheme(
        manufacturer: .crusader,
        colorScheme: .dark,
        palette: Palette(
            background: Color(hex: 0x090F1C),
            panel: Color(hex: 0x172942),
            panelHighlight: Color(hex: 0x79BFFF).opacity(0.16),
            line: Color(hex: 0x79BFFF).opacity(0.22),
            lineHighlight: Color(hex: 0x79BFFF).opacity(0.6),
            text: Color(hex: 0xF0F3F5),
            dim: Color(hex: 0xA5AFBA),
            accent: Color(hex: 0x79BFFF),
            green: Color(hex: 0x75DEA2),
            amber: Color(hex: 0xFFD079),
            red: Color(hex: 0xFF7979),
            blue: Color(hex: 0x7FC5FF)
        ),
        typography: Typography(
            display: ThemeFont(family: "Montserrat", fallbackDesign: .default, fallbackWidth: .standard),
            body: ThemeFont(family: "Exo 2", fallbackDesign: .default, fallbackWidth: .standard),
            labelUppercased: true,
            labelTrackingEm: 0.07,
            labelWeight: .semibold
        ),
        key: Key(
            corners: .all(.round(12)),
            fillTop: Color(hex: 0x172942),
            fillBottom: Color(hex: 0x090F1C),
            fillAngle: 160,
            edgeWidth: 2,
            topAccent: KeyTopAccent(style: .centerFade, height: 2),
            shadow: nil
        ),
        icons: Icons(weight: .light, glowRadius: 5),
        backdrop: ThemeBackdrop(
            glowColor: Color(hex: 0x79BFFF).opacity(0.16),
            glowCenter: UnitPoint(x: 0.75, y: -0.1),
            glowRadii: CGSize(width: 0.8, height: 0.6),
            pattern: .stars,
            baseBottom: nil
        )
    )

    static let misc = ManufacturerTheme(
        manufacturer: .misc,
        colorScheme: .dark,
        palette: Palette(
            background: Color(hex: 0x07110F),
            panel: Color(hex: 0x132B29),
            panelHighlight: Color(hex: 0x58DDD1).opacity(0.16),
            line: Color(hex: 0x58DDD1).opacity(0.22),
            lineHighlight: Color(hex: 0x58DDD1).opacity(0.6),
            text: Color(hex: 0xF0F3F5),
            dim: Color(hex: 0xA5AFBA),
            accent: Color(hex: 0x58DDD1),
            green: Color(hex: 0x75DEA2),
            amber: Color(hex: 0xFFD079),
            red: Color(hex: 0xFF7979),
            blue: Color(hex: 0x7FC5FF)
        ),
        typography: Typography(
            display: ThemeFont(family: "Chakra Petch", fallbackDesign: .default, fallbackWidth: .standard),
            body: ThemeFont(family: "Chakra Petch", fallbackDesign: .default, fallbackWidth: .standard),
            labelUppercased: true,
            labelTrackingEm: 0.07,
            labelWeight: .semibold
        ),
        key: Key(
            corners: .all(.round(4)),
            fillTop: Color(hex: 0x132B29),
            fillBottom: Color(hex: 0x07110F),
            fillAngle: 160,
            edgeWidth: 2,
            topAccent: KeyTopAccent(style: .segment(length: 56, trackOpacity: 0.2), height: 2),
            shadow: nil
        ),
        icons: Icons(weight: .light, glowRadius: 5),
        backdrop: ThemeBackdrop(
            glowColor: Color(hex: 0x58DDD1).opacity(0.16),
            glowCenter: UnitPoint(x: 0.75, y: -0.1),
            glowRadii: CGSize(width: 0.8, height: 0.6),
            pattern: .grid(spacing: 36),
            baseBottom: nil
        )
    )

    static let mirai = ManufacturerTheme(
        manufacturer: .mirai,
        colorScheme: .dark,
        palette: Palette(
            background: Color(hex: 0x120A12),
            panel: Color(hex: 0x2D1525),
            panelHighlight: Color(hex: 0xFF647C).opacity(0.16),
            line: Color(hex: 0xFF647C).opacity(0.22),
            lineHighlight: Color(hex: 0xFF647C).opacity(0.6),
            text: Color(hex: 0xF0F3F5),
            dim: Color(hex: 0xA5AFBA),
            accent: Color(hex: 0xFF647C),
            green: Color(hex: 0x75DEA2),
            amber: Color(hex: 0xFFD079),
            red: Color(hex: 0xFF7979),
            blue: Color(hex: 0x7FC5FF)
        ),
        typography: Typography(
            display: ThemeFont(family: "Rajdhani", fallbackDesign: .default, fallbackWidth: .standard),
            body: ThemeFont(family: "Rajdhani", fallbackDesign: .default, fallbackWidth: .standard),
            labelUppercased: true,
            labelTrackingEm: 0.14,
            labelWeight: .semibold
        ),
        key: Key(
            corners: .all(.cut(14)),
            fillTop: Color(hex: 0x2D1525),
            fillBottom: Color(hex: 0x120A12),
            fillAngle: 160,
            edgeWidth: 0,
            topAccent: KeyTopAccent(style: .fade(end: 0.9), height: 2),
            shadow: nil
        ),
        icons: Icons(weight: .light, glowRadius: 5),
        backdrop: ThemeBackdrop(
            glowColor: Color(hex: 0xFF647C).opacity(0.16),
            glowCenter: UnitPoint(x: 0.75, y: -0.1),
            glowRadii: CGSize(width: 0.8, height: 0.6),
            pattern: .scanlines,
            baseBottom: nil
        )
    )

    static let consolidatedOutland = ManufacturerTheme(
        manufacturer: .consolidatedOutland,
        colorScheme: .dark,
        palette: Palette(
            background: Color(hex: 0x100D1B),
            panel: Color(hex: 0x261E38),
            panelHighlight: Color(hex: 0xD8BEFF).opacity(0.16),
            line: Color(hex: 0xD8BEFF).opacity(0.22),
            lineHighlight: Color(hex: 0xD8BEFF).opacity(0.6),
            text: Color(hex: 0xF0F3F5),
            dim: Color(hex: 0xA5AFBA),
            accent: Color(hex: 0xD8BEFF),
            green: Color(hex: 0x75DEA2),
            amber: Color(hex: 0xFFD079),
            red: Color(hex: 0xFF7979),
            blue: Color(hex: 0x7FC5FF)
        ),
        typography: Typography(
            display: ThemeFont(family: "Exo 2", fallbackDesign: .default, fallbackWidth: .standard),
            body: ThemeFont(family: "Montserrat", fallbackDesign: .default, fallbackWidth: .standard),
            labelUppercased: true,
            labelTrackingEm: 0.07,
            labelWeight: .semibold
        ),
        key: Key(
            corners: .all(.cut(10)),
            fillTop: Color(hex: 0x261E38),
            fillBottom: Color(hex: 0x100D1B),
            fillAngle: 160,
            edgeWidth: 0,
            topAccent: KeyTopAccent(style: .solidFade(endOpacity: 0.2), height: 2),
            shadow: nil
        ),
        icons: Icons(weight: .light, glowRadius: 5),
        backdrop: ThemeBackdrop(
            glowColor: Color(hex: 0xD8BEFF).opacity(0.16),
            glowCenter: UnitPoint(x: 0.75, y: -0.1),
            glowRadii: CGSize(width: 0.8, height: 0.6),
            pattern: .grid(spacing: 52),
            baseBottom: nil
        )
    )

    static let greycat = ManufacturerTheme(
        manufacturer: .greycat,
        colorScheme: .dark,
        palette: Palette(
            background: Color(hex: 0x10110D),
            panel: Color(hex: 0x27291E),
            panelHighlight: Color(hex: 0xF4D35E).opacity(0.16),
            line: Color(hex: 0xF4D35E).opacity(0.22),
            lineHighlight: Color(hex: 0xF4D35E).opacity(0.6),
            text: Color(hex: 0xF0F3F5),
            dim: Color(hex: 0xA5AFBA),
            accent: Color(hex: 0xF4D35E),
            green: Color(hex: 0x75DEA2),
            amber: Color(hex: 0xFFD079),
            red: Color(hex: 0xFF7979),
            blue: Color(hex: 0x7FC5FF)
        ),
        typography: Typography(
            display: ThemeFont(family: "Chakra Petch", fallbackDesign: .default, fallbackWidth: .standard),
            body: ThemeFont(family: "Saira Condensed", fallbackDesign: .default, fallbackWidth: .standard),
            labelUppercased: true,
            labelTrackingEm: 0.07,
            labelWeight: .semibold
        ),
        key: Key(
            corners: .all(.square),
            fillTop: Color(hex: 0x27291E),
            fillBottom: Color(hex: 0x10110D),
            fillAngle: 160,
            edgeWidth: 0,
            topAccent: KeyTopAccent(style: .segment(length: 28, trackOpacity: 0.25), height: 2),
            shadow: nil
        ),
        icons: Icons(weight: .regular, glowRadius: 0),
        backdrop: ThemeBackdrop(
            glowColor: Color(hex: 0xF4D35E).opacity(0.16),
            glowCenter: UnitPoint(x: 0.75, y: -0.1),
            glowRadii: CGSize(width: 0.8, height: 0.6),
            pattern: .grid(spacing: 28),
            baseBottom: nil
        )
    )

    static let tumbril = ManufacturerTheme(
        manufacturer: .tumbril,
        colorScheme: .dark,
        palette: Palette(
            background: Color(hex: 0x12100B),
            panel: Color(hex: 0x2A261C),
            panelHighlight: Color(hex: 0xDDB582).opacity(0.16),
            line: Color(hex: 0xDDB582).opacity(0.22),
            lineHighlight: Color(hex: 0xDDB582).opacity(0.6),
            text: Color(hex: 0xF0F3F5),
            dim: Color(hex: 0xA5AFBA),
            accent: Color(hex: 0xDDB582),
            green: Color(hex: 0x75DEA2),
            amber: Color(hex: 0xFFD079),
            red: Color(hex: 0xFF7979),
            blue: Color(hex: 0x7FC5FF)
        ),
        typography: Typography(
            display: ThemeFont(family: "Black Ops One", fallbackDesign: .default, fallbackWidth: .standard),
            body: ThemeFont(family: "Chakra Petch", fallbackDesign: .default, fallbackWidth: .standard),
            labelUppercased: true,
            labelTrackingEm: 0.07,
            labelWeight: .semibold
        ),
        key: Key(
            corners: .all(.cut(6)),
            fillTop: Color(hex: 0x2A261C),
            fillBottom: Color(hex: 0x12100B),
            fillAngle: 160,
            edgeWidth: 0,
            topAccent: KeyTopAccent(style: .hazard(stripeWidth: 10, dark: Color(hex: 0x12100B)), height: 4),
            shadow: nil
        ),
        icons: Icons(weight: .regular, glowRadius: 0),
        backdrop: ThemeBackdrop(
            glowColor: Color(hex: 0xDDB582).opacity(0.16),
            glowCenter: UnitPoint(x: 0.75, y: -0.1),
            glowRadii: CGSize(width: 0.8, height: 0.6),
            pattern: .diagonalHatch(spacing: 18),
            baseBottom: nil
        )
    )

    static let kruger = ManufacturerTheme(
        manufacturer: .kruger,
        colorScheme: .dark,
        palette: Palette(
            background: Color(hex: 0x140B0A),
            panel: Color(hex: 0x301C19),
            panelHighlight: Color(hex: 0xFF846A).opacity(0.16),
            line: Color(hex: 0xFF846A).opacity(0.22),
            lineHighlight: Color(hex: 0xFF846A).opacity(0.6),
            text: Color(hex: 0xF0F3F5),
            dim: Color(hex: 0xA5AFBA),
            accent: Color(hex: 0xFF846A),
            green: Color(hex: 0x75DEA2),
            amber: Color(hex: 0xFFD079),
            red: Color(hex: 0xFF7979),
            blue: Color(hex: 0x7FC5FF)
        ),
        typography: Typography(
            display: ThemeFont(family: "Saira Stencil One", fallbackDesign: .default, fallbackWidth: .standard),
            body: ThemeFont(family: "Rajdhani", fallbackDesign: .default, fallbackWidth: .standard),
            labelUppercased: true,
            labelTrackingEm: 0.07,
            labelWeight: .semibold
        ),
        key: Key(
            corners: .all(.cut(18)),
            fillTop: Color(hex: 0x301C19),
            fillBottom: Color(hex: 0x140B0A),
            fillAngle: 160,
            edgeWidth: 0,
            topAccent: KeyTopAccent(style: .segment(length: 44, trackOpacity: 0.15), height: 2),
            shadow: nil
        ),
        icons: Icons(weight: .light, glowRadius: 5),
        backdrop: ThemeBackdrop(
            glowColor: Color(hex: 0xFF846A).opacity(0.16),
            glowCenter: UnitPoint(x: 0.75, y: -0.1),
            glowRadii: CGSize(width: 0.8, height: 0.6),
            pattern: .scanlines,
            baseBottom: nil
        )
    )

    static let aopoa = ManufacturerTheme(
        manufacturer: .aopoa,
        colorScheme: .dark,
        palette: Palette(
            background: Color(hex: 0x0B110B),
            panel: Color(hex: 0x1E3020),
            panelHighlight: Color(hex: 0xB6ED68).opacity(0.16),
            line: Color(hex: 0xB6ED68).opacity(0.22),
            lineHighlight: Color(hex: 0xB6ED68).opacity(0.6),
            text: Color(hex: 0xF0F3F5),
            dim: Color(hex: 0xA5AFBA),
            accent: Color(hex: 0xB6ED68),
            green: Color(hex: 0x75DEA2),
            amber: Color(hex: 0xFFD079),
            red: Color(hex: 0xFF7979),
            blue: Color(hex: 0x7FC5FF)
        ),
        typography: Typography(
            display: ThemeFont(family: "Exo 2", fallbackDesign: .default, fallbackWidth: .standard),
            body: ThemeFont(family: "Exo 2", fallbackDesign: .default, fallbackWidth: .standard),
            labelUppercased: true,
            labelTrackingEm: 0.07,
            labelWeight: .semibold
        ),
        key: Key(
            corners: .all(.round(22)),
            fillTop: Color(hex: 0x1E3020),
            fillBottom: Color(hex: 0x0B110B),
            fillAngle: 160,
            edgeWidth: 0,
            topAccent: KeyTopAccent(style: .centerFade, height: 2),
            shadow: nil
        ),
        icons: Icons(weight: .light, glowRadius: 5),
        backdrop: ThemeBackdrop(
            glowColor: Color(hex: 0xB6ED68).opacity(0.16),
            glowCenter: UnitPoint(x: 0.75, y: -0.1),
            glowRadii: CGSize(width: 0.8, height: 0.6),
            pattern: .stars,
            baseBottom: nil
        )
    )

    static let banu = ManufacturerTheme(
        manufacturer: .banu,
        colorScheme: .dark,
        palette: Palette(
            background: Color(hex: 0x130E09),
            panel: Color(hex: 0x302317),
            panelHighlight: Color(hex: 0xF1CC80).opacity(0.16),
            line: Color(hex: 0xF1CC80).opacity(0.22),
            lineHighlight: Color(hex: 0xF1CC80).opacity(0.6),
            text: Color(hex: 0xF0F3F5),
            dim: Color(hex: 0xA5AFBA),
            accent: Color(hex: 0xF1CC80),
            green: Color(hex: 0x75DEA2),
            amber: Color(hex: 0xFFD079),
            red: Color(hex: 0xFF7979),
            blue: Color(hex: 0x7FC5FF)
        ),
        typography: Typography(
            display: ThemeFont(family: "Saira Condensed", fallbackDesign: .default, fallbackWidth: .standard),
            body: ThemeFont(family: "Montserrat", fallbackDesign: .default, fallbackWidth: .standard),
            labelUppercased: true,
            labelTrackingEm: 0.07,
            labelWeight: .semibold
        ),
        key: Key(
            corners: .all(.round(16)),
            fillTop: Color(hex: 0x302317),
            fillBottom: Color(hex: 0x130E09),
            fillAngle: 160,
            edgeWidth: 0,
            topAccent: KeyTopAccent(style: .solidFade(endOpacity: 0.25), height: 2),
            shadow: nil
        ),
        icons: Icons(weight: .light, glowRadius: 5),
        backdrop: ThemeBackdrop(
            glowColor: Color(hex: 0xF1CC80).opacity(0.16),
            glowCenter: UnitPoint(x: 0.75, y: -0.1),
            glowRadii: CGSize(width: 0.8, height: 0.6),
            pattern: .diagonalHatch(spacing: 38),
            baseBottom: nil
        )
    )

    static let esperia = ManufacturerTheme(
        manufacturer: .esperia,
        colorScheme: .dark,
        palette: Palette(
            background: Color(hex: 0x0E0B18),
            panel: Color(hex: 0x231C35),
            panelHighlight: Color(hex: 0xB8A0FF).opacity(0.16),
            line: Color(hex: 0xB8A0FF).opacity(0.22),
            lineHighlight: Color(hex: 0xB8A0FF).opacity(0.6),
            text: Color(hex: 0xF0F3F5),
            dim: Color(hex: 0xA5AFBA),
            accent: Color(hex: 0xB8A0FF),
            green: Color(hex: 0x75DEA2),
            amber: Color(hex: 0xFFD079),
            red: Color(hex: 0xFF7979),
            blue: Color(hex: 0x7FC5FF)
        ),
        typography: Typography(
            display: ThemeFont(family: "Rajdhani", fallbackDesign: .default, fallbackWidth: .standard),
            body: ThemeFont(family: "Exo 2", fallbackDesign: .default, fallbackWidth: .standard),
            labelUppercased: true,
            labelTrackingEm: 0.07,
            labelWeight: .semibold
        ),
        key: Key(
            corners: .all(.cut(22)),
            fillTop: Color(hex: 0x231C35),
            fillBottom: Color(hex: 0x0E0B18),
            fillAngle: 160,
            edgeWidth: 0,
            topAccent: KeyTopAccent(style: .fade(end: 0.65), height: 2),
            shadow: nil
        ),
        icons: Icons(weight: .light, glowRadius: 5),
        backdrop: ThemeBackdrop(
            glowColor: Color(hex: 0xB8A0FF).opacity(0.16),
            glowCenter: UnitPoint(x: 0.75, y: -0.1),
            glowRadii: CGSize(width: 0.8, height: 0.6),
            pattern: .stars,
            baseBottom: nil
        )
    )

    static let gatac = ManufacturerTheme(
        manufacturer: .gatac,
        colorScheme: .dark,
        palette: Palette(
            background: Color(hex: 0x081216),
            panel: Color(hex: 0x143039),
            panelHighlight: Color(hex: 0x6DE6F2).opacity(0.16),
            line: Color(hex: 0x6DE6F2).opacity(0.22),
            lineHighlight: Color(hex: 0x6DE6F2).opacity(0.6),
            text: Color(hex: 0xF0F3F5),
            dim: Color(hex: 0xA5AFBA),
            accent: Color(hex: 0x6DE6F2),
            green: Color(hex: 0x75DEA2),
            amber: Color(hex: 0xFFD079),
            red: Color(hex: 0xFF7979),
            blue: Color(hex: 0x7FC5FF)
        ),
        typography: Typography(
            display: ThemeFont(family: "Chakra Petch", fallbackDesign: .default, fallbackWidth: .standard),
            body: ThemeFont(family: "Exo 2", fallbackDesign: .default, fallbackWidth: .standard),
            labelUppercased: true,
            labelTrackingEm: 0.07,
            labelWeight: .semibold
        ),
        key: Key(
            corners: .all(.cut(12)),
            fillTop: Color(hex: 0x143039),
            fillBottom: Color(hex: 0x081216),
            fillAngle: 160,
            edgeWidth: 2,
            topAccent: KeyTopAccent(style: .centerFade, height: 2),
            shadow: nil
        ),
        icons: Icons(weight: .light, glowRadius: 5),
        backdrop: ThemeBackdrop(
            glowColor: Color(hex: 0x6DE6F2).opacity(0.16),
            glowCenter: UnitPoint(x: 0.75, y: -0.1),
            glowRadii: CGSize(width: 0.8, height: 0.6),
            pattern: .grid(spacing: 60),
            baseBottom: nil
        )
    )

    static let vanduul = ManufacturerTheme(
        manufacturer: .vanduul,
        colorScheme: .dark,
        palette: Palette(
            background: Color(hex: 0x160808),
            panel: Color(hex: 0x341414),
            panelHighlight: Color(hex: 0xFF6858).opacity(0.16),
            line: Color(hex: 0xFF6858).opacity(0.22),
            lineHighlight: Color(hex: 0xFF6858).opacity(0.6),
            text: Color(hex: 0xF0F3F5),
            dim: Color(hex: 0xA5AFBA),
            accent: Color(hex: 0xFF6858),
            green: Color(hex: 0x75DEA2),
            amber: Color(hex: 0xFFD079),
            red: Color(hex: 0xFF7979),
            blue: Color(hex: 0x7FC5FF)
        ),
        typography: Typography(
            display: ThemeFont(family: "Black Ops One", fallbackDesign: .default, fallbackWidth: .standard),
            body: ThemeFont(family: "Rajdhani", fallbackDesign: .default, fallbackWidth: .standard),
            labelUppercased: true,
            labelTrackingEm: 0.07,
            labelWeight: .semibold
        ),
        key: Key(
            corners: .all(.cut(26)),
            fillTop: Color(hex: 0x341414),
            fillBottom: Color(hex: 0x160808),
            fillAngle: 160,
            edgeWidth: 0,
            topAccent: KeyTopAccent(style: .solidFade(endOpacity: 0.1), height: 2),
            shadow: nil
        ),
        icons: Icons(weight: .light, glowRadius: 5),
        backdrop: ThemeBackdrop(
            glowColor: Color(hex: 0xFF6858).opacity(0.16),
            glowCenter: UnitPoint(x: 0.75, y: -0.1),
            glowRadii: CGSize(width: 0.8, height: 0.6),
            pattern: .diagonalHatch(spacing: 32),
            baseBottom: nil
        )
    )
}
