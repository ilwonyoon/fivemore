import AVFoundation
import SwiftUI

/// Records one short cheer for the alarm library. The asynchronous permission
/// API is important here: the old callback path could trap on a real device.
struct CheerRecorderView: View {
    @Environment(\.dismiss) private var dismiss

    var onSaved: (String) -> Void = { _ in }

    @State private var recorder: AVAudioRecorder?
    @State private var recordElapsed: TimeInterval = 0
    @State private var recordTimer: Timer?
    @State private var previewURL: URL?
    @State private var previewPlayer: AVAudioPlayer?
    @State private var micDenied = false

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()

                VStack(spacing: Spacing.section) {
                    Image("SymbolCompletion")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 82, height: 82)

                    VStack(spacing: 7) {
                        Text("Record a cheer")
                            .font(SRTypography.displayTitle)
                            .foregroundStyle(SRColor.charcoal)
                        Text("Up to \(AlarmSound.maxRecordingSeconds) seconds — a cheer, a giggle, or a tiny “time’s up!”")
                            .font(.callout)
                            .foregroundStyle(SRColor.muted)
                            .multilineTextAlignment(.center)
                    }

                    recorderControls

                    if micDenied {
                        Text("Microphone is off. Allow it in Settings to record.")
                            .font(.caption)
                            .foregroundStyle(SRColor.orange)
                    }

                    Spacer(minLength: 0)
                }
                .padding(Spacing.section)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(SRColor.orange)
                }
            }
        }
        .tint(SRColor.orange)
        .onDisappear {
            previewPlayer?.stop()
            stopRecording(keep: false)
        }
    }

    @ViewBuilder
    private var recorderControls: some View {
        if recorder != nil {
            VStack(spacing: Spacing.margin) {
                Text("\(Int(recordElapsed))s")
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(SRColor.charcoal)

                Button("Stop recording") {
                    stopRecording(keep: true)
                }
                .buttonStyle(.borderedProminent)
                .tint(SRColor.orange)
                .foregroundStyle(.white)
            }
        } else if let previewURL {
            VStack(spacing: 12) {
                Button {
                    playPreview(url: previewURL)
                } label: {
                    HStack(spacing: 9) {
                        CrayonControlMark(kind: .play, color: SRColor.orange)
                            .frame(width: 22, height: 22)
                        Text("Play my take")
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.bordered)
                .tint(SRColor.orange)

                Button {
                    keepTake(from: previewURL)
                } label: {
                    HStack(spacing: 9) {
                        CrayonControlMark(kind: .check, color: SRColor.charcoal)
                            .frame(width: 22, height: 22)
                        Text("Keep this cheer")
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(SRColor.yellow)
                .foregroundStyle(SRColor.charcoal)

                Button("Record again", role: .destructive) {
                    self.previewURL = nil
                }
            }
        } else {
            Button("Start recording") {
                Task { await startRecording() }
            }
            .buttonStyle(.borderedProminent)
            .tint(SRColor.orange)
            .foregroundStyle(.white)
        }
    }

    private func playPreview(url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient)
            try AVAudioSession.sharedInstance().setActive(true)
            previewPlayer = try AVAudioPlayer(contentsOf: url)
            previewPlayer?.play()
        } catch {
            previewPlayer = nil
        }
    }

    private func startRecording() async {
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            micDenied = true
            return
        }
        micDenied = false

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory.appendingPathComponent("CheerTake.m4a")
            try? FileManager.default.removeItem(at: url)

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 24_000,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            ]
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.record()
            recordElapsed = 0

            recordTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
                Task { @MainActor in
                    recordElapsed = recorder?.currentTime ?? 0
                    if recordElapsed >= Double(AlarmSound.maxRecordingSeconds) {
                        stopRecording(keep: true)
                    }
                }
            }
        } catch {
            recorder = nil
        }
    }

    private func stopRecording(keep: Bool) {
        recordTimer?.invalidate()
        recordTimer = nil

        if keep, let url = recorder?.url {
            recorder?.stop()
            previewURL = url
        } else if let recorder {
            recorder.stop()
            recorder.deleteRecording()
        }
        recorder = nil
        recordElapsed = 0
    }

    private func keepTake(from url: URL) {
        do {
            let existingOldestFirst = Array(AlarmSound.recordingsNewestFirst().map(\.fileName).reversed())
            let fileName = UUID().uuidString.lowercased() + ".m4a"
            let destination = AlarmSound.url(forRecording: fileName)
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try FileManager.default.moveItem(at: url, to: destination)

            for victim in AlarmSound.evictedAfterAdding(to: existingOldestFirst) {
                try? FileManager.default.removeItem(at: AlarmSound.url(forRecording: victim))
            }

            previewURL = nil
            onSaved(fileName)
            dismiss()
        } catch {
            previewURL = nil
        }
    }
}

#Preview {
    CheerRecorderView()
}
