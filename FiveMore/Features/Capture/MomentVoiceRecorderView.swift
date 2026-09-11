import AVFoundation
import SwiftUI

/// Optional five-second voice memory for the moment currently on the timer.
/// It is a separate file from reusable alarm Cheers and never changes them.
struct MomentVoiceRecorderView: View {
    @Environment(\.dismiss) private var dismiss
    let momentID: UUID
    let onSaved: (String, Double, Int) -> Void

    @State private var recorder: AVAudioRecorder?
    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer?
    @State private var previewURL: URL?
    @State private var player: AVAudioPlayer?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                VStack(spacing: Spacing.section) {
                    Image("SymbolFiveHand")
                        .resizable().scaledToFit().frame(width: 88, height: 88)
                    Text("Our 5-second cheer")
                        .font(SRTypography.displayTitle)
                        .foregroundStyle(SRColor.charcoal)
                    Text("A tiny “five is up!” becomes part of this moment.")
                        .font(.callout).foregroundStyle(SRColor.muted)
                        .multilineTextAlignment(.center)

                    controls

                    if let errorMessage {
                        Text(errorMessage).font(.caption).foregroundStyle(SRColor.orange)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
                .padding(Spacing.section)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }.foregroundStyle(SRColor.orange)
                }
            }
        }
        .onDisappear {
            player?.stop()
            stopRecording(keep: false)
        }
    }

    @ViewBuilder private var controls: some View {
        if recorder != nil {
            VStack(spacing: Spacing.margin) {
                Text("\(Int(elapsed))s")
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .monospacedDigit().foregroundStyle(SRColor.charcoal)
                Button("Stop recording") { stopRecording(keep: true) }
                    .buttonStyle(.borderedProminent).tint(SRColor.orange).foregroundStyle(.white)
            }
        } else if let previewURL {
            VStack(spacing: 12) {
                Button {
                    playPreview(previewURL)
                } label: {
                    HStack { CrayonControlMark(kind: .play, color: SRColor.orange).frame(width: 22, height: 22); Text("Play our cheer") }
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.bordered).tint(SRColor.orange)
                Button {
                    save(previewURL)
                } label: {
                    HStack { CrayonControlMark(kind: .check, color: SRColor.charcoal).frame(width: 22, height: 22); Text("Attach to this moment") }
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent).tint(SRColor.yellow).foregroundStyle(SRColor.charcoal)
                Button("Record again", role: .destructive) { self.previewURL = nil }
            }
        } else {
            Button("Start recording") { Task { await startRecording() } }
                .buttonStyle(.borderedProminent).tint(SRColor.orange).foregroundStyle(.white)
        }
    }

    private func startRecording() async {
        guard MomentVoiceStore.canSave() else {
            errorMessage = "Voice memories are full. Remove an older one in Memories to add another."
            return
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            errorMessage = "Microphone is off. Allow it in Settings to record."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
            try session.setActive(true)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("MomentVoiceTake.m4a")
            try? FileManager.default.removeItem(at: url)
            recorder = try AVAudioRecorder(url: url, settings: [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 24_000,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            ])
            recorder?.record()
            elapsed = 0
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                Task { @MainActor in
                    elapsed = recorder?.currentTime ?? 0
                    if elapsed >= Double(AlarmSound.maxRecordingSeconds) { stopRecording(keep: true) }
                }
            }
        } catch {
            recorder = nil
            errorMessage = "Couldn’t start recording. Please try again."
        }
    }

    private func stopRecording(keep: Bool) {
        timer?.invalidate(); timer = nil
        if keep, let url = recorder?.url { recorder?.stop(); previewURL = url }
        else if let recorder { recorder.stop(); recorder.deleteRecording() }
        recorder = nil; elapsed = 0
    }

    private func playPreview(_ url: URL) {
        do { player = try AVAudioPlayer(contentsOf: url); player?.play() } catch { errorMessage = "Couldn’t play this recording." }
    }

    private func save(_ source: URL) {
        do {
            let name = MomentVoiceStore.fileName(for: momentID)
            let destination = MomentVoiceStore.url(for: name)
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: source, to: destination)
            let bytes = ((try? destination.resourceValues(forKeys: [.fileSizeKey]))?.fileSize) ?? 0
            let duration = (try? AVAudioPlayer(contentsOf: destination).duration) ?? 0
            onSaved(name, duration, bytes)
            dismiss()
        } catch {
            errorMessage = "Couldn’t save this cheer. Please try again."
        }
    }
}
