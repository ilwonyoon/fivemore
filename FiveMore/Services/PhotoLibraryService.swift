@preconcurrency import Photos
import UIKit

enum PhotoLibraryError: LocalizedError {
    case addPermissionDenied
    case saveFailed
    case missingIdentifier

    var errorDescription: String? {
        switch self {
        case .addPermissionDenied:
            "Photo access is off. Allow Five More Minutes to add photos in Settings."
        case .saveFailed:
            "The photo could not be saved to your library."
        case .missingIdentifier:
            "The saved photo could not be linked to this moment."
        }
    }
}

@MainActor
final class PhotoLibraryService {
    static let shared = PhotoLibraryService()

    private init() {}

    var readAuthorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestReadAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    func savePhoto(data: Data) async throws -> String {
        let existingStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let status: PHAuthorizationStatus

        if existingStatus == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        } else {
            status = existingStatus
        }

        guard status == .authorized || status == .limited else {
            throw PhotoLibraryError.addPermissionDenied
        }

        return try await Self.performSave(data: data)
    }

    nonisolated private static func performSave(data: Data) async throws -> String {
        let identifierBox = PhotoIdentifierBox()

        return try await withCheckedThrowingContinuation { continuation in
            let changes: @Sendable () -> Void = {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
                identifierBox.value = request.placeholderForCreatedAsset?.localIdentifier
            }

            let completion: @Sendable (Bool, Error?) -> Void = { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if !success {
                    continuation.resume(throwing: PhotoLibraryError.saveFailed)
                } else if let localIdentifier = identifierBox.value {
                    continuation.resume(returning: localIdentifier)
                } else {
                    continuation.resume(throwing: PhotoLibraryError.missingIdentifier)
                }
            }

            PHPhotoLibrary.shared().performChanges(changes, completionHandler: completion)
        }
    }

    func image(
        localIdentifier: String,
        targetSize: CGSize,
        allowsNetworkAccess: Bool = true
    ) async -> UIImage? {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = assets.firstObject else { return nil }

        let options = PHImageRequestOptions()
        options.deliveryMode = allowsNetworkAccess ? .highQualityFormat : .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = allowsNetworkAccess

        return await withCheckedContinuation { continuation in
            var hasResumed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                guard !hasResumed else { return }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                let error = info?[PHImageErrorKey] as? Error

                if isCancelled || error != nil {
                    hasResumed = true
                    continuation.resume(returning: nil)
                } else if !isDegraded {
                    hasResumed = true
                    continuation.resume(returning: image)
                }
            }
        }
    }
}

private final class PhotoIdentifierBox: @unchecked Sendable {
    var value: String?
}
