import AudioToolbox
import AVFoundation
import SwiftUI

/// The cheer library plus bundled alarm clips. This keeps the practical sound
/// picker inside the same hand-drawn world as the rest of Settings.
struct AlarmSoundView: View {
    @AppStorage(AlarmSound.selectionKey) private var selection: String?

    @State private var cheers: [(fileName: String, createdAt: Date)] = []
    @State private var presets: [String] = []
    @State private var playingID: String?
    @State private var player: AVAudioPlayer?
    @State private var showRecorder = false

    private var current: AlarmSound.Resolved {
        AlarmSound.resolve(
            selection: selection,
            presets: presets,
            recordingsNewestFirst: cheers.map(\.fileName)
        )
    }

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.section) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("The little bell")
                            .font(SRTypography.displayTitle)
                            .foregroundStyle(SRColor.charcoal)
                        Text("Choose what plays when five more is over.")
                            .font(.subheadline)
                            .foregroundStyle(SRColor.muted)
                    }

                    SoundCard(title: "Your cheers", image: "SymbolFiveHand", tint: SRColor.yellow) {
                        if cheers.isEmpty {
                            Text("A cheer, a giggle, or a tiny “time’s up!” — save up to five.")
                                .font(.subheadline)
                                .foregroundStyle(SRColor.muted)
                        } else {
                            ForEach(cheers, id: \.fileName) { cheer in
                                soundRow(
                                    id: cheer.fileName,
                                    title: cheerTitle(for: cheer.createdAt),
                                    isSelected: current == .recording(cheer.fileName),
                                    isDeletable: true
                                ) {
                                    play(url: AlarmSound.url(forRecording: cheer.fileName), id: cheer.fileName)
                                } onDelete: {
                                    deleteCheer(cheer.fileName)
                                }
                            }
                        }

                        Button {
                            showRecorder = true
                        } label: {
                            Text(cheers.isEmpty ? "Record your first cheer" : "Record a new cheer")
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(SRColor.orange)
                        .foregroundStyle(.white)
                        .disabled(cheers.count >= AlarmSound.maxRecordings)

                        Text("Up to \(AlarmSound.maxRecordings) cheers are kept (\(cheers.count) now). The newest one becomes the alarm until you choose another.")
                            .font(.caption)
                            .foregroundStyle(SRColor.muted)
                    }

                    SoundCard(title: "Included sounds", image: "SymbolCompletion", tint: SRColor.yellow) {
                        ForEach(presets, id: \.self) { preset in
                            soundRow(
                                id: preset,
                                title: AlarmSound.displayName(for: .preset(preset)),
                                isSelected: current == .preset(preset)
                            ) {
                                play(url: AlarmSound.bundledURL(forPreset: preset), id: preset)
                            }
                        }

                        soundRow(
                            id: AlarmSound.systemID,
                            title: "Default chime",
                            isSelected: current == .system
                        ) {
                            play(url: nil, id: AlarmSound.systemID)
                        }
                    }
                }
                .padding(Spacing.margin)
            }
        }
        .navigationTitle("Alarm sound")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refresh)
        .onDisappear(perform: stopPlayback)
        .sheet(isPresented: $showRecorder) {
            CheerRecorderView { fileName in
                refresh()
                selection = fileName
            }
        }
    }

    private func cheerTitle(for date: Date) -> String {
        "Cheer · " + date.formatted(date: .abbreviated, time: .shortened)
    }

    private func soundRow(
        id: String,
        title: String,
        isSelected: Bool,
        isDeletable: Bool = false,
        playAction: @escaping () -> Void,
        onDelete: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 10) {
            Button {
                selection = id
            } label: {
                HStack(spacing: 9) {
                    CrayonControlMark(kind: isSelected ? .check : .circle, color: isSelected ? SRColor.orange : SRColor.muted)
                        .frame(width: 24, height: 24)
                    Text(title)
                        .foregroundStyle(SRColor.charcoal)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            Button(action: playAction) {
                CrayonControlMark(kind: playingID == id ? .stop : .play, color: SRColor.orange)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Preview \(title)")

            if isDeletable, let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Image("IconTrash")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete \(title)")
            }
        }
        .font(.system(.body, design: .rounded, weight: .semibold))
        .padding(.vertical, 4)
    }

    private func refresh() {
        presets = AlarmSound.bundledPresetNames()
        cheers = AlarmSound.recordingsNewestFirst()
    }

    private func play(url: URL?, id: String) {
        if playingID == id {
            stopPlayback()
            return
        }
        stopPlayback()

        if let url {
            do {
                try AVAudioSession.sharedInstance().setCategory(.ambient)
                try AVAudioSession.sharedInstance().setActive(true)
                player = try AVAudioPlayer(contentsOf: url)
                player?.play()
                playingID = id
            } catch {
                playingID = nil
            }
        } else {
            AudioServicesPlaySystemSound(1005)
            playingID = id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if playingID == id { playingID = nil }
            }
        }
    }

    private func stopPlayback() {
        player?.stop()
        player = nil
        playingID = nil
    }

    private func deleteCheer(_ fileName: String) {
        stopPlayback()
        try? FileManager.default.removeItem(at: AlarmSound.url(forRecording: fileName))
        if selection == fileName { selection = nil }
        refresh()
    }
}

private struct SoundCard<Content: View>: View {
    let title: String
    let image: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                Image(image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 38, height: 38)
                Text(title)
                    .font(SRTypography.action)
                    .foregroundStyle(SRColor.charcoal)
            }

            VStack(alignment: .leading, spacing: 10) {
                content
            }
        }
        .padding(16)
        .background(SRColor.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(tint.opacity(0.34), lineWidth: 2)
        }
    }
}

#Preview {
    NavigationStack {
        AlarmSoundView()
    }
}
