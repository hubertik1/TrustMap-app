import SwiftUI

struct MainTabView: View {
    @ObservedObject private var container: AppContainer
    @ObservedObject private var deepLinkRouter: DeepLinkRouter
    @State private var selectedTab: AppTab = .map

    init(container: AppContainer) {
        self.container = container
        self.deepLinkRouter = container.deepLinkRouter
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                MapScreen(container: container)
            }
            .tabItem {
                Label("Map", systemImage: "map")
            }
            .tag(AppTab.map)

            NavigationStack {
                PlacesView(container: container)
            }
            .tabItem {
                Label("Places", systemImage: "mappin.and.ellipse")
            }
            .tag(AppTab.places)

            NavigationStack {
                FeedView(container: container)
            }
            .tabItem {
                Label("Feed", systemImage: "list.bullet.rectangle")
            }
            .tag(AppTab.feed)

            NavigationStack {
                FriendsView(container: container)
            }
            .tabItem {
                Label("Friends", systemImage: "person.2")
            }
            .tag(AppTab.friends)

            NavigationStack {
                ProfileView(container: container)
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }
            .tag(AppTab.profile)
        }
        .onChange(of: deepLinkRouter.presentedInvite?.id) { _, presentedInviteID in
            guard presentedInviteID != nil else {
                return
            }

            selectedTab = .friends
        }
        .sheet(
            item: Binding(
                get: { deepLinkRouter.presentedInvite },
                set: { newValue in
                    if newValue == nil {
                        deepLinkRouter.dismissPresentedInvite()
                    }
                }
            )
        ) { presentedInvite in
            NavigationStack {
                AcceptInviteView(container: container, token: presentedInvite.token)
            }
        }
    }
}

#Preview {
    MainTabView(container: PreviewAppFactory.makeContainer())
}
