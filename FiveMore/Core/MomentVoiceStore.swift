import Foundation

/// Compact, local-only voice clips attached to individual Moments. Files stay
/// in Library/Sounds so iOS can also play the active moment's clip in a local
/// notification. They are intentionally distinct from reusable Cheers.
enum MomentVoiceStore {
    static let filePrefix = "MomentVoice-"
    static let maximumClipCount = 200
    static let maximumBytes = 10 * 1_024 * 1_024

    static func fileName(for momentID: UUID) -> String {
        "\(filePrefix)\(momentID.uuidString.lowercased()).m4a"
    }

    static func url(for fileName: String) -> URL {
        AlarmSound.soundsDirectory.appendingPathComponent(fileName)
    }

    static func usage() -> (count: Int, bytes: Int) {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: AlarmSound.soundsDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        )) ?? []
        let voices = files.filter { isMomentVoiceFile($0.lastPathComponent) }
        let bytes = voices.reduce(0) { total, url in
            total + ((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        return (voices.count, bytes)
    }

    static func canSave(estimatedBytes: Int = 32_000) -> Bool {
        let current = usage()
        return current.count < maximumClipCount && current.bytes + estimatedBytes <= maximumBytes
    }

    static func isMomentVoiceFile(_ fileName: String) -> Bool {
        fileName.hasPrefix(filePrefix) && AlarmSound.isRecordingFile(fileName)
    }
}
