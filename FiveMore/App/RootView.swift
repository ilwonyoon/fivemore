import SwiftUI

struct RootView: View {
    private enum Destination {
        case home
        case memories
    }

    @StateObject private var purchaseService = PurchaseService()
    @State private var destination = Destination.home

    var body: some View {
        ZStack {
            switch destination {
            case .home:
                CaptureFlowView {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        destination = .memories
                    }
                }
            case .memories:
                MemoriesView {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        destination = .home
                    }
                }
            }
        }
        .background(SRColor.paper)
        .environmentObject(purchaseService)
        .task {
            await purchaseService.prepare()
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: Moment.self, inMemory: true)
}
