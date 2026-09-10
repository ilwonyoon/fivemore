import Photos
import SwiftData
import SwiftUI

struct MemoriesView: View {
    @Query(sort: \Moment.capturedAt, order: .reverse) private var moments: [Moment]
    @State private var authorizationStatus = PhotoLibraryService.shared.readAuthorizationStatus

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: 3
    )

    private var canReadPhotos: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()

                if moments.isEmpty {
                    ContentUnavailableView {
                        Label("No moments yet", systemImage: "hand.raised")
                    } description: {
                        Text("Your 5 More photos will collect here.")
                    }
                } else if !canReadPhotos {
                    permissionView
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(moments) { moment in
                                NavigationLink(value: moment) {
                                    MomentThumbnail(moment: moment)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(12)
                    }
                }
            }
            .navigationTitle("Our 5 More")
            .toolbarBackground(SRColor.paper, for: .navigationBar)
            .navigationDestination(for: Moment.self) { moment in
                MomentPagerView(moments: moments, initialMoment: moment)
            }
        }
        .tint(SRColor.orange)
    }

    private var permissionView: some View {
        ContentUnavailableView {
            Label("See your saved moments", systemImage: "photo.on.rectangle.angled")
        } description: {
            Text("Allow photo access to display the 5 More photos already saved in your library.")
        } actions: {
            Button("Continue") {
                Task {
                    authorizationStatus = await PhotoLibraryService.shared.requestReadAuthorization()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(SRColor.charcoal)
        }
    }
}

private struct MomentThumbnail: View {
    let moment: Moment

    @State private var image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(SRColor.paperShadow.opacity(0.38))

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(SRColor.muted)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(moment.capturedAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundStyle(SRColor.muted)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("5 More moment from \(moment.capturedAt.formatted(date: .long, time: .shortened))")
        .task(id: moment.photoLocalIdentifier) {
            image = await PhotoLibraryService.shared.image(
                localIdentifier: moment.photoLocalIdentifier,
                targetSize: CGSize(width: 360, height: 360),
                allowsNetworkAccess: false
            )
        }
    }
}

#Preview {
    MemoriesView()
        .modelContainer(for: Moment.self, inMemory: true)
}

