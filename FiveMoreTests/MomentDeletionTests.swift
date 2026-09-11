import Foundation
import SwiftData
import Testing
@testable import FiveMore

/// Covers moment deletion: removing a memory drops its record from the store
/// while (by design) leaving the device photo library untouched.
struct MomentDeletionTests {

    @Test func deletingAMomentRemovesItFromTheStore() throws {
        let container = try ModelContainer(
            for: Moment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        context.insert(Moment(photoLocalIdentifier: "test-photo"))
        try context.save()

        let descriptor = FetchDescriptor<Moment>()
        #expect(try context.fetch(descriptor).count == 1)

        context.delete(try context.fetch(descriptor)[0])
        try context.save()

        #expect(try context.fetch(descriptor).isEmpty)
    }

    @Test func otherMomentsSurviveADeletion() throws {
        let container = try ModelContainer(
            for: Moment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        context.insert(Moment(photoLocalIdentifier: "keep-me"))
        context.insert(Moment(photoLocalIdentifier: "delete-me"))
        try context.save()

        let descriptor = FetchDescriptor<Moment>(
            predicate: #Predicate { $0.photoLocalIdentifier == "delete-me" }
        )
        for moment in try context.fetch(descriptor) {
            context.delete(moment)
        }
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<Moment>())
        #expect(remaining.count == 1)
        #expect(remaining[0].photoLocalIdentifier == "keep-me")
    }
}
