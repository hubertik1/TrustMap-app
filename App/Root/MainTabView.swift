import SwiftUI

struct MainTabView: View {
    @ObservedObject private var container: AppContainer
    @State private var selectedTab: AppTab = .map

    init(container: AppContainer) {
        self.container = container
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
                AddHubView(container: container)
            }
            .tabItem {
                Label("Add", systemImage: "plus.circle.fill")
            }
            .tag(AppTab.add)

            NavigationStack {
                FeedView(container: container)
            }
            .tabItem {
                Label("Feed", systemImage: "list.bullet.rectangle")
            }
            .tag(AppTab.feed)

            NavigationStack {
                ProfileView(container: container)
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }
            .tag(AppTab.profile)
        }
    }
}

#Preview {
    MainTabView(container: PreviewAppFactory.makeContainer())
}
