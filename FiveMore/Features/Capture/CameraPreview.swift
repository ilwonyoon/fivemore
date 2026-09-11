import AVFoundation
import SwiftUI

struct CameraPreview: View {
    let session: AVCaptureSession?

    var body: some View {
#if targetEnvironment(simulator)
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.86, blue: 0.69),
                    Color(red: 0.72, green: 0.84, blue: 0.73)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 16) {
                Image("SymbolFiveHand")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 122, height: 122)
                    .shadow(color: .white.opacity(0.35), radius: 8, y: 4)

                Text("Camera preview")
                    .font(.headline)
                    .foregroundStyle(SRColor.charcoal.opacity(0.72))

                Text("Simulator demo")
                    .font(.caption)
                    .foregroundStyle(SRColor.charcoal.opacity(0.55))
            }
        }
        .accessibilityLabel("Simulated camera preview")
#else
        if let session {
            CameraPreviewRepresentable(session: session)
                .accessibilityLabel("Live camera preview")
        } else {
            VStack(spacing: 12) {
                Image("IconCamera")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                Text("Camera unavailable")
                    .font(.headline)
            }
            .foregroundStyle(SRColor.muted)
        }
#endif
    }
}

#if !targetEnvironment(simulator)
private struct CameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected AVCaptureVideoPreviewLayer")
        }
        return previewLayer
    }
}
#endif
