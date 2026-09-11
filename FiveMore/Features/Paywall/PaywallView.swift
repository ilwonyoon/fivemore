import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchaseService: PurchaseService

    let onUnlocked: () -> Void

    var body: some View {
        ZStack {
            PaperBackground()

            VStack(spacing: 24) {
                Spacer()

                Image("SymbolFiveHand")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 138, height: 138)
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text("Your first \(TrialUsageStore.freeLimit) moments\nare saved.")
                        .font(SRTypography.paywallTitle)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(SRColor.charcoal)

                    Text("Keep capturing little moments with one purchase.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(SRColor.muted)
                        .padding(.horizontal, 28)

                    if let regularPrice = purchaseService.regularPriceText {
                        HStack(spacing: 7) {
                            Text(regularPrice)
                                .strikethrough()
                                .foregroundStyle(SRColor.muted)

                            Text("Launch price")
                                .fontWeight(.bold)
                                .foregroundStyle(SRColor.orange)
                        }
                        .font(.subheadline)
                        .padding(.top, 2)
                    }
                }

                VStack(spacing: 12) {
                    Button {
                        Task {
                            if await purchaseService.purchase() {
                                onUnlocked()
                            }
                        }
                    } label: {
                        HStack {
                            if purchaseService.isWorking {
                                ProgressView().tint(SRColor.charcoal)
                            }
                            Text(unlockButtonTitle)
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(SRColor.yellow)
                    .foregroundStyle(SRColor.charcoal)
                    .disabled(purchaseService.product == nil || purchaseService.isWorking)

                    VStack(spacing: 3) {
                        Text("One-time purchase. No subscription.")

                        Text("Shared with your Family Sharing group")
                    }
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(SRColor.muted)

                    Button("Restore purchases") {
                        Task {
                            if await purchaseService.restore() {
                                onUnlocked()
                            }
                        }
                    }
                    .disabled(purchaseService.isWorking)

                    Button("Not now") {
                        dismiss()
                    }
                    .foregroundStyle(SRColor.muted)
                }
                .padding(.horizontal, 28)

                if purchaseService.product == nil {
                    Text("The Store product isn’t available yet. Try again shortly.")
                        .font(.caption)
                        .foregroundStyle(SRColor.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
        }
        .alert("App Store", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchaseService.errorMessage ?? "Please try again.")
        }
        .task {
            if purchaseService.product == nil {
                await purchaseService.loadProduct()
            }
        }
    }

    private var unlockButtonTitle: String {
        if let product = purchaseService.product {
            "Unlock forever · \(product.displayPrice)"
        } else {
            "Loading price…"
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { purchaseService.errorMessage != nil },
            set: { isPresented in
                if !isPresented { purchaseService.errorMessage = nil }
            }
        )
    }
}
