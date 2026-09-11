import SwiftUI

/// The generated Home illustration used before a photo starts the timer.
/// Keeping it in the asset catalog gives the start state the same tactile
/// crayon texture as the product references without rasterizing any UI text.
struct CrayonHeroView: View {
    var body: some View {
        Image("HeroSpace")
            .resizable()
            .scaledToFit()
            .padding(4)
        .background(SRColor.paper)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A childlike crayon drawing of a rocket, planet, and stars")
    }

    private func crayon(
        _ context: inout GraphicsContext,
        _ path: Path,
        color: Color,
        width: CGFloat
    ) {
        context.stroke(
            path.offsetBy(dx: 1.6, dy: -1.6),
            with: .color(color.opacity(0.32)),
            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        )
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawSun(in context: inout GraphicsContext, origin: CGPoint, scale: CGFloat) {
        let at = { (x: CGFloat, y: CGFloat) in CGPoint(x: origin.x + x * scale, y: origin.y + y * scale) }

        crayon(
            &context,
            Path(ellipseIn: CGRect(x: at(232, 30).x, y: at(232, 30).y, width: 52 * scale, height: 48 * scale)),
            color: SRColor.yellow,
            width: 6 * scale
        )

        var rays = Path()
        rays.move(to: at(258, 12)); rays.addLine(to: at(258, 2))
        rays.move(to: at(296, 54)); rays.addLine(to: at(306, 54))
        rays.move(to: at(238, 20)); rays.addLine(to: at(230, 12))
        rays.move(to: at(288, 26)); rays.addLine(to: at(296, 18))
        rays.move(to: at(292, 92)); rays.addLine(to: at(298, 100))
        crayon(&context, rays, color: SRColor.yellow, width: 5 * scale)
    }

    private func drawCloud(in context: inout GraphicsContext, origin: CGPoint, scale: CGFloat) {
        let at = { (x: CGFloat, y: CGFloat) in CGPoint(x: origin.x + x * scale, y: origin.y + y * scale) }

        var cloud = Path()
        cloud.move(to: at(28, 74))
        cloud.addQuadCurve(to: at(52, 58), control: at(36, 56))
        cloud.addQuadCurve(to: at(78, 62), control: at(64, 52))
        cloud.addQuadCurve(to: at(96, 74), control: at(90, 60))
        crayon(&context, cloud, color: SRColor.blue, width: 5 * scale)
    }

    private func drawHouse(in context: inout GraphicsContext, origin: CGPoint, scale: CGFloat) {
        let at = { (x: CGFloat, y: CGFloat) in CGPoint(x: origin.x + x * scale, y: origin.y + y * scale) }

        var walls = Path()
        walls.addRect(CGRect(x: at(84, 176).x, y: at(84, 176).y, width: 118 * scale, height: 92 * scale))
        crayon(&context, walls, color: SRColor.blue, width: 6 * scale)

        var roof = Path()
        roof.move(to: at(76, 178))
        roof.addLine(to: at(146, 122))
        roof.addLine(to: at(212, 176))
        crayon(&context, roof, color: SRColor.blue, width: 6 * scale)

        var door = Path()
        door.addRect(CGRect(x: at(130, 218).x, y: at(130, 218).y, width: 30 * scale, height: 50 * scale))
        crayon(&context, door, color: SRColor.orange, width: 5 * scale)

        var window = Path()
        window.move(to: at(96, 200)); window.addLine(to: at(118, 200))
        window.move(to: at(107, 190)); window.addLine(to: at(107, 210))
        crayon(&context, window, color: SRColor.orange, width: 4 * scale)
    }

    private func drawFigure(
        in context: inout GraphicsContext,
        origin: CGPoint,
        scale: CGFloat,
        hip: CGPoint,
        tall: CGFloat
    ) {
        let at = { (x: CGFloat, y: CGFloat) in CGPoint(x: origin.x + x * scale, y: origin.y + y * scale) }
        let limbs = tall * scale

        crayon(
            &context,
            Path(ellipseIn: CGRect(
                x: at(hip.x - 9 * tall, hip.y - 52 * tall).x,
                y: at(hip.x - 9 * tall, hip.y - 52 * tall).y,
                width: 18 * limbs,
                height: 17 * limbs
            )),
            color: SRColor.charcoal,
            width: 4 * scale
        )

        var body = Path()
        body.move(to: at(hip.x, hip.y - 34 * tall))
        body.addLine(to: at(hip.x + 2, hip.y))
        body.move(to: at(hip.x, hip.y - 28 * tall))
        body.addLine(to: at(hip.x - 15 * tall, hip.y - 12 * tall))
        body.move(to: at(hip.x, hip.y - 28 * tall))
        body.addLine(to: at(hip.x + 16 * tall, hip.y - 16 * tall))
        body.move(to: at(hip.x + 2, hip.y))
        body.addLine(to: at(hip.x - 9 * tall, hip.y + 22 * tall))
        body.move(to: at(hip.x + 2, hip.y))
        body.addLine(to: at(hip.x + 11 * tall, hip.y + 22 * tall))
        crayon(&context, body, color: SRColor.charcoal, width: 4 * scale)
    }

    private func drawBush(in context: inout GraphicsContext, origin: CGPoint, scale: CGFloat) {
        let at = { (x: CGFloat, y: CGFloat) in CGPoint(x: origin.x + x * scale, y: origin.y + y * scale) }

        var bush = Path()
        bush.addEllipse(in: CGRect(x: at(214, 246).x, y: at(214, 246).y, width: 62 * scale, height: 26 * scale))
        crayon(&context, bush, color: SRColor.green, width: 5 * scale)
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
