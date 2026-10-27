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

    @Test func manufacturerThemesKeepTheirNames() {
        let drake = AppTheme.manufacturer(.drake).theme
        #expect(drake.shortName == "DRAKE")
        #expect(drake.displayName == "Drake Interplanetary")
    }
}
