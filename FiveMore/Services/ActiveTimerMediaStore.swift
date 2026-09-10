import UIKit

@MainActor
final class ActiveTimerMediaStore {
    static let shared = ActiveTimerMediaStore()

    private let fileURL: URL

    private init() {
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        fileURL = cacheDirectory.appendingPathComponent("five-more-active-moment.jpg")
    }

    func save(_ data: Data) throws {
        try data.write(to: fileURL, options: .atomic)
    }

    func loadImage() -> UIImage? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}

