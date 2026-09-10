import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchaseService: PurchaseService
    @ObservedObject var trialStore: TrialUsageStore

    var body: some View {
        NavigationStack {
            List {
                Section("Access") {
                    LabeledContent("Plan", value: purchaseService.isUnlocked ? "Lifetime" : "Free")

                    if !purchaseService.isUnlocked {
                        LabeledContent("Free moments left", value: "\(trialStore.remainingCount)")
                    }

                    Button("Restore purchases") {
                        Task { _ = await purchaseService.restore() }
                    }
                    .disabled(purchaseService.isWorking)
                }

                Section {
                    Label("Say “Five More Minutes” to Siri.", systemImage: "mic.fill")
                    Label("Add the button to Control Center or your Lock Screen.", systemImage: "switch.2")
                    Label("Assign it to the Action Button, if your iPhone has one.", systemImage: "button.horizontal.top.press")

                    Link(destination: URL(string: "shortcuts://")!) {
                        Label("Choose your own Siri phrase", systemImage: "text.bubble")
                    }
                } header: {
                    Text("Start without opening the app")
                } footer: {
                    Text("Open the Shortcuts app to record a phrase that suits you — “오분만 더”, “five more”, anything you already say.")
                }

                Section("Your photos") {
                    Label("Photos stay in your Apple Photos library.", systemImage: "photo")
                    Label("No account and no photo uploads.", systemImage: "lock.shield")
                }

                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                    Text("A five-minute timer for a lifetime of memories.")
                        .foregroundStyle(SRColor.muted)
                }

#if DEBUG
                Section("Development") {
                    Button("Reset free uses", role: .destructive) {
                        trialStore.resetForDevelopment()
                    }
                }
#endif
            }
            .scrollContentBackground(.hidden)
            .background(SRColor.paper)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(SRColor.orange)
    }
}

