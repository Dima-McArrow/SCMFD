import SwiftUI

struct MissionControlView: View {
    let session: DemoSession
    let horizontal: Bool
    @Environment(\.manufacturerTheme) private var manufacturerTheme
    private var theme: MFDTheme { MFDTheme(manufacturerTheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            MFDPageHeading(
                eyebrow: "COVALEX / HAULING / MFD–01",
                title: "Supply Delivery",
                subtitle: "Archived session contract. Delivery objectives were extracted from the log.",
                theme: theme
            )

            MFDPanel(theme: theme, highlighted: true) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 24) {
                        contractIdentity
                        Spacer()
                        contractStatus
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        contractIdentity
                        contractStatus
                    }
                }
            }

            MFDColumns(horizontal: horizontal) {
                objectiveCard(session.objectives[0], index: "A")
            } trailing: {
                objectiveCard(session.objectives[1], index: "B")
            }

            MFDReceipt(
                title: session.missionAbandoned ? "21:42:39 UTC / END MISSION" : "21:03:51 UTC / CONTRACT",
                message: session.missionAbandoned
                    ? "The player abandoned this contract. Objectives remain visible for reference."
                    : "Contract accepted. Required cargo quantities are known; actual cargo on board is unknown.",
                theme: theme
            )
            .accessibilityIdentifier("mission.receipt")

            MFDColumns(horizontal: horizontal) {
                Button {
                    session.replayAbandonment()
                } label: {
                    Label("Replay abandonment", systemImage: "forward.end")
                }
                .buttonStyle(MFDButtonStyle(theme: theme, prominent: true))
                .disabled(session.missionAbandoned)
                .opacity(session.missionAbandoned ? 0.4 : 1)
                .accessibilityIdentifier("mission.abandon")
            } trailing: {
                Button {
                    session.replayAcceptance()
                } label: {
                    Label("Replay contract acceptance", systemImage: "backward.end")
                }
                .buttonStyle(MFDButtonStyle(theme: theme))
                .accessibilityIdentifier("mission.replay")
            }

            MFDSourceNote(
                theme: theme,
                lines: [
                    "Sample: 19 Jun 2026 · SC Tracker / sample-events.log.",
                    "MissionId: addd0f67-f57d-4173-a212-7a8f46e4b3fd.",
                    "Objectives: 13 SCU of ice → HDPC-Cassillo; 188 SCU of food → Teasa Spaceport.",
                    "In this sample, the contract ends in abandonment rather than a completed delivery.",
                    "201 SCU is the total required cargo, not a cargo hold reading.",
                ])
        }
    }

    private var contractIdentity: some View {
        VStack(alignment: .leading, spacing: 8) {
            MFDLabel(text: "CONTRACT / ADDD0F67", theme: theme)
            Text("MULTI–DROP / SUPPLY")
                .font(.system(.title2, design: .monospaced).weight(.medium))
                .foregroundStyle(theme.accent)
            Text("2 delivery stops · \(session.requiredSCU) SCU required")
                .font(.callout)
                .foregroundStyle(theme.muted)
        }
    }

    private var contractStatus: some View {
        MFDTag(
            text: session.missionAbandoned ? "CONTRACT ABANDONED" : "CONTRACT ACCEPTED",
            theme: theme,
            filled: !session.missionAbandoned
        )
        .accessibilityIdentifier("mission.status")
    }

    private func objectiveCard(_ objective: DeliveryObjective, index: String) -> some View {
        MFDPanel(theme: theme) {
            HStack {
                MFDLabel(text: "DELIVERY STOP / \(index)", theme: theme)
                Spacer()
                Image(systemName: "shippingbox")
                    .foregroundStyle(theme.accent)
                    .accessibilityHidden(true)
            }
            Text(objective.destination)
                .font(.system(.title2, design: .monospaced).weight(.medium))
                .foregroundStyle(theme.accent)
                .fixedSize(horizontal: false, vertical: true)
            Text(objective.commodity)
                .font(.headline)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(MFDFormat.integer(objective.requiredSCU))
                    .font(.system(size: 48, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                Text("SCU")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(theme.muted)
            }
            Rectangle().fill(theme.edge).frame(height: 1)
            Text(
                session.missionAbandoned
                    ? "Archived objective · contract closed" : "Contract requirement · cargo on board unknown"
            )
            .font(.caption)
            .foregroundStyle(theme.muted)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("Mission / Accepted", traits: .fixedLayout(width: 1194, height: 834)) {
    MFDPreviewSurface(page: .mission)
}

#Preview("Mission / Abandoned", traits: .fixedLayout(width: 1194, height: 834)) {
    MFDPreviewSurface(page: .mission, scenario: .abandoned)
}

#Preview("Mission / Narrow screen", traits: .fixedLayout(width: 390, height: 844)) {
    MFDPreviewSurface(page: .mission)
}
