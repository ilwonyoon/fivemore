import Foundation

/// Alarm sound selection: bundled preset clips plus a small library of user
/// recordings ("cheers"). Recordings are kept in Library/Sounds so they can
/// be used by both the foreground alarm and local notifications.
enum AlarmSound {
    /// Stored selection: a preset name, a recording file name, or `system`.
    static let selectionKey = "alarmSoundSelection"
    static let systemID = "system"
    static let presetPrefix = "Alarm"
    static let audioExtensions = ["m4a", "caf", "wav", "mp3"]

    /// A short recording loops more pleasantly when a moment ends.
    static let maxRecordingSeconds = 5

    /// Five keeps the library playful and curated without consuming space.
    static let maxRecordings = 5

    static func isRecordingFile(_ name: String) -> Bool {
        let parts = name.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 2 && audioExtensions.contains(String(parts[1]).lowercased())
    }

    static func isMomentVoiceFile(_ name: String) -> Bool {
        name.hasPrefix(MomentVoiceStore.filePrefix) && isRecordingFile(name)
    }

    /// File base names (without extensions) of bundled `Alarm<Name>` clips.
    static func presetNames(from resourceNames: [String]) -> [String] {
        resourceNames.compactMap { name in
            let parts = name.split(separator: ".", omittingEmptySubsequences: false)
            guard parts.count == 2,
                  parts[0].hasPrefix(presetPrefix),
                  audioExtensions.contains(String(parts[1]).lowercased()) else {
                return nil
            }
            return String(parts[0])
        }
        .sorted()
    }

    /// Returns the oldest recording names that must leave when one new cheer
    /// is saved. The caller performs deletion only after the new file is safe.
    static func evictedAfterAdding(to existingOldestFirst: [String]) -> [String] {
        let overflow = existingOldestFirst.count + 1 - maxRecordings
        guard overflow > 0 else { return [] }
        return Array(existingOldestFirst.prefix(overflow))
    }

    enum Resolved: Equatable {
        case recording(String)
        case preset(String)
        case system
    }

    /// A valid explicit choice wins. If it disappeared, use the newest cheer,
    /// then a bundled clip, then the dependable iOS system tone.
    static func resolve(
        selection: String?,
        presets: [String],
        recordingsNewestFirst: [String]
    ) -> Resolved {
        if let selection {
            if selection == systemID { return .system }
            if recordingsNewestFirst.contains(selection) { return .recording(selection) }
            if presets.contains(selection) { return .preset(selection) }
        }

        if let newest = recordingsNewestFirst.first { return .recording(newest) }
        if let first = presets.first { return .preset(first) }
        return .system
    }

    static func url(forRecording fileName: String, libraryDirectory: URL) -> URL {
        libraryDirectory
            .appendingPathComponent("Sounds", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    static func displayName(for resolved: Resolved) -> String {
        switch resolved {
        case .recording:
            return "Saved cheer"
        case .preset(let name):
            let short = String(name.dropFirst(presetPrefix.count))
            return short.isEmpty ? name : short
        case .system:
            return "Default chime"
        }
    }

    // MARK: - Runtime filesystem helpers

    static var soundsDirectory: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sounds", isDirectory: true)
    }

    static func url(forRecording fileName: String) -> URL {
        soundsDirectory.appendingPathComponent(fileName)
    }

    /// File names and creation dates, newest first.
    static func recordingsNewestFirst() -> [(fileName: String, createdAt: Date)] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: soundsDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )) ?? []

        return files
            .filter { isRecordingFile($0.lastPathComponent) && !isMomentVoiceFile($0.lastPathComponent) }
            .compactMap { url in
                let date = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
                return date.map { (url.lastPathComponent, $0) }
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    static func bundledPresetNames() -> [String] {
        let found = audioExtensions.flatMap {
            Bundle.main.urls(forResourcesWithExtension: $0, subdirectory: nil) ?? []
        }.map(\.lastPathComponent)
        return presetNames(from: found)
    }

    static func bundledURL(forPreset name: String) -> URL? {
        for ext in audioExtensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    static func bundledFileName(forPreset name: String) -> String? {
        bundledURL(forPreset: name)?.lastPathComponent
    }

    static func currentResolved() -> Resolved {
        resolve(
            selection: UserDefaults.standard.string(forKey: selectionKey),
            presets: bundledPresetNames(),
            recordingsNewestFirst: recordingsNewestFirst().map(\.fileName)
        )
    }
}
