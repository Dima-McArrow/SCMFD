import SwiftUI

nonisolated enum DeckPage: String, CaseIterable, Identifiable, Sendable {
    case flight
    case power
    case quantum
    case emergency

    var id: String { rawValue }

    static let leftPages: [DeckPage] = [.flight, .power]
    static let rightPages: [DeckPage] = [.quantum, .emergency]

    var title: LocalizedStringResource {
        switch self {
        case .flight: "Flight"
        case .power: "Power"
        case .quantum: "Quantum"
        case .emergency: "Emergency"
        }
    }
}

/// The keys of one deck page.
struct DeckPageContent: View {
    let page: DeckPage
    @Bindable var state: DeckState

    private let spacing: CGFloat = 12

    private var hangarTint: KeyTint {
        switch state.hangarRequest {
        case .pending, .timeout: .amber
        case .answered: .green
        case .idle, nil: .accent
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
            GeometryReader { geometry in
                VStack(spacing: spacing) {
                    QuantumTargetReadout(target: state.quantumTarget)
                    HStack(spacing: spacing) {
                        MFDKey(.masterMode)
                        MFDKey(.operatorMode)
                    }
                    .frame(maxHeight: .infinity)
                    MFDHoldKey(action: .quantumEngage, caption: "Tap to engage")
                        .frame(height: min(geometry.size.height * 0.55, 280))
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
