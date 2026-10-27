import SwiftUI

/// Radial ticks; `progress` (0...1) selects how many of them are drawn.
/// A `Shape` so SwiftUI interpolates `progress` and the ticks light up one by one.
nonisolated struct TickRingShape: Shape {
    var ticks: Int = 60
    var progress: Double = 1
    var majorEvery = 5

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let visible = Double(ticks) * min(max(progress, 0), 1)
        var path = Path()
        for index in 0..<ticks where Double(index) < visible {
            let angle = Double(index) / Double(ticks) * 2 * .pi - .pi / 2
            let length: CGFloat = index % majorEvery == 0 ? radius * 0.16 : radius * 0.09
            let outer = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            let inner = CGPoint(
                x: center.x + cos(angle) * (radius - length),
                y: center.y + sin(angle) * (radius - length)
            )
            path.move(to: inner)
            path.addLine(to: outer)
        }
        return path
    }
}

/// Hold progress dial: dim tick track, lit ticks for progress, inner hairline circle
/// and a dashed arc that sweeps while the key is held.
struct TickRing<Center: View>: View {
    var progress: Double
    var color: Color
    var track: Color
    var isSpinning: Bool
    @ViewBuilder var center: Center

    var body: some View {
        ZStack {
            TickRingShape(progress: 1)
                .stroke(track, lineWidth: 1)
            TickRingShape(progress: progress)
                .stroke(color, lineWidth: 1.4)
                .shadow(color: color.opacity(0.8), radius: 3)
            Circle()
                .inset(by: 0)
                .stroke(track, lineWidth: HUD.hairline)
                .padding(18)
            TimelineView(.animation(paused: !isSpinning)) { timeline in
                let angle = timeline.date.timeIntervalSinceReferenceDate * 220
                Circle()
                    .trim(from: 0, to: 0.22)
                    .stroke(color, style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2, 4]))
                    .rotationEffect(.degrees(angle.truncatingRemainder(dividingBy: 360)))
                    .padding(-6)
                    .opacity(isSpinning ? 1 : 0)
            }
            center
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
