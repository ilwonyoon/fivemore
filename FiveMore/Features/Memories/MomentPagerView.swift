import AVFoundation
import SwiftData
import SwiftUI

/// Full-screen, swipeable browser for saved moments.
///
/// Opened by tapping a Memories thumbnail; swiping left and right moves through
/// the same newest-first order the grid uses.
struct MomentPagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let moments: [Moment]
    let initialMoment: Moment

    @State private var selection: PersistentIdentifier
    @State private var showDeleteConfirm = false

    init(moments: [Moment], initialMoment: Moment) {
        self.moments = moments
        self.initialMoment = initialMoment
        _selection = State(initialValue: initialMoment.persistentModelID)
    }

    private var currentMoment: Moment? {
        moments.first { $0.persistentModelID == selection }
    }

    var body: some View {
        ZStack {
            PaperBackground()

            TabView(selection: $selection) {
                ForEach(moments) { moment in
                    MomentPage(moment: moment)
                        .tag(moment.persistentModelID)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(SRColor.paper, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image("IconTrash")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 23, height: 23)
                }
                .accessibilityLabel("Delete this moment")
            }
        }
        .alert("Delete this moment?", isPresented: $showDeleteConfirm) {
            Button("Delete moment", role: .destructive) {
                deleteCurrentMoment()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes it from Memories. The photo stays in your photo library.")
        }
        .safeAreaInset(edge: .bottom) {
            Text(positionText)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SRColor.muted)
                .monospacedDigit()
                .padding(.bottom, 6)
                .accessibilityLabel(positionAccessibilityLabel)
        }
    }

    /// Removes the moment from Memories and steps back to the grid. The photo
    /// itself stays in the device library — deleting a memory should never
    /// destroy the family's original.
    private func deleteCurrentMoment() {
        guard let currentMoment else { return }
        if let fileName = currentMoment.alarmRecordingFileName {
            try? FileManager.default.removeItem(at: MomentVoiceStore.url(for: fileName))
        }
        modelContext.delete(currentMoment)
        try? modelContext.save()
        dismiss()
    }

    private var navigationTitle: String {
        guard let currentMoment else { return "Moment" }
        return currentMoment.capturedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var positionText: String {
        guard let index = moments.firstIndex(where: { $0.persistentModelID == selection }) else {
            return ""
        }
        return "\(index + 1) of \(moments.count)"
    }

    private var positionAccessibilityLabel: String {
        guard let index = moments.firstIndex(where: { $0.persistentModelID == selection }) else {
            return ""
        }
        return "Moment \(index + 1) of \(moments.count)"
    }
}

/// One page of the pager: the photo in its crayon frame plus its details.
private struct MomentPage: View {
    @Environment(\.modelContext) private var modelContext
    let moment: Moment

    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var voicePlayer: AVAudioPlayer?
    @State private var showVoiceDeleteConfirm = false

    var body: some View {
        VStack(spacing: 18) {
            GeometryReader { proxy in
                // Same portrait frame as capture (0.915), not a square.
                let frameWidth = min(proxy.size.width - 40, 360)
                let frameHeight = frameWidth / 0.915

                CrayonFrame {
                    photo
                        .frame(width: frameWidth, height: frameHeight)
                        .clipped()
                }
                .frame(width: frameWidth, height: frameHeight)
                .frame(maxWidth: .infinity)
            }
            .frame(height: min(UIScreen.main.bounds.width - 40, 360) / 0.915)

            details

            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        .task {
            image = await PhotoLibraryService.shared.image(
                localIdentifier: moment.photoLocalIdentifier,
                targetSize: CGSize(width: 1_400, height: 1_400)
            )
            isLoading = false
        }
        .alert("Remove this cheer?", isPresented: $showVoiceDeleteConfirm) {
            Button("Remove cheer", role: .destructive, action: removeVoice)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The photo and this 5 More moment will stay.")
        }
    }

    @ViewBuilder
    private var photo: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .accessibilityLabel("The photo saved for this 5 More moment")
        } else {
            ZStack {
                SRColor.paperShadow.opacity(0.35)

                if isLoading {
                    ProgressView()
                        .tint(SRColor.muted)
                } else {
                    VStack(spacing: 10) {
                        Image("IconMemories")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                        Text("This photo is no longer in your library")
                            .font(.callout)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(SRColor.muted)
                    .padding(24)
                }
            }
        }
    }

    private var details: some View {
        VStack(spacing: 6) {
            Text(durationText)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(SRColor.charcoal)

            Text(moment.capturedAt.formatted(date: .complete, time: .shortened))
                .font(.footnote)
                .foregroundStyle(SRColor.muted)
                .multilineTextAlignment(.center)

            if let voiceURL {
                Button {
                    playVoice(voiceURL)
                } label: {
                    HStack(spacing: 7) {
                        CrayonControlMark(kind: .play, color: SRColor.orange)
                            .frame(width: 20, height: 20)
                        Text("Play our 5-second cheer")
                    }
                }
                .buttonStyle(.plain)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(SRColor.orange)
                .padding(.top, 4)
                .accessibilityLabel("Play the cheer saved with this moment")

                Button("Remove cheer", role: .destructive) {
                    showVoiceDeleteConfirm = true
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(SRColor.orange)
            }
        }
        .padding(.horizontal, 24)
    }

    private var durationText: String {
        let seconds = moment.actualDurationSeconds
        let minutes = seconds / 60
        let remainder = seconds % 60

        if moment.rounds > 1 {
            return "\(minutes) minutes across \(moment.rounds) rounds"
        }

        switch moment.endReason {
        case .endedEarly:
            return "Ended early after \(minutes)m \(remainder)s"
        case .interrupted:
            return "Interrupted after \(minutes)m \(remainder)s"
        case .completed, .none:
            return "A full \(minutes) minutes"
        }
    }

    private var voiceURL: URL? {
        guard let fileName = moment.alarmRecordingFileName else { return nil }
        let url = MomentVoiceStore.url(for: fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func playVoice(_ url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient)
            try AVAudioSession.sharedInstance().setActive(true)
            voicePlayer = try AVAudioPlayer(contentsOf: url)
            voicePlayer?.play()
        } catch {
            voicePlayer = nil
        }
    }

    private func removeVoice() {
        voicePlayer?.stop()
        if let fileName = moment.alarmRecordingFileName {
            try? FileManager.default.removeItem(at: MomentVoiceStore.url(for: fileName))
        }
        moment.alarmRecordingFileName = nil
        moment.audioDurationSeconds = nil
        moment.audioByteCount = nil
        try? modelContext.save()
    }
}
