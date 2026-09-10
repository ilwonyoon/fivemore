import SwiftUI

struct CrayonHeroView: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 330, size.height / 330)
            let center = CGPoint(x: size.width * 0.52, y: size.height * 0.53)

            drawPlanet(in: &context, center: CGPoint(x: size.width * 0.24, y: size.height * 0.25), scale: scale)
            drawRocket(in: &context, center: center, scale: scale)
            drawStars(in: &context, size: size, scale: scale)
        }
        .background(SRColor.paper)
        .drawingGroup()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A childlike crayon drawing of a rocket flying through space")
    }

    private func drawPlanet(in context: inout GraphicsContext, center: CGPoint, scale: CGFloat) {
        let radius = 35 * scale
        let planet = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.fill(planet, with: .color(SRColor.blue.opacity(0.75)))
        context.stroke(planet, with: .color(SRColor.blue), style: StrokeStyle(lineWidth: 5 * scale, lineCap: .round))

        var ring = Path()
        ring.addEllipse(in: CGRect(x: center.x - radius * 1.6, y: center.y - radius * 0.45, width: radius * 3.2, height: radius * 0.9))
        context.stroke(ring, with: .color(SRColor.green), style: StrokeStyle(lineWidth: 5 * scale, lineCap: .round))
    }

    private func drawRocket(in context: inout GraphicsContext, center: CGPoint, scale: CGFloat) {
        var body = Path()
        body.move(to: CGPoint(x: center.x - 28 * scale, y: center.y + 48 * scale))
        body.addCurve(
            to: CGPoint(x: center.x + 40 * scale, y: center.y - 70 * scale),
            control1: CGPoint(x: center.x - 26 * scale, y: center.y - 8 * scale),
            control2: CGPoint(x: center.x + 13 * scale, y: center.y - 58 * scale)
        )
        body.addCurve(
            to: CGPoint(x: center.x + 28 * scale, y: center.y + 55 * scale),
            control1: CGPoint(x: center.x + 63 * scale, y: center.y - 35 * scale),
            control2: CGPoint(x: center.x + 56 * scale, y: center.y + 25 * scale)
        )
        body.closeSubpath()
        context.fill(body, with: .color(.white.opacity(0.94)))
        context.stroke(body, with: .color(SRColor.blue), style: StrokeStyle(lineWidth: 7 * scale, lineCap: .round, lineJoin: .round))

        var nose = Path()
        nose.move(to: CGPoint(x: center.x + 14 * scale, y: center.y - 54 * scale))
        nose.addLine(to: CGPoint(x: center.x + 42 * scale, y: center.y - 92 * scale))
        nose.addLine(to: CGPoint(x: center.x + 54 * scale, y: center.y - 45 * scale))
        nose.closeSubpath()
        context.fill(nose, with: .color(SRColor.orange))
        context.stroke(nose, with: .color(SRColor.orange.opacity(0.9)), style: StrokeStyle(lineWidth: 5 * scale, lineCap: .round))

        let windowRect = CGRect(x: center.x + 2 * scale, y: center.y - 23 * scale, width: 36 * scale, height: 36 * scale)
        context.fill(Path(ellipseIn: windowRect), with: .color(SRColor.yellow))
        context.stroke(Path(ellipseIn: windowRect), with: .color(SRColor.blue), style: StrokeStyle(lineWidth: 5 * scale))

        var leftFin = Path()
        leftFin.move(to: CGPoint(x: center.x - 21 * scale, y: center.y + 23 * scale))
        leftFin.addLine(to: CGPoint(x: center.x - 58 * scale, y: center.y + 56 * scale))
        leftFin.addLine(to: CGPoint(x: center.x - 20 * scale, y: center.y + 66 * scale))
        leftFin.closeSubpath()
        context.fill(leftFin, with: .color(SRColor.orange))

        var rightFin = Path()
        rightFin.move(to: CGPoint(x: center.x + 34 * scale, y: center.y + 27 * scale))
        rightFin.addLine(to: CGPoint(x: center.x + 69 * scale, y: center.y + 51 * scale))
        rightFin.addLine(to: CGPoint(x: center.x + 29 * scale, y: center.y + 69 * scale))
        rightFin.closeSubpath()
        context.fill(rightFin, with: .color(SRColor.orange))

        let flameColors = [SRColor.orange, SRColor.yellow, SRColor.orange.opacity(0.72)]
        for index in 0..<3 {
            var flame = Path()
            let x = center.x + CGFloat(index - 1) * 17 * scale
            flame.move(to: CGPoint(x: x, y: center.y + 61 * scale))
            flame.addLine(to: CGPoint(x: x - 8 * scale, y: center.y + CGFloat(105 + index * 8) * scale))
            context.stroke(flame, with: .color(flameColors[index]), style: StrokeStyle(lineWidth: 8 * scale, lineCap: .round))
        }
    }

    private func drawStars(in context: inout GraphicsContext, size: CGSize, scale: CGFloat) {
        let points = [
            CGPoint(x: size.width * 0.16, y: size.height * 0.62),
            CGPoint(x: size.width * 0.78, y: size.height * 0.24),
            CGPoint(x: size.width * 0.82, y: size.height * 0.70)
        ]

        for (index, point) in points.enumerated() {
            var star = Path()
            let radius = CGFloat(index == 1 ? 18 : 13) * scale
            for ray in 0..<8 {
                let angle = CGFloat(ray) * .pi / 4
                let inner = CGPoint(x: point.x + cos(angle) * radius * 0.25, y: point.y + sin(angle) * radius * 0.25)
                let outer = CGPoint(x: point.x + cos(angle) * radius, y: point.y + sin(angle) * radius)
                star.move(to: inner)
                star.addLine(to: outer)
            }
            context.stroke(star, with: .color(SRColor.yellow), style: StrokeStyle(lineWidth: 5 * scale, lineCap: .round))
        }
    }
}

#Preview {
    CrayonFrame {
        CrayonHeroView()
            .frame(width: 330, height: 360)
    }
    .padding()
    .background(SRColor.paper)
}

