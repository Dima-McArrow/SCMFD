import SwiftUI

/// Pair with the Windows server: scan the QR code from its Pair window, type the 6-digit code,
/// done. Manual address entry with a fingerprint comparison is the fallback.
struct ConnectToPCView: View {
    @Environment(\.manufacturerTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    let connection: ServerConnection

    @AppStorage("debugServerIPv4") private var manualHost = ""
    @AppStorage("debugServerPort") private var manualPort = "47823"
    @State private var isScanning = false
    @State private var scanMessage: LocalizedStringResource?
    @State private var lastRejectedCode: String?
    @State private var code = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    status
                    main
                    manualPairing
                }
                .padding(20)
                .frame(maxWidth: 700, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(theme.palette.text)
            .background(theme.palette.panel.opacity(0.35))
            .navigationTitle(Text("Connect to PC"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Status

    private var status: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                StatusPip(color: statusColor, isOn: true, size: 7)
                Text(statusTitle)
                    .font(.headline)
            }
            // Keep the recovery guidance visible even when later log entries change.
            if connection.phase == .closed(.pinRejected) {
                Text("The server certificate could not be verified. Pair again to connect.",
                     comment: "Shown after certificate pin rejection. Ask the user to pair again without claiming the certificate changed.")
                    .font(.callout)
                    .foregroundStyle(theme.palette.red)
            } else if let last = connection.entries.last, !isReady {
                Text(verbatim: last.message)
                    .font(.callout)
                    .foregroundStyle(theme.palette.dim)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Main step

    @ViewBuilder
    private var main: some View {
        if connection.phase == .pairingRequired {
            codeEntry
        } else if isScanning {
            scanner
        } else if isReady, let server = connection.pairedServer {
            pairedControls(server, connected: true)
        } else if isBusy {
            ProgressView()
        } else if let server = connection.pairedServer {
            pairedControls(server, connected: false)
        } else {
            scanIntro
        }
    }

    private var scanIntro: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("On the PC, open the CSMFD tray icon and choose **Pair iPad…**, then scan the QR code it shows.")
            Button("Scan QR code", systemImage: "qrcode.viewfinder") {
                scanMessage = nil
                isScanning = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var scanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            QRScannerView { handle($0) }
            if let scanMessage {
                Text(scanMessage)
                    .foregroundStyle(theme.palette.red)
            }
            Button("Cancel") { isScanning = false }
                .buttonStyle(.bordered)
        }
    }

    private var codeEntry: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Type the 6-digit code shown in the Pair window on the PC.")
            HStack {
                TextField("6-digit code", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.title2.monospaced())
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
                    .onSubmit { sendCode() }
                Button("Pair") { sendCode() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValidCode)
            }
        }
    }

    private func pairedControls(_ server: PairedServer, connected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: "\(server.host):\(server.port)")
                .font(.title3.monospaced())
            HStack {
                if connected {
                    Button("Disconnect") { connection.disconnect() }
                        .buttonStyle(.bordered)
                } else {
                    Button("Connect", systemImage: "network.badge.shield.half.filled") { connection.connect() }
                        .buttonStyle(.borderedProminent)
                }
                Button("Pair again", systemImage: "qrcode.viewfinder") {
                    connection.disconnect()
                    scanMessage = nil
                    isScanning = true
                }
                .buttonStyle(.bordered)
                Button("Forget this PC", role: .destructive) { connection.forgetPairing() }
                    .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Manual fallback

    private var manualPairing: some View {
        DisclosureGroup("Enter the address manually") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Use the private IPv4 address shown in the Pair window. You will compare the certificate fingerprint before anything is sent.")
                    .font(.callout)
                    .foregroundStyle(theme.palette.dim)
                TextField("PC IPv4 address", text: $manualHost, prompt: Text(verbatim: "192.168.1.42"))
                    .keyboardType(.decimalPad)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                TextField("Port", text: $manualPort)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)

                if let captured = connection.capturedFingerprint {
                    Text("Compare with the fingerprint in the Pair window on the PC:")
                    Text(verbatim: captured.grouped)
                        .font(.title3.monospaced())
                        .textSelection(.enabled)
                    HStack {
                        Button("Matches the PC — pair", systemImage: "checkmark.shield") {
                            connection.pairWithCapturedFingerprint()
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Does not match", role: .cancel) { connection.disconnect() }
                            .buttonStyle(.bordered)
                    }
                } else {
                    Button("Read fingerprint", systemImage: "lock.shield") {
                        guard let endpoint = manualEndpoint else { return }
                        isScanning = false
                        connection.captureFingerprint(host: endpoint.host, port: endpoint.port)
                    }
                    .buttonStyle(.bordered)
                    .disabled(manualEndpoint == nil || connection.isCapturingFingerprint)
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Actions

    private func handle(_ scanned: String) {
        guard let url = URL(string: scanned), let payload = try? PairingPayload(url: url) else {
            // The camera reports the same code many times a second; react once.
            guard scanned != lastRejectedCode else { return }
            lastRejectedCode = scanned
            withAnimation { scanMessage = "Not a CSMFD pairing code" }
            return
        }
        isScanning = false
        scanMessage = nil
        connection.pair(with: payload)
    }

    private func sendCode() {
        guard isValidCode else { return }
        connection.submitPairingCode(code)
        code = ""
    }

    // MARK: - Derived state

    private var isValidCode: Bool {
        code.count == 6 && code.allSatisfy { ("0"..."9").contains($0) }
    }

    private var isReady: Bool {
        if case .ready = connection.phase { true } else { false }
    }

    private var isBusy: Bool {
        connection.isCapturingFingerprint || connection.phase == .awaitingWelcome || connection.phase == .pairing
    }

    private var statusTitle: LocalizedStringResource {
        switch connection.phase {
        case .ready: "Connected"
        case .pairingRequired: "Waiting for the code"
        case .pairing: "Checking code…"
        case .awaitingWelcome: "Connecting…"
        case .idle, .closed: connection.pairedServer == nil ? "Not paired" : "Not connected"
        }
    }

    private var statusColor: Color {
        switch connection.phase {
        case .ready: theme.palette.green
        case .awaitingWelcome, .pairingRequired, .pairing: theme.palette.amber
        case .idle, .closed: theme.palette.red
        }
    }

    private var manualEndpoint: (host: String, port: UInt16)? {
        let host = manualHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard PrivateIPv4.isValid(host), let port = UInt16(manualPort.trimmingCharacters(in: .whitespaces)), port > 0 else {
            return nil
        }
        return (host, port)
    }
}

#Preview("Connect to PC") {
    ConnectToPCView(connection: ServerConnection(store: ServerTrustStore(service: "com.csmfd.preview")))
        .manufacturerTheme(.drake)
}
