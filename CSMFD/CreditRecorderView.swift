import SwiftUI

struct CreditRecorderView: View {
    let session: DemoSession
    let horizontal: Bool
    @Environment(\.manufacturerTheme) private var manufacturerTheme
    private var theme: MFDTheme { MFDTheme(manufacturerTheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            MFDPageHeading(
                eyebrow: "INDUSTRIAL SERIES / LEDGER / MFD–02",
                title: "Transaction History",
                subtitle: "Rewards and fines recorded in the archived log. Wallet balance is unknown.",
                theme: theme
            )

            MFDColumns(horizontal: horizontal) {
                recordedDelta
            } trailing: {
                MFDPanel(theme: theme) {
                    MFDLabel(text: "LEDGER / NEWEST FIRST", theme: theme)
                    ForEach(session.creditEntries) { entry in
                        VStack(alignment: .leading, spacing: 10) {
                            MFDLabel(text: "\(entry.time) UTC / NOTIFICATION", theme: theme)
                            ViewThatFits(in: .horizontal) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(entry.title)
                                    Spacer()
                                    entryAmount(entry)
                                }
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(entry.title)
                                    entryAmount(entry)
                                }
                            }
                            .font(.callout)
                            Text(entry.source)
                                .font(.caption)
                                .foregroundStyle(theme.muted)
                            Rectangle().fill(theme.edge).frame(height: 1)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    Text("The reward cannot be linked to a specific mission: the notification contains a zero mission ID.")
                        .font(.caption)
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                session.toggleFine()
            } label: {
                Label(
                    session.includesFine ? "Remove fine entry" : "Add fine entry",
                    systemImage: session.includesFine ? "minus.rectangle" : "plus.rectangle"
                )
            }
            .buttonStyle(MFDButtonStyle(theme: theme, prominent: true))
            .accessibilityIdentifier("credits.toggleFine")

            MFDReceipt(
                title: "LOCAL TOTAL / ENTRIES: \(session.creditEntries.count)",
                message: session.includesFine
                    ? "28,375 − 20,000 = +8,375. This is the net change from the two displayed entries; other transactions are unknown."
                    : "One reward is shown. Add the fine entry to see the combined total.",
                theme: theme
            )

            MFDSourceNote(
                theme: theme,
                lines: [
                    "Sample: 19 Jun 2026 · SC Tracker / sample-events.log.",
                    "Reward: 28,375 aUEC at 22:09:03 UTC. Fine: 20,000 UEC at 21:17:46 UTC.",
                    "Both entries come from notifications, not a balance API.",
                    "The total combines the nominal UEC/aUEC amounts in the sample.",
                    "The history may be incomplete. Purchases, sales, and unrecorded transactions are excluded.",
                ])
        }
    }

    private var recordedDelta: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("TOTAL OF DISPLAYED ENTRIES")
                .font(.system(.caption, design: .monospaced))
                .tracking(1.5)
            Text(MFDFormat.signed(session.recordedCreditDelta))
                .font(.system(size: 60, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .accessibilityIdentifier("credits.delta")
            Text("UEC / aUEC")
                .font(.system(.body, design: .monospaced))
            Rectangle().fill(theme.background.opacity(0.25)).frame(height: 1)
            VStack(alignment: .leading, spacing: 8) {
                Text("WALLET / NO DATA")
                    .font(.system(.callout, design: .monospaced).weight(.medium))
                Text("These entries cannot determine your current balance.")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(theme.background)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(theme.accent)
        .clipShape(CutCornerShape(cut: 16))
    }

    private func entryAmount(_ entry: CreditEntry) -> some View {
        Text(MFDFormat.signed(entry.amount))
            .font(.system(.title3, design: .monospaced).weight(.medium))
            .monospacedDigit()
            .foregroundStyle(theme.accent)
            .fixedSize()
    }
}

#Preview("Credits / Reward", traits: .fixedLayout(width: 1194, height: 834)) {
    MFDPreviewSurface(page: .credits)
}

#Preview("Credits / With fine", traits: .fixedLayout(width: 1194, height: 834)) {
    MFDPreviewSurface(page: .credits, scenario: .withFine)
}
