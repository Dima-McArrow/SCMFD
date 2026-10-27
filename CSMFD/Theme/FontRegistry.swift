import CoreText
import Foundation

/// Registers the manufacturer fonts shipped in the app bundle.
///
/// Runtime registration instead of `UIAppFonts` because the target also builds for macOS
/// (which uses a different Info.plist key) and because Xcode previews never run `App.init`.
nonisolated enum FontRegistry {
    /// Runs once, on first access. `ThemeFont` touches it before resolving any font.
    static let registeredFontCount: Int = {
        let urls = ["ttf", "otf"].flatMap { Bundle.main.urls(forResourcesWithExtension: $0, subdirectory: nil) ?? [] }
        // Synchronous on purpose: callers read the installed families right after this returns.
        // A font that is already registered (e.g. after a preview reload) fails harmlessly.
        return urls.reduce(into: 0) { count, url in
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) {
                count += 1
            }
        }
    }()
}
