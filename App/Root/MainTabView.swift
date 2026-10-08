import SwiftUI

struct MainTabView: View {
    @ObservedObject private var container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    var body: some View {
        if TrustMapPlatform.isMacCatalyst {
            MacMainWindowView(container: container)
        } else {
            PhoneMainTabView(container: container)
        }
    }
}

private struct PhoneMainTabView: View {
    @ObservedObject private var container: AppContainer
    @ObservedObject private var notificationBadgeStore: NotificationBadgeStore
    @ObservedObject private var refreshCenter: AppRefreshCenter
    @State private var isShowingNotifications = false

    init(container: AppContainer) {
        self.container = container
        self.notificationBadgeStore = container.notificationBadgeStore
        self.refreshCenter = container.refreshCenter
    }

    var body: some View {
        TabView(selection: $container.selectedTab) {
            NavigationStack {
                MapScreen(container: container)
            }
            .toolbar {
                notificationToolbarItem
            }
            .tabItem {
                Label(AppTab.map.phoneTitle, systemImage: AppTab.map.systemImage)
            }
            .tag(AppTab.map)

            NavigationStack {
                PlacesView(container: container)
            }
            .toolbar {
                notificationToolbarItem
            }
            .tabItem {
                Label(AppTab.places.phoneTitle, systemImage: AppTab.places.systemImage)
            }
            .tag(AppTab.places)

            NavigationStack {
                AddHubView(container: container)
            }
            .toolbar {
                notificationToolbarItem
            }
            .tabItem {
                Label(AppTab.add.phoneTitle, systemImage: AppTab.add.systemImage)
            }
            .tag(AppTab.add)

            NavigationStack {
                FeedView(container: container)
            }
            .toolbar {
                notificationToolbarItem
            }
            .tabItem {
                Label(AppTab.feed.phoneTitle, systemImage: AppTab.feed.systemImage)
            }
            .tag(AppTab.feed)

            NavigationStack {
                ProfileView(container: container)
            }
            .toolbar {
                notificationToolbarItem
            }
            .tabItem {
                Label(AppTab.profile.phoneTitle, systemImage: AppTab.profile.systemImage)
            }
            .tag(AppTab.profile)
        }
        .sheet(isPresented: $isShowingNotifications) {
            NavigationStack {
                NotificationsView(container: container)
            }
        }
        .task {
            await notificationBadgeStore.loadUnreadCount()
        }
        .task(id: refreshCenter.globalRevision) {
            await notificationBadgeStore.loadUnreadCount()
        }
    }

    @ToolbarContentBuilder
    private var notificationToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                isShowingNotifications = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.body.weight(.semibold))

                    if notificationBadgeStore.unreadCount > 0 {
                        Text(notificationBadgeText)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, notificationBadgeStore.unreadCount > 9 ? 4 : 0)
                            .frame(minWidth: 15, minHeight: 15)
                            .background(Color.red, in: Capsule())
                            .offset(x: 8, y: -8)
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: 28, height: 28)
            }
            .accessibilityLabel(notificationAccessibilityLabel)
        }
    }

    private var notificationBadgeText: String {
        notificationBadgeStore.unreadCount > 99 ? "99+" : String(notificationBadgeStore.unreadCount)
    }

    private var notificationAccessibilityLabel: String {
        let count = notificationBadgeStore.unreadCount
        return count > 0 ? L10n.valueUnreadNotifications(String(describing: count)) : L10n.notifications
    }
}

#Preview {
    MainTabView(container: PreviewAppFactory.makeContainer())
}
