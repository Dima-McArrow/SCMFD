import Foundation

/// Every ship function the deck can trigger, with its Star Citizen default binding.
/// Bindings live here in one place; a user-editable keymap will override them later.
nonisolated enum ShipAction: String, CaseIterable, Identifiable, Codable, Sendable {
    case flightReady
    case landingGear
    case autoLand
    case vtol
    case requestLanding
    case lights
    case masterMode
    case operatorMode
    case quantumEngage
    case coupledMode
    case cruiseMode
    case resetFlightAccelerometer
    case cycleConfiguration
    case powerAll
    case powerWeapons
    case powerThrusters
    case powerShields
    case raiseWeapons
    case raiseThrusters
    case raiseShields
    case resetPower
    case exitSeat
    case selfDestruct

    /// How the key behaves on the tablet. The game always receives a real press and release;
    /// the kind only changes the visuals (lit state, hold ring) and the haptics.
    enum Kind: Sendable, Equatable {
        /// Momentary press.
        case tap
        /// Momentary press that flips a lit ON/OFF state on the tablet. The state follows taps, not the game.
        case toggle
        /// One tap on the tablet makes the game see the key held for `seconds`.
        /// The hold animation plays for exactly this long.
        case hold(seconds: Double)
    }

    var id: String { rawValue }

    var kind: Kind {
        switch self {
        case .requestLanding, .operatorMode: .tap
        case .raiseWeapons, .raiseThrusters, .raiseShields, .resetPower: .tap
        case .resetFlightAccelerometer, .cycleConfiguration: .tap
        case .flightReady, .landingGear, .vtol, .lights: .toggle
        // No telemetry for coupled or cruise: like the other toggles, the lit state follows the taps, not the game.
        case .coupledMode, .cruiseMode: .toggle
        case .powerAll, .powerWeapons, .powerThrusters, .powerShields: .toggle
        case .autoLand, .exitSeat: .hold(seconds: 1)
        // Long-press B cycles master mode; the game threshold is about a quarter second.
        case .masterMode: .hold(seconds: 0.5)
        case .quantumEngage: .hold(seconds: 1.5)
        case .selfDestruct: .hold(seconds: 3)
        }
    }

    /// Star Citizen default bindings, checked against Alpha 4.10.2: RAlt+R flight ready,
    /// long-press B cycles master mode, middle mouse cycles operator modes,
    /// long-press left mouse engages quantum.
    /// Flight-control chords (coupled, cruise, accelerometer, transform) come from the SCMFDBE ActionCatalog
    /// contract and are not yet checked in game.
    var defaultChord: KeyChord {
        switch self {
        case .flightReady: KeyChord("r", .ralt)
        case .landingGear: KeyChord("n")
        case .autoLand: KeyChord("n")
        case .vtol: KeyChord("k")
        case .requestLanding: KeyChord("n", .alt)
        case .lights: KeyChord("l")
        case .masterMode: KeyChord("b")
        case .operatorMode: KeyChord("mouse3")
        case .quantumEngage: KeyChord("mouse1")
        // Must match the SCMFDBE ActionCatalog exactly; `.alt` is left Alt, `.ralt` is right Alt.
        case .coupledMode: KeyChord("c")
        case .cruiseMode: KeyChord("c", .alt)
        case .resetFlightAccelerometer: KeyChord("c", .ralt)
        case .cycleConfiguration: KeyChord("k", .alt)
        case .powerAll: KeyChord("u")
        case .powerWeapons: KeyChord("p")
        case .powerThrusters: KeyChord("i")
        case .powerShields: KeyChord("o")
        case .raiseWeapons: KeyChord("f5")
        case .raiseThrusters: KeyChord("f6")
        case .raiseShields: KeyChord("f7")
        case .resetPower: KeyChord("f8")
        case .exitSeat: KeyChord("y")
        case .selfDestruct: KeyChord("backspace")
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .flightReady: "Flight ready"
        case .landingGear: "Landing gear"
        case .autoLand: "Auto land"
        case .vtol: "VTOL"
        case .requestLanding: "Request landing / takeoff"
        case .lights: "Lights"
        case .masterMode: "SCM / NAV"
        case .operatorMode: "Operator mode"
        case .quantumEngage: "Engage quantum"
        case .coupledMode: "Coupled"
        case .cruiseMode: "Cruise mode"
        case .resetFlightAccelerometer: "Reset accelerometer"
        case .cycleConfiguration: "Transform"
        case .powerAll: "Power"
        case .powerWeapons: "Weapons"
        case .powerThrusters: "Thrusters"
        case .powerShields: "Shields"
        case .raiseWeapons: "+ Weapons"
        case .raiseThrusters: "+ Thrusters"
        case .raiseShields: "+ Shields"
        case .resetPower: "Reset power"
        case .exitSeat: "Exit seat"
        case .selfDestruct: "Self-destruct"
        }
    }

    /// SF Symbol name.
    var symbol: String {
        switch self {
        case .flightReady: "power"
        case .landingGear: "airplane.arrival"
        case .autoLand: "arrow.down.to.line"
        case .vtol: "arrow.up.and.down.circle"
        case .requestLanding: "antenna.radiowaves.left.and.right"
        case .lights: "lightbulb.max"
        case .masterMode: "arrow.left.arrow.right"
        case .operatorMode: "slider.horizontal.3"
        case .quantumEngage: "sparkles"
        case .coupledMode: "link"
        case .cruiseMode: "gauge.with.dots.needle.67percent"
        case .resetFlightAccelerometer: "gyroscope"
        case .cycleConfiguration: "arrow.triangle.2.circlepath"
        case .powerAll: "bolt"
        case .powerWeapons: "scope"
        case .powerThrusters: "flame"
        case .powerShields: "shield"
        case .raiseWeapons, .raiseThrusters, .raiseShields: "chevron.up.2"
        case .resetPower: "arrow.counterclockwise"
        case .exitSeat: "figure.walk.departure"
        case .selfDestruct: "exclamationmark.triangle"
        }
    }
}
