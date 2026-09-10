import SwiftData
import SwiftUI

@main
struct FiveMoreApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: Moment.self)
        } catch {
            fatalError("Unable to create the local 5 More store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}

