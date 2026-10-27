import SwiftUI

/// Camera viewfinder that reports every decoded QR string. Stops the camera when it leaves the screen.
struct QRScannerView: View {
    @Environment(\.manufacturerTheme) private var theme
    let onCode: (String) -> Void

    @State private var frame: CGImage?
    @State private var failure: QRCameraScanner.Failure?

    var body: some View {
        ZStack {
            Color.black
            if let frame {
                Image(decorative: frame, scale: 1)
                    .resizable()
                    .scaledToFill()
            } else if let failure {
                Text(message(for: failure))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(24)
            } else {
                ProgressView()
                    .tint(.white)
            }
            if failure == nil {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(theme.palette.accent, lineWidth: 2)
                    .frame(width: 240, height: 240)
                    .shadow(color: theme.palette.accent.opacity(0.6), radius: 6)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Camera viewfinder"))
        .accessibilityHint(Text("Point the camera at the QR code in the Pair window on the PC."))
        .task { await run() }
    }

    private func run() async {
        let scanner = QRCameraScanner()
        do {
            try await scanner.start()
        } catch {
            failure = error
            return
        }
        let codes = Task {
            for await code in scanner.codes {
                onCode(code)
            }
        }
        // Ends when the view disappears and SwiftUI cancels this task.
        for await next in scanner.frames {
            frame = next.image
        }
        codes.cancel()
        scanner.stop()
    }

    private func message(for failure: QRCameraScanner.Failure) -> LocalizedStringResource {
        switch failure {
        case .accessDenied: "Camera access is off. Allow it in Settings › Privacy › Camera, or enter the address manually below."
        case .cameraUnavailable: "Camera unavailable on this device. Enter the address manually below."
        case .configurationFailed: "The camera could not start. Try again, or enter the address manually below."
        }
    }
}
