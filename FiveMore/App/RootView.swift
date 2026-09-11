import SwiftUI

struct RootView: View {
    private enum Tab: Hashable {
        case home
        case memories
    }

    @StateObject private var purchaseService = PurchaseService()
    @State private var selection: Tab = .home

    var body: some View {
        TabView(selection: $selection) {
            CaptureFlowView()
                .tabItem {
                    Label {
                        Text("Home")
                    } icon: {
                        Image("IconHome")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                    }
                }
                .tag(Tab.home)

            MemoriesView()
                .tabItem {
                    Label {
                        Text("Memories")
                    } icon: {
                        Image("IconMemories")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                    }
                }
                .tag(Tab.memories)
        }
        .tint(SRColor.orange)
        .background(SRColor.paper)
        .toolbarBackground(SRColor.paper, for: .tabBar)
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
