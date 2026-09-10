import Foundation
import UIKit

/// Saves a captured photo to the user's library and returns its local
/// identifier.
///
/// PRD §9 requires the capture rules to sit behind a protocol so they can run
/// in tests and previews without a camera or a photo library.
@MainActor
protocol PhotoSaving {
    func savePhoto(data: Data) async throws -> String
    func image(localIdentifier: String, targetSize: CGSize, allowsNetworkAccess: Bool) async -> UIImage?
}

extension PhotoLibraryService: PhotoSaving {}

/// Persists the timer that is currently running, so it survives a relaunch.
@MainActor
protocol ActiveTimerPersisting {
    func load() -> ActiveTimerRecord?
    func save(_ record: ActiveTimerRecord)
    func clear()
}

extension ActiveTimerStore: ActiveTimerPersisting {}

/// Keeps the in-progress photo on disk while a timer is running.
@MainActor
protocol ActiveTimerMediaPersisting {
    func save(_ data: Data) throws
    func loadImage() -> UIImage?
    func clear()
}

extension ActiveTimerMediaStore: ActiveTimerMediaPersisting {}
