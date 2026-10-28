# FIX-09 · QT target readout sits directly above the Engage quantum key

| | |
|---|---|
| Size | XS (layout only) |
| Depends on | nothing |
| Requested | owner, 2026-10-28 |
| Status | implemented 2026-10-28 (`DeckPage.swift`, `case .quantum`), previews `Quantum / destination` (550×650) and `Quantum / destination, compact` (360×560) checked: the readout sits above Engage and does not overlap the hold ring. At 360 pt a long name (`MISSION_QT_Quantum_Beacon_LongRange_0042`) stays on one line but is truncated, not fully shrunk. Not yet checked on the device |

## Problem

On the Quantum page (`SCMFD/Deck/DeckPage.swift`, `case .quantum`) the order is: `QuantumTargetReadout` at the
top of the page, then the SCM/NAV and Operator mode keys, then the Engage quantum hold key. The readout is the
information you check right before engaging, but it is a whole row of keys away from that key.

## Change

New order: SCM/NAV + Operator mode on top, then the readout **directly above** Engage quantum, grouped with it by
a tighter spacing so it reads as the key's own label. Key sizes do not change: the upper row still takes the
remaining height, Engage keeps `min(height * 0.55, 280)`, the readout keeps its fixed 64 pt.

```swift
case .quantum:
    // The engage key is the focal control, but capped so it doesn't swallow the page.
    // The QT target sits right above it: it is what you check before engaging.
    GeometryReader { geometry in
        VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                MFDKey(.masterMode)
                MFDKey(.operatorMode)
            }
            .frame(maxHeight: .infinity)
            VStack(spacing: 6) {
                QuantumTargetReadout(target: state.quantumTarget)
                MFDHoldKey(action: .quantumEngage, caption: "Tap to engage")
                    .frame(height: min(geometry.size.height * 0.55, 280))
            }
        }
    }
```

Add a `#Preview("Quantum / destination")` for `DeckPageContent(page: .quantum, …)` with
`state.quantumTarget = .destination("CRU-L4")` to check the layout in Xcode, in at least one compact and one
large iPad size.

## Tests

None: layout only, no logic change. Check the preview and on the device: the readout must not overlap the
Engage hold ring, and long names (`MISSION_QT_Quantum_Beacon_LongRange_…`) still shrink on one line
(`minimumScaleFactor(0.6)` is already there).
