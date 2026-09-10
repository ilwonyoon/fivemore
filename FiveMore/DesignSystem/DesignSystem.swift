import SwiftUI

enum SRColor {
    static let paper = Color(red: 0.985, green: 0.972, blue: 0.935)
    static let paperShadow = Color(red: 0.91, green: 0.88, blue: 0.80)
    static let charcoal = Color(red: 0.12, green: 0.13, blue: 0.13)
    static let blue = Color(red: 0.10, green: 0.55, blue: 0.89)
    static let yellow = Color(red: 1.00, green: 0.74, blue: 0.16)
    static let orange = Color(red: 0.98, green: 0.37, blue: 0.16)
    static let green = Color(red: 0.34, green: 0.58, blue: 0.34)
    static let muted = Color(red: 0.46, green: 0.45, blue: 0.41)
}

struct PaperBackground: View {
    var body: some View {
        ZStack {
            SRColor.paper

            Canvas { context, size in
                let dots: [(CGFloat, CGFloat, CGFloat)] = [
                    (0.08, 0.11, 1.1), (0.24, 0.07, 0.8), (0.47, 0.17, 0.9),
                    (0.73, 0.08, 1.2), (0.91, 0.21, 0.7), (0.14, 0.38, 0.7),
                    (0.39, 0.31, 1.0), (0.64, 0.44, 0.8), (0.87, 0.39, 1.1),
                    (0.07, 0.66, 0.8), (0.31, 0.73, 1.2), (0.57, 0.62, 0.7),
                    (0.82, 0.76, 1.0), (0.19, 0.91, 0.9), (0.68, 0.94, 1.1)
                ]

                for dot in dots {
                    let rect = CGRect(
                        x: size.width * dot.0,
                        y: size.height * dot.1,
                        width: dot.2,
                        height: dot.2
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(SRColor.paperShadow.opacity(0.28)))
                }
            }
        }
        .drawingGroup()
        .ignoresSafeArea()
    }
}

struct BrandWordmark: View {
    var body: some View {
        VStack(spacing: 2) {
            Text("5 More")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(SRColor.charcoal)
                .rotationEffect(.degrees(-1.2))

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [SRColor.yellow, SRColor.orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 150, height: 6)
                .rotationEffect(.degrees(-4))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("5 More")
    }
}

struct CrayonFrame<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(SRColor.blue, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .stroke(SRColor.blue.opacity(0.72), style: StrokeStyle(lineWidth: 2, dash: [22, 2]))
                    .offset(x: 2, y: -2)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .stroke(SRColor.blue.opacity(0.42), lineWidth: 1.5)
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
                    Image(systemName: "camera.fill")
                        .font(.system(size: 29, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityLabel(isBusy ? "Taking photo" : "Take a photo to start")
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
