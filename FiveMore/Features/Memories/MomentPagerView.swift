import SwiftData
import SwiftUI

/// Full-screen, swipeable browser for saved moments.
///
/// Opened by tapping a Memories thumbnail; swiping left and right moves through
/// the same newest-first order the grid uses.
struct MomentPagerView: View {
    let moments: [Moment]
    let initialMoment: Moment

    @State private var selection: PersistentIdentifier

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
        .safeAreaInset(edge: .bottom) {
            Text(positionText)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SRColor.muted)
                .monospacedDigit()
                .padding(.bottom, 6)
                .accessibilityLabel(positionAccessibilityLabel)
        }
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
    let moment: Moment

    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 18) {
            GeometryReader { proxy in
                let side = min(proxy.size.width - 40, 360)

                CrayonFrame {
                    photo
                        .frame(width: side, height: side)
                        .clipped()
                }
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity)
            }
            .frame(height: min(UIScreen.main.bounds.width - 40, 360))

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
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: 40))
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
}
