import Foundation
import Testing
@testable import SCMFD

/// The neutral SCMFD theme and the stored theme choice.
struct AppThemeTests {
    @Test func savedManufacturerFromOlderVersionsStillDecodes() {
        #expect(AppTheme(rawValue: "rsi") == .manufacturer(.rsi))
        #expect(AppTheme(rawValue: "drake") == .manufacturer(.drake))
    }

    @Test(arguments: AppTheme.all)
    func everyChoiceSurvivesStorage(theme: AppTheme) {
        #expect(AppTheme(rawValue: theme.rawValue) == theme)
    }

    @Test func unknownStoredValueIsRejected() {
        #expect(AppTheme(rawValue: "foo") == nil)
    }

    @Test func pickerListsSCMFDFirstThenEveryManufacturer() {
        #expect(AppTheme.all.first == .standard)
        #expect(AppTheme.all.count == Manufacturer.allCases.count + 1)
    }

    @Test func standardThemeLooksLikeRSIUnderTheAppName() {
        let standard = AppTheme.standard.theme
        let rsi = Manufacturer.rsi.theme
        #expect(standard.manufacturer == nil)
        #expect(standard.shortName == "SCMFD")
        #expect(standard.displayName == "Star Citizen MFD")
        #expect(standard.palette.accent == rsi.palette.accent)
        #expect(standard.palette.background == rsi.palette.background)
        #expect(standard.typography.display.family == rsi.typography.display.family)
    }

    // MARK: - FIX-04: auto theme

    @Test(arguments: Manufacturer.allCases)
    func everyServerPrefixMapsToItsManufacturer(manufacturer: Manufacturer) {
        let prefix = String(manufacturer.logEntityPrefix.dropLast())
        #expect(Manufacturer(logPrefix: prefix) == manufacturer)
    }

    @Test func prefixesThatDoNotMatchTheLogNamesFollowTheSpecTable() {
        #expect(Manufacturer(logPrefix: "XIAN") == .aopoa)
        #expect(Manufacturer(logPrefix: "GAMA") == .gatac)
        #expect(Manufacturer(logPrefix: "GRIN") == .greycat)
    }

    @Test(arguments: ["FOO", "DRAK_", "drak", ""])
    func unknownPrefixIsRejected(prefix: String) {
        #expect(Manufacturer(logPrefix: prefix) == nil)
    }

    @Test func joinSwitchesTheThemeOnlyWithAutoThemeOn() {
        let join = ThemeChange(theme: .manufacturer(.aegis), sessionId: UUID(), revision: 3)
        #expect(AppTheme.after(join, current: .standard, autoTheme: true) == .manufacturer(.aegis))
        #expect(AppTheme.after(join, current: .standard, autoTheme: false) == .standard)
    }

    @Test func leaveRestoresTheStandardThemeOnlyWithAutoThemeOn() {
        let leave = ThemeChange(theme: .standard, sessionId: UUID(), revision: 4)
        #expect(AppTheme.after(leave, current: .manufacturer(.drake), autoTheme: true) == .standard)
        #expect(AppTheme.after(leave, current: .manufacturer(.drake), autoTheme: false) == .manufacturer(.drake))
    }

    @Test func manufacturerThemesKeepTheirNames() {
        let drake = AppTheme.manufacturer(.drake).theme
        #expect(drake.shortName == "DRAKE")
        #expect(drake.displayName == "Drake Interplanetary")
    }
}
