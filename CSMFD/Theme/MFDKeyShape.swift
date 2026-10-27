import SwiftUI

/// Key outline driven by per-corner tokens: square, 45° cut or rounded.
/// Mirrors the `clip-path` / `border-radius` combinations of the CSS reference.
nonisolated struct MFDKeyShape: InsettableShape {
    var corners: KeyCorners
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let frame = rect.insetBy(dx: insetAmount, dy: insetAmount)
        guard frame.width > 0, frame.height > 0 else { return Path() }

        let limit = min(frame.width, frame.height) / 2
        let topLeading = extent(of: corners.topLeading, limit: limit)
        let topTrailing = extent(of: corners.topTrailing, limit: limit)
        let bottomTrailing = extent(of: corners.bottomTrailing, limit: limit)
        let bottomLeading = extent(of: corners.bottomLeading, limit: limit)

        var path = Path()
        path.move(to: CGPoint(x: frame.minX + topLeading, y: frame.minY))

        path.addLine(to: CGPoint(x: frame.maxX - topTrailing, y: frame.minY))
        addCorner(
            corners.topTrailing,
            extent: topTrailing,
            at: CGPoint(x: frame.maxX, y: frame.minY),
            to: CGPoint(x: frame.maxX, y: frame.minY + topTrailing),
            in: &path
        )

        path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY - bottomTrailing))
        addCorner(
            corners.bottomTrailing,
            extent: bottomTrailing,
            at: CGPoint(x: frame.maxX, y: frame.maxY),
            to: CGPoint(x: frame.maxX - bottomTrailing, y: frame.maxY),
            in: &path
        )

        path.addLine(to: CGPoint(x: frame.minX + bottomLeading, y: frame.maxY))
        addCorner(
            corners.bottomLeading,
            extent: bottomLeading,
            at: CGPoint(x: frame.minX, y: frame.maxY),
            to: CGPoint(x: frame.minX, y: frame.maxY - bottomLeading),
            in: &path
        )

        path.addLine(to: CGPoint(x: frame.minX, y: frame.minY + topLeading))
        addCorner(
            corners.topLeading,
            extent: topLeading,
            at: CGPoint(x: frame.minX, y: frame.minY),
            to: CGPoint(x: frame.minX + topLeading, y: frame.minY),
            in: &path
        )

        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> MFDKeyShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }

    /// Distance from the corner point to where the corner starts on each edge,
    /// corrected for the inset so `strokeBorder` stays parallel to the outer outline.
    private func extent(of corner: KeyCorner, limit: CGFloat) -> CGFloat {
        let value: CGFloat
        switch corner {
        case .square:
            value = 0
        case .cut(let size):
            // A 45° chamfer offset inward by d shrinks by d * (2 - √2) along each edge.
            value = size - insetAmount * (2 - CGFloat(2).squareRoot())
        case .round(let radius):
            value = radius - insetAmount
        }
        return min(max(value, 0), limit)
    }

    private func addCorner(
        _ corner: KeyCorner,
        extent: CGFloat,
        at point: CGPoint,
        to end: CGPoint,
        in path: inout Path
    ) {
        guard extent > 0 else {
            path.addLine(to: point)
            return
        }
        switch corner {
        case .square:
            path.addLine(to: point)
        case .cut:
            path.addLine(to: end)
        case .round:
            path.addArc(tangent1End: point, tangent2End: end, radius: extent)
        }
    }
}

nonisolated extension ManufacturerTheme.Key {
    var shape: MFDKeyShape { MFDKeyShape(corners: corners) }

    /// Key background with the CSS gradient angle converted to unit points.
    var fillGradient: LinearGradient {
        let (start, end) = UnitPoint.cssGradientPoints(angle: fillAngle)
        return LinearGradient(colors: [fillTop, fillBottom], startPoint: start, endPoint: end)
    }
}

extension UnitPoint {
    /// CSS `linear-gradient(<angle>deg, ...)`: 0° points up, angles grow clockwise.
    nonisolated static func cssGradientPoints(angle degrees: Double) -> (UnitPoint, UnitPoint) {
        let radians = degrees * .pi / 180
        let dx = sin(radians) / 2
        let dy = -cos(radians) / 2
        return (UnitPoint(x: 0.5 - dx, y: 0.5 - dy), UnitPoint(x: 0.5 + dx, y: 0.5 + dy))
    }
}
