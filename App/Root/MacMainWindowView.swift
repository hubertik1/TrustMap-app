import SwiftUI

struct MacMainWindowView: View {
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
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(spacing: 6) {
                    sidebarButton(for: .map)
                    sidebarButton(for: .places)
                    sidebarButton(for: .add)
                    sidebarButton(for: .feed)
                    sidebarButton(for: .profile)
                }
                .padding(.horizontal, 10)
                .padding(.top, 16)

                Spacer(minLength: 0)
            }
            .navigationTitle("TrustMap")
            .navigationSplitViewColumnWidth(
                min: TrustMapLayout.macSidebarMinWidth,
                ideal: TrustMapLayout.macSidebarIdealWidth,
                max: TrustMapLayout.macSidebarMaxWidth
            )
        } detail: {
            NavigationStack {
                detailView
            }
            .id(container.selectedTab)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    container.refreshCenter.invalidateAll()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
                .accessibilityLabel("Refresh")

                Button {
                    isShowingNotifications = true
                } label: {
                    notificationButtonLabel
                }
                .help(notificationAccessibilityLabel)
                .accessibilityLabel(notificationAccessibilityLabel)

                Button {
                    container.isSettingsPresented = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $isShowingNotifications) {
            NavigationStack {
                NotificationsView(container: container)
            }
            .trustMapMacSheet(width: 560, minHeight: 620)
        }
        .sheet(isPresented: $container.isSettingsPresented) {
            NavigationStack {
                SettingsView(container: container)
            }
            .trustMapMacSheet(width: TrustMapLayout.settingsMaxWidth, minHeight: 680)
        }
        .task {
            await notificationBadgeStore.loadUnreadCount()
        }
        .task(id: refreshCenter.globalRevision) {
            await notificationBadgeStore.loadUnreadCount()
        }
    }

    private func sidebarButton(for tab: AppTab) -> some View {
        let isSelected = container.selectedTab == tab

        return Button {
            container.selectedTab = tab
        } label: {
            Label(tab.macTitle, systemImage: tab.systemImage)
                .font(.body.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.accentColor)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityLabel(tab.macTitle)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var detailView: some View {
        switch container.selectedTab {
        case .map:
            MapScreen(container: container)
        case .places:
            PlacesView(container: container)
        case .add:
            AddHubView(container: container)
        case .feed:
            FeedView(container: container)
        case .profile:
            ProfileView(container: container)
        }
    }

    private var notificationButtonLabel: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "bell")

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

    private var notificationBadgeText: String {
        notificationBadgeStore.unreadCount > 99 ? "99+" : String(notificationBadgeStore.unreadCount)
    }

    private var notificationAccessibilityLabel: String {
        let count = notificationBadgeStore.unreadCount
        return count > 0 ? "\(count) unread notifications" : "Notifications"
    }
}

#Preview {
    MacMainWindowView(container: PreviewAppFactory.makeContainer())
}
