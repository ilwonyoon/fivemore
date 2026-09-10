import Foundation

struct ActiveTimerRecord: Codable, Equatable {
    let momentID: UUID
    let photoLocalIdentifier: String
    let startedAt: Date
    let endsAt: Date
}

@MainActor
final class ActiveTimerStore {
    static let shared = ActiveTimerStore()

    private let defaults = UserDefaults.standard
    private let key = "five-more.active-timer"

    private init() {
        if LaunchFlags.shouldResetState {
            clear()
        }
    }

    func load() -> ActiveTimerRecord? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ActiveTimerRecord.self, from: data)
    }

    func save(_ record: ActiveTimerRecord) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}

