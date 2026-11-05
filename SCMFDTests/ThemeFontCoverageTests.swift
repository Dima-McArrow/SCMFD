import SwiftUI
import Testing
@testable import SCMFD

/// Cyrillic fallback: a theme family without every letter of a string hands the whole string to Exo 2.
struct ThemeFontCoverageTests {
    nonisolated static let latin = "Landing gear"
    /// Includes Ё and ё, which sit outside А–я.
    nonisolated static let cyrillic = "Шасси Ёё"

    /// Every bundled family, and whether its cmap has Cyrillic (parsed from the .ttf files).
    nonisolated static let bundledFamilies: [(String, Bool)] = [
        ("Black Ops One", false),
        ("Chakra Petch", false),
        ("Exo 2", true),
        ("Montserrat", true),
        ("Rajdhani", false),
        ("Saira Condensed", false),
        ("Saira Stencil One", false),
    ]

    private func font(_ family: String) -> ThemeFont {
        ThemeFont(family: family, fallbackDesign: .default, fallbackWidth: .standard)
    }

    @Test(arguments: bundledFamilies)
    func coverageMatchesTheFontFile(family: String, hasCyrillic: Bool) {
        #expect(font(family).isAvailable)
        #expect(font(family).covers(Self.latin))
        #expect(font(family).covers(Self.cyrillic) == hasCyrillic)
    }

    @Test func chakraPetchFallsBackToExo2ForCyrillic() {
        #expect(font("Chakra Petch").resolvedFamily(for: Self.cyrillic) == "Exo 2")
    }

    @Test func exo2StaysExo2() {
        #expect(font("Exo 2").resolvedFamily(for: Self.cyrillic) == "Exo 2")
        #expect(font("Exo 2").resolvedFamily(for: Self.latin) == "Exo 2")
    }

    @Test func latinKeepsTheThemeFamily() {
        #expect(font("Chakra Petch").resolvedFamily(for: Self.latin) == "Chakra Petch")
    }

    /// Only letters count: Exo 2 lacks the arrow too, so a symbol must not move a Latin string.
    @Test func missingSymbolDoesNotSwitchTheFont() {
        #expect(font("Chakra Petch").resolvedFamily(for: "Game.log ↗") == "Chakra Petch")
    }

    /// CoreText substitutes another font for an unknown family; it must not answer for it.
    @Test func unknownFamilyCoversNothing() {
        #expect(!ThemeFont.family("No Such Family", covers: Self.latin))
    }

    /// Latin text looks exactly as before in every theme; Russian never lands on a family without Cyrillic.
    @Test(arguments: Manufacturer.allCases)
    func everyThemeKeepsLatinAndDrawsRussianInOneFont(manufacturer: Manufacturer) {
        for themeFont in [manufacturer.theme.typography.display, manufacturer.theme.typography.body] {
            #expect(themeFont.resolvedFamily(for: Self.latin) == themeFont.family)
            let russian = themeFont.resolvedFamily(for: Self.cyrillic)
            #expect(russian == themeFont.family || russian == ThemeFont.fallbackFamily)
            #expect(russian.map { ThemeFont.family($0, covers: Self.cyrillic) } == true)
        }
    }
}
