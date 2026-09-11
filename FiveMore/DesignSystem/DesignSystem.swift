import SwiftUI
import UIKit

enum SRColor {
    private static func adaptive(_ light: UIColor, _ dark: UIColor) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }

    static let paper = adaptive(
        UIColor(red: 0.985, green: 0.972, blue: 0.935, alpha: 1),
        UIColor(red: 0.075, green: 0.078, blue: 0.075, alpha: 1)
    )
    static let paperShadow = adaptive(
        UIColor(red: 0.91, green: 0.88, blue: 0.80, alpha: 1),
        UIColor(red: 0.22, green: 0.225, blue: 0.21, alpha: 1)
    )
    static let card = adaptive(
        UIColor(red: 1.0, green: 0.988, blue: 0.955, alpha: 1),
        UIColor(red: 0.12, green: 0.125, blue: 0.115, alpha: 1)
    )
    static let charcoal = adaptive(
        UIColor(red: 0.12, green: 0.13, blue: 0.13, alpha: 1),
        UIColor(red: 0.96, green: 0.94, blue: 0.89, alpha: 1)
    )
    static let blue = adaptive(
        UIColor(red: 0.10, green: 0.55, blue: 0.89, alpha: 1),
        UIColor(red: 0.31, green: 0.70, blue: 1.0, alpha: 1)
    )
    static let yellow = adaptive(
        UIColor(red: 1.00, green: 0.74, blue: 0.16, alpha: 1),
        UIColor(red: 1.00, green: 0.78, blue: 0.24, alpha: 1)
    )
    static let orange = adaptive(
        UIColor(red: 0.98, green: 0.37, blue: 0.16, alpha: 1),
        UIColor(red: 1.00, green: 0.50, blue: 0.28, alpha: 1)
    )
    static let green = adaptive(
        UIColor(red: 0.34, green: 0.58, blue: 0.34, alpha: 1),
        UIColor(red: 0.50, green: 0.76, blue: 0.49, alpha: 1)
    )
    static let muted = adaptive(
        UIColor(red: 0.46, green: 0.45, blue: 0.41, alpha: 1),
        UIColor(red: 0.73, green: 0.70, blue: 0.64, alpha: 1)
    )
}

/// Brand display copy stays expressive without becoming a bitmap. Using a
/// relative custom font keeps Dynamic Type working for the parent-facing UI.
enum SRTypography {
    static let action = Font.custom(
        "Noteworthy-Bold",
        size: 24,
        relativeTo: .title3
    )
    static let displayTitle = Font.custom(
        "Noteworthy-Bold",
        size: 38,
        relativeTo: .largeTitle
    )
    static let paywallTitle = Font.custom(
        "Noteworthy-Bold",
        size: 34,
        relativeTo: .title
    )
}

/// Deterministic pseudo-random source so paper grain and crayon wobble are
/// stable across renders instead of shimmering on every state change.
private struct SeededWobble {
    var state: UInt64

    mutating func next(in range: ClosedRange<CGFloat>) -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let unit = CGFloat((state >> 33) & 0xFFFF) / CGFloat(0xFFFF)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }
}

struct PaperBackground: View {
    private static let specks: [(x: CGFloat, y: CGFloat, d: CGFloat, o: Double)] = {
        var rng = SeededWobble(state: 20260910)
        return (0..<48).map { _ in
            (
                rng.next(in: 0.02...0.98),
                rng.next(in: 0.02...0.98),
                rng.next(in: 0.7...1.7),
                Double(rng.next(in: 0.08...0.30))
            )
        }
    }()

    private static let fibers: [(x0: CGFloat, y0: CGFloat, x1: CGFloat, y1: CGFloat)] = {
        var rng = SeededWobble(state: 77)
        return (0..<7).map { _ in
            let x = rng.next(in: 0.05...0.9)
            let y = rng.next(in: 0.05...0.9)
            return (x, y, x + rng.next(in: -0.08...0.08), y + rng.next(in: -0.05...0.05))
        }
    }()

    var body: some View {
        ZStack {
            SRColor.paper

            Canvas { context, size in
                for speck in Self.specks {
                    let rect = CGRect(
                        x: size.width * speck.x,
                        y: size.height * speck.y,
                        width: speck.d,
                        height: speck.d
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(SRColor.paperShadow.opacity(speck.o)))
                }

                for fiber in Self.fibers {
                    var fiberPath = Path()
                    fiberPath.move(to: CGPoint(x: size.width * fiber.x0, y: size.height * fiber.y0))
                    fiberPath.addLine(to: CGPoint(x: size.width * fiber.x1, y: size.height * fiber.y1))
                    context.stroke(fiberPath, with: .color(SRColor.paperShadow.opacity(0.35)), lineWidth: 0.8)
                }
            }
        }
        .drawingGroup()
        .ignoresSafeArea()
    }
}

struct BrandWordmark: View {
    var body: some View {
        Image("BrandWordmark")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 158, height: 52)
            .foregroundStyle(SRColor.charcoal)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("5 More")
    }
}

/// The compact product signature used on working screens. It reuses the
/// familiar five-hand mark rather than spending vertical space on a second
/// large wordmark or creating another logo asset.
struct CompactBrandHeader: View {
    var body: some View {
        HStack(spacing: 7) {
            Image("SymbolFiveHand")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)

            Text("Five More Minutes")
                .font(.custom("Noteworthy-Bold", size: 21, relativeTo: .headline))
                .foregroundStyle(SRColor.charcoal)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Five More Minutes")
    }
}

/// A rounded box drawn like a crayon pass: a superellipse sampled once into
/// jittered unit points, smoothed through quadratic midpoints. The wobble is
/// static so the frame never shifts between renders.
struct CrayonStroke: Shape {
    private static let unit: [CGPoint] = {
        var rng = SeededWobble(state: 5)
        let count = 160
        let exponent: CGFloat = 0.5
        return (0..<count).map { i in
            let turn = CGFloat(i) / CGFloat(count) * 2 * .pi
            let cosine = cos(turn)
            let sine = sin(turn)
            let x = (cosine >= 0 ? 1 : -1) * pow(abs(cosine), exponent)
            let y = (sine >= 0 ? 1 : -1) * pow(abs(sine), exponent)
            let wobble = rng.next(in: -0.010...0.010)
            return CGPoint(x: x * (1 + wobble), y: y * (1 + wobble))
        }
    }()

    func path(in rect: CGRect) -> Path {
        let inset = rect.insetBy(dx: 7, dy: 7)
        let points = Self.unit.map { unit in
            CGPoint(
                x: inset.midX + unit.x * inset.width / 2,
                y: inset.midY + unit.y * inset.height / 2
            )
        }

        var stroke = Path()
        let last = points.count - 1
        stroke.move(to: midpoint(points[last], points[0]))
        for i in 0...last {
            stroke.addQuadCurve(
                to: midpoint(points[i], points[(i + 1) % points.count]),
                control: points[i]
            )
        }
        stroke.closeSubpath()
        return stroke
    }

    private func midpoint(_ first: CGPoint, _ second: CGPoint) -> CGPoint {
        CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
    }
}

struct CrayonFrame<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            // The photo and camera preview use the exact same irregular shape
            // as the blue border, so no square image corners can peek through.
            .clipShape(CrayonStroke())
            .overlay {
                CrayonStroke()
                    .stroke(SRColor.blue, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
            .overlay {
                CrayonStroke()
                    .stroke(SRColor.blue.opacity(0.55), lineWidth: 2)
                    .offset(x: 2, y: -2)
            }
            .overlay {
                CrayonStroke()
                    .stroke(SRColor.blue.opacity(0.35), lineWidth: 1.5)
                    .offset(x: -2, y: 2)
            }
            .shadow(color: SRColor.paperShadow.opacity(0.32), radius: 10, y: 5)
    }
}

struct PrimaryCameraButton: View {
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(SRColor.charcoal)
                    .frame(width: 82, height: 82)
                    .shadow(color: .black.opacity(0.16), radius: 10, y: 5)

                if isBusy {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image("IconCamera")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityLabel(isBusy ? "Taking photo" : "Take a photo to start")
    }
}

/// Small hand-drawn controls used in place of system symbols so secondary
/// screens keep the same visual language as the capture flow.
enum CrayonControlKind {
    case close
    case check
    case circle
    case play
    case stop
}

struct CrayonControlMark: View {
    let kind: CrayonControlKind
    let color: Color

    var body: some View {
        Canvas { context, size in
            let inset = min(size.width, size.height) * 0.18
            let rect = CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)
            let style = StrokeStyle(lineWidth: max(2, min(size.width, size.height) * 0.105), lineCap: .round, lineJoin: .round)

            switch kind {
            case .close:
                var path = Path()
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                context.stroke(path, with: .color(color), style: style)
            case .check:
                let circle = Path(ellipseIn: rect)
                context.stroke(circle, with: .color(color), style: style)
                var path = Path()
                path.move(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.43, y: rect.maxY - rect.height * 0.22))
                path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.minY + rect.height * 0.25))
                context.stroke(path, with: .color(color), style: style)
            case .circle:
                context.stroke(Path(ellipseIn: rect), with: .color(color), style: style)
            case .play:
                var path = Path()
                path.move(to: CGPoint(x: rect.minX + rect.width * 0.26, y: rect.minY + rect.height * 0.15))
                path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.26, y: rect.maxY - rect.height * 0.15))
                path.closeSubpath()
                context.fill(path, with: .color(color))
            case .stop:
                context.fill(Path(roundedRect: rect.insetBy(dx: rect.width * 0.18, dy: rect.height * 0.18), cornerRadius: 3), with: .color(color))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Explains the gesture in the place parents are already looking. The ring
/// doubles as feedback: it fills only while a full open palm remains visible.
struct AutoCaptureGuide: View {
    let progress: Double
    let isReady: Bool
    let isCapturing: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(SRColor.yellow.opacity(0.28), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: max(0.02, progress))
                    .stroke(SRColor.yellow, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image("SymbolFiveHand")
                    .resizable()
                    .scaledToFit()
                    .padding(7)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text(isCapturing ? "Photo is being saved" : isReady ? "Open hand found!" : "Photo takes itself")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                Text("Hold up 5 fingers until the yellow ring fills")
                    .font(.caption)
                    .foregroundStyle(SRColor.muted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(SRColor.card.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(SRColor.yellow.opacity(0.45), lineWidth: 1.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Automatic photo: hold up an open hand with five fingers until the yellow ring fills.")
    }
}


struct TimerProgressRing: View {
    let remainingSeconds: Int
    let totalSeconds: Int
    var diameter: CGFloat = 38
    var lineWidth: CGFloat = 6

    private var fraction: Double {
        guard totalSeconds > 0 else { return 0 }
        return min(1, max(0, Double(remainingSeconds) / Double(totalSeconds)))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(SRColor.green.opacity(0.18), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(SRColor.green, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}

/// Vertical and horizontal rhythm, on a 4pt base.
///
/// Four steps only: this app's theme is large and simple, so it has no need for
/// fine adjustment values. `zone` is the measured gap between the photo frame
/// and the timer in the reference images.
enum Spacing {
    static let tight: CGFloat = 8
    static let margin: CGFloat = 16
    static let section: CGFloat = 24
    static let zone: CGFloat = 44
}
