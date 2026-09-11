import SwiftUI

/// A deliberately branded settings surface. Settings is still practical, but
/// it should feel like it belongs to the little moment parents just captured.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchaseService: PurchaseService
    @ObservedObject var trialStore: TrialUsageStore

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.section) {
                        header

                        BrandedSettingsCard(title: "Your access", image: "SymbolFiveHand", tint: SRColor.yellow) {
                            SettingsLine(title: "Plan", detail: purchaseService.isUnlocked ? "Lifetime" : "Free")

                            if !purchaseService.isUnlocked {
                                SettingsLine(title: "Free moments left", detail: "\(trialStore.remainingCount)")
                            }

                            Button("Restore purchases") {
                                Task { _ = await purchaseService.restore() }
                            }
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(SRColor.orange)
                            .disabled(purchaseService.isWorking)
                            .padding(.top, 2)
                        }

                        BrandedSettingsCard(title: "Start without opening", image: "IconCamera", tint: SRColor.blue) {
                            SettingsHint(text: "Say “Five More Minutes” to Siri.")
                            SettingsHint(text: "Add the button to Control Center or your Lock Screen.")
                            SettingsHint(text: "Use the Action Button, if your iPhone has one.")

                            Link("Choose your own Siri phrase", destination: URL(string: "shortcuts://")!)
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(SRColor.orange)
                                .padding(.top, 2)
                        }

                        BrandedSettingsCard(title: "The little bell", image: "SymbolCompletion", tint: SRColor.yellow) {
                            NavigationLink {
                                AlarmSoundView()
                            } label: {
                                HStack {
                                    Text("Alarm sound")
                                        .foregroundStyle(SRColor.charcoal)
                                    Spacer()
                                    Text("Choose")
                                        .font(.subheadline)
                                        .foregroundStyle(SRColor.orange)
                                }
                                .font(.system(.body, design: .rounded, weight: .semibold))
                            }
                            .buttonStyle(.plain)
                        }

                        BrandedSettingsCard(title: "Your photos", image: "IconMemories", tint: SRColor.blue) {
                            SettingsHint(text: "Photos stay in your Apple Photos library.")
                            SettingsHint(text: "No account and no photo uploads.")
                        }

                        BrandedSettingsCard(title: "About", image: "IconSettings", tint: SRColor.orange) {
                            SettingsLine(title: "Version", detail: "0.1.0")
                            Text("A five-minute timer for a lifetime of memories.")
                                .font(.subheadline)
                                .foregroundStyle(SRColor.muted)
                        }
                    }
                    .padding(.horizontal, Spacing.margin)
                    .padding(.vertical, 18)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(SRColor.orange)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Settings")
                    .font(SRTypography.displayTitle)
                    .foregroundStyle(SRColor.charcoal)
                Text("Keep five more feeling like yours.")
                    .font(.subheadline)
                    .foregroundStyle(SRColor.muted)
            }

            Spacer()

            Button("Done") { dismiss() }
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(SRColor.charcoal)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(SRColor.yellow, in: Capsule())
        }
    }
}

private struct BrandedSettingsCard<Content: View>: View {
    let title: String
    let image: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(image)
                    .renderingMode(image.hasPrefix("Icon") ? .template : .original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 37, height: 37)
                    .foregroundStyle(tint)

                Text(title)
                    .font(SRTypography.action)
                    .foregroundStyle(SRColor.charcoal)
            }

            VStack(alignment: .leading, spacing: 11) {
                content
            }
        }
        .padding(16)
        .background(SRColor.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(tint.opacity(0.34), lineWidth: 2)
        }
        .shadow(color: SRColor.paperShadow.opacity(0.32), radius: 8, y: 4)
    }
}

private struct SettingsLine: View {
    let title: String
    let detail: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(SRColor.charcoal)
            Spacer()
            Text(detail)
                .fontWeight(.bold)
                .foregroundStyle(SRColor.orange)
        }
        .font(.system(.subheadline, design: .rounded))
    }
}

private struct SettingsHint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(SRColor.yellow)
                .frame(width: 7, height: 7)
                .padding(.top, 5)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(SRColor.charcoal)
        }
    }
}
