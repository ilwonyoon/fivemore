import Foundation
import Testing
@testable import FiveMore

/// Covers discovery, selection and bounded storage of the cheer library.
struct AlarmSoundTests {
    @Test func listsOnlyAlarmPrefixedAudio() {
        let names = AlarmSound.presetNames(from: [
            "AlarmGentle.m4a", "AlarmPlayful.WAV", "CompletionChime.m4a",
            "AlarmNotes.txt", "AlarmNoExtension", "Alarm.Two.Dots.m4a",
        ])
        #expect(names == ["AlarmGentle", "AlarmPlayful"])
    }

    @Test func sortsPresetsForAStablePicker() {
        #expect(AlarmSound.presetNames(from: ["AlarmSunrise.m4a", "AlarmGentle.m4a"]) == ["AlarmGentle", "AlarmSunrise"])
    }

    @Test func recognizesRecordingFiles() {
        #expect(AlarmSound.isRecordingFile("8E2A.m4a"))
        #expect(!AlarmSound.isRecordingFile("notes.txt"))
        #expect(!AlarmSound.isRecordingFile("noextension"))
    }

    @Test func recordingURLLivesInLibrarySounds() {
        let library = URL(fileURLWithPath: "/tmp/Library", isDirectory: true)
        #expect(AlarmSound.url(forRecording: "abc.m4a", libraryDirectory: library).path == "/tmp/Library/Sounds/abc.m4a")
    }

    @Test func evictsOnlyTheOldestWhenFull() {
        #expect(AlarmSound.evictedAfterAdding(to: ["a.m4a", "b.m4a"]) == [])
        let full = (1...AlarmSound.maxRecordings).map { "\($0).m4a" }
        #expect(AlarmSound.evictedAfterAdding(to: full) == ["1.m4a"])
    }

    @Test func recordingCapStaysSmallAndLoopFriendly() {
        #expect(AlarmSound.maxRecordingSeconds > 0)
        #expect(AlarmSound.maxRecordingSeconds <= 15)
        #expect(AlarmSound.maxRecordings == 5)
    }

    @Test func honorsValidChoices() {
        #expect(AlarmSound.resolve(selection: "AlarmGentle", presets: ["AlarmGentle"], recordingsNewestFirst: ["x.m4a"]) == .preset("AlarmGentle"))
        #expect(AlarmSound.resolve(selection: "x.m4a", presets: ["AlarmGentle"], recordingsNewestFirst: ["x.m4a", "y.m4a"]) == .recording("x.m4a"))
        #expect(AlarmSound.resolve(selection: "system", presets: ["AlarmGentle"], recordingsNewestFirst: ["x.m4a"]) == .system)
    }

    @Test func fallsBackToNewestAvailableSound() {
        #expect(AlarmSound.resolve(selection: "AlarmGone", presets: ["AlarmGentle"], recordingsNewestFirst: ["x.m4a"]) == .recording("x.m4a"))
        #expect(AlarmSound.resolve(selection: "gone.m4a", presets: ["AlarmGentle"], recordingsNewestFirst: []) == .preset("AlarmGentle"))
        #expect(AlarmSound.resolve(selection: "gone.m4a", presets: [], recordingsNewestFirst: []) == .system)
    }

    @Test func defaultsToTheNewestCheer() {
        #expect(AlarmSound.resolve(selection: nil, presets: ["AlarmGentle"], recordingsNewestFirst: ["new.m4a", "old.m4a"]) == .recording("new.m4a"))
    }

    @Test func displayNamesStayFriendly() {
        #expect(AlarmSound.displayName(for: .preset("AlarmGentle")) == "Gentle")
        #expect(AlarmSound.displayName(for: .recording("x.m4a")) == "Saved cheer")
        #expect(AlarmSound.displayName(for: .system) == "Default chime")
    }

    @Test func momentVoiceFilesStaySeparateFromReusableCheers() {
        let name = MomentVoiceStore.fileName(for: UUID(uuidString: "A0A0A0A0-0000-0000-0000-000000000000")!)
        #expect(name == "MomentVoice-a0a0a0a0-0000-0000-0000-000000000000.m4a")
        #expect(MomentVoiceStore.isMomentVoiceFile(name))
        #expect(!AlarmSound.isMomentVoiceFile("my-cheer.m4a"))
        #expect(!AlarmSound.isRecordingFile("not-audio.txt"))
    }
}
