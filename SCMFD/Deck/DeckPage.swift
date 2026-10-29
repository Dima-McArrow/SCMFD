import SwiftUI

nonisolated enum DeckPage: String, CaseIterable, Identifiable, Sendable {
    case flight
    case flightControls
    case power
    case quantum
    case emergency

    var id: String { rawValue }

    static let leftPages: [DeckPage] = [.flight, .power]
    static let rightPages: [DeckPage] = [.quantum, .flightControls, .emergency]

    var title: LocalizedStringResource {
        switch self {
        case .flight: "Flight"
        case .flightControls: "FC"
        case .power: "Power"
        case .quantum: "Quantum"
        case .emergency: "Emergency"
        }
    }
}

/// The keys of one deck page.
struct DeckPageContent: View {
    @Environment(\.commandLink) private var link
    let page: DeckPage
    @Bindable var state: DeckState

    private let spacing: CGFloat = 12

    private var hangarTint: KeyTint {
        switch state.hangarRequest {
        case .pending, .timeout: .amber
        case .answered: .green
        case .idle, .unrecognized, nil: .accent
        }
    }

    var body: some View {
        switch page {
        case .flight:
            Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
                GridRow {
                    MFDKey(
                        .flightReady,
                        isLit: state.binding(for: .flightReady),
                        detail: state.shipName.map { Text(verbatim: $0) } ?? Text("Ship · No data")
                    )
                        .gridCellColumns(2)
                }
                GridRow {
                    MFDKey(.landingGear, isLit: state.binding(for: .landingGear))
                    MFDKey(.vtol, isLit: state.binding(for: .vtol))
                }
                GridRow {
                    MFDKey(.lights, isLit: state.binding(for: .lights))
                    MFDKey(
                        .requestLanding,
                        tint: hangarTint,
                        title: "Request landing / takeoff",
                        detail: state.hangarRequest.map { Text($0.title) } ?? Text("ATC · No data")
                    )
                }
                GridRow {
                    MFDHoldKey(action: .autoLand, caption: "Tap to land")
                        .gridCellColumns(2)
                }
            }
        case .flightControls:
            VStack(spacing: spacing) {
                // Fixed vertically: the keys take their natural height (all as tall as the tallest one),
                // so the drums below are the only flexible row and get all the remaining height.
                HStack(spacing: spacing) {
                    MFDKey(.coupledMode, isLit: state.binding(for: .coupledMode))
                    MFDKey(.cruiseMode, isLit: state.binding(for: .cruiseMode))
                    MFDKey(.resetFlightAccelerometer)
                    MFDKey(.cycleConfiguration)
                }
                .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: spacing) {
                    MFDWheelDrum(title: "Speed limiter", keycap: "ALT+WHEEL",
                                 failure: state.wheelCommands.failure(for: .speedLimiter)) { intention in
                        state.wheelCommands.submit(intention, for: .speedLimiter, link: link)
                    }
                    MFDWheelDrum(title: "Acceleration limiter", keycap: "RALT+WHEEL",
                                 failure: state.wheelCommands.failure(for: .accelerationLimiter)) { intention in
                        state.wheelCommands.submit(intention, for: .accelerationLimiter, link: link)
                    }
                }
            }
        case .power:
            // Toggles on top, distribution below: raising one system draws from the others,
            // and reset returns to an even split. No meters until the server reports real values.
            Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
                GridRow {
                    MFDKey(.powerAll, isLit: state.binding(for: .powerAll))
                        .gridCellColumns(3)
                }
                GridRow {
                    MFDKey(.powerWeapons, isLit: state.binding(for: .powerWeapons), tint: .red)
                    MFDKey(.powerThrusters, isLit: state.binding(for: .powerThrusters), tint: .blue)
                    MFDKey(.powerShields, isLit: state.binding(for: .powerShields), tint: .green)
                }
                GridRow {
                    MFDKey(.raiseWeapons, tint: .red)
                    MFDKey(.raiseThrusters, tint: .blue)
                    MFDKey(.raiseShields, tint: .green)
                }
                GridRow {
                    MFDKey(.resetPower)
                        .gridCellColumns(3)
                }
            }
        case .quantum:
            // The engage key is the focal control, but capped so it doesn't swallow the page.
            // The QT target sits right above it: it is what you check before engaging (FIX-09).
            GeometryReader { geometry in
                VStack(spacing: spacing) {
                    HStack(spacing: spacing) {
                        MFDKey(.masterMode)
                        MFDKey(.operatorMode)
                    }
                    .frame(maxHeight: .infinity)
                    // Tighter spacing groups the readout with the key, so it reads as the key's own label.
                    VStack(spacing: 6) {
                        QuantumTargetReadout(target: state.quantumTarget)
                        MFDHoldKey(action: .quantumEngage, caption: "Tap to engage")
                            .frame(height: min(geometry.size.height * 0.55, 280))
                    }
                }
            }
        case .emergency:
            VStack(spacing: spacing) {
                MFDHoldKey(action: .exitSeat, tint: .amber, caption: "Tap to exit")
                MFDSlideToArm(isArmed: $state.selfDestructArmed)
                MFDHoldKey(
                    action: .selfDestruct,
                    tint: .red,
                    isEnabled: state.selfDestructArmed,
                    caption: "Tap to destruct"
                )
            }
        }
    }
}

#Preview("Flight / ATC pending", traits: .fixedLayout(width: 550, height: 650)) {
    @Previewable @State var state: DeckState = {
        let state = DeckState()
        state.enableManually()
        state.shipName = "Drake Cutter Rambler"
        state.hangarRequest = .pending
        return state
    }()
    DeckPageContent(page: .flight, state: state)
        .padding(20)
        .background { ThemeBackdropView() }
        .manufacturerTheme(.drake)
}

#Preview("Flight / ATC answered", traits: .fixedLayout(width: 550, height: 650)) {
    @Previewable @State var state: DeckState = {
        let state = DeckState()
        state.enableManually()
        state.shipName = "Drake Cutter Rambler"
        state.hangarRequest = .answered
        return state
    }()
    DeckPageContent(page: .flight, state: state)
        .padding(20)
        .background { ThemeBackdropView() }
        .manufacturerTheme(.drake)
}

#Preview("Flight controls", traits: .fixedLayout(width: 550, height: 650)) {
    @Previewable @State var state: DeckState = {
        let state = DeckState()
        state.enableManually()
        return state
    }()
    DeckPageContent(page: .flightControls, state: state)
        .padding(20)
        .background { ThemeBackdropView() }
        .manufacturerTheme(.drake)
}

#Preview("Quantum / destination", traits: .fixedLayout(width: 550, height: 650)) {
    @Previewable @State var state: DeckState = {
        let state = DeckState()
        state.enableManually()
        state.quantumTarget = .destination("CRU-L4")
        return state
    }()
    DeckPageContent(page: .quantum, state: state)
        .padding(20)
        .background { ThemeBackdropView() }
        .manufacturerTheme(.drake)
}

#Preview("Quantum / destination, compact", traits: .fixedLayout(width: 360, height: 560)) {
    @Previewable @State var state: DeckState = {
        let state = DeckState()
        state.enableManually()
        // A long technical name must still shrink onto one line.
        state.quantumTarget = .destination("MISSION_QT_Quantum_Beacon_LongRange_0042")
        return state
    }()
    DeckPageContent(page: .quantum, state: state)
        .padding(20)
        .background { ThemeBackdropView() }
        .manufacturerTheme(.aegis)
}
