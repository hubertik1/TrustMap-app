import SwiftUI
import UIKit

enum TrustMapLayout {
    static let macWindowTitle = "TrustMap"
    static let macSidebarMinWidth: CGFloat = 240
    static let macSidebarIdealWidth: CGFloat = 260
    static let macSidebarMaxWidth: CGFloat = 280
    static let readableContentMaxWidth: CGFloat = 900
    static let activityContentMaxWidth: CGFloat = 920
    static let formMaxWidth: CGFloat = 740
    static let settingsMaxWidth: CGFloat = 760
    static let mapSearchPanelWidth: CGFloat = 400
    static let mapInspectorWidth: CGFloat = 420
    static let macBottomPadding: CGFloat = 24
    static let phoneTabBarBottomPadding: CGFloat = 132
    static let macMinimumWindowSize = CGSize(width: 1100, height: 720)

    static var tabAwareBottomPadding: CGFloat {
        TrustMapPlatform.isMacCatalyst ? macBottomPadding : phoneTabBarBottomPadding
    }
}

private struct TrustMapReadableContentModifier: ViewModifier {
    let maxWidth: CGFloat
    let alignment: Alignment

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth, alignment: alignment)
            .frame(maxWidth: .infinity, alignment: alignment)
    }
}

private struct TrustMapMacSheetModifier: ViewModifier {
    let width: CGFloat
    let minHeight: CGFloat?

    func body(content: Content) -> some View {
        if TrustMapPlatform.isMacCatalyst {
            content
                .frame(minWidth: width, idealWidth: width, maxWidth: width)
                .frame(minHeight: minHeight)
        } else {
            content
        }
    }
}

private struct TrustMapMacWindowConfiguratorModifier: ViewModifier {
    let minSize: CGSize

    func body(content: Content) -> some View {
        if TrustMapPlatform.isMacCatalyst {
            content
                .background(MacWindowChromeConfigurator(minSize: minSize, title: TrustMapLayout.macWindowTitle))
        } else {
            content
        }
    }
}

private struct TrustMapPhoneTabBarHiddenModifier: ViewModifier {
    func body(content: Content) -> some View {
        if TrustMapPlatform.isMacCatalyst {
            content
        } else {
            content.toolbar(.hidden, for: .tabBar)
        }
    }
}

private struct TrustMapDismissKeyboardOnTapModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(KeyboardDismissTapInstaller())
    }
}

extension View {
    func trustMapReadableContent(
        maxWidth: CGFloat = TrustMapLayout.readableContentMaxWidth,
        alignment: Alignment = .top
    ) -> some View {
        modifier(TrustMapReadableContentModifier(maxWidth: maxWidth, alignment: alignment))
    }

    func trustMapMacSheet(width: CGFloat = TrustMapLayout.formMaxWidth, minHeight: CGFloat? = nil) -> some View {
        modifier(TrustMapMacSheetModifier(width: width, minHeight: minHeight))
    }

    func trustMapMacWindowConfigurator(minSize: CGSize = TrustMapLayout.macMinimumWindowSize) -> some View {
        modifier(TrustMapMacWindowConfiguratorModifier(minSize: minSize))
    }

    func trustMapPhoneTabBarHidden() -> some View {
        modifier(TrustMapPhoneTabBarHiddenModifier())
    }

    func trustMapDismissKeyboardOnTap() -> some View {
        modifier(TrustMapDismissKeyboardOnTapModifier())
    }
}

private struct KeyboardDismissTapInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> InstallerView {
        let view = InstallerView()
        view.onWindowChange = { window in
            context.coordinator.install(in: window)
        }
        return view
    }

    func updateUIView(_ uiView: InstallerView, context: Context) {
        uiView.onWindowChange = { window in
            context.coordinator.install(in: window)
        }
        context.coordinator.install(in: uiView.window)
    }

    static func dismantleUIView(_ uiView: InstallerView, coordinator: Coordinator) {
        uiView.onWindowChange = nil
        coordinator.uninstall()
    }

    final class InstallerView: UIView {
        var onWindowChange: ((UIWindow?) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onWindowChange?(window)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var installedWindow: UIWindow?
        private weak var tapRecognizer: UITapGestureRecognizer?

        func install(in window: UIWindow?) {
            guard installedWindow !== window else { return }

            uninstall()

            guard let window else { return }

            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tapRecognizer.cancelsTouchesInView = false
            tapRecognizer.delegate = self
            window.addGestureRecognizer(tapRecognizer)

            installedWindow = window
            self.tapRecognizer = tapRecognizer
        }

        func uninstall() {
            if let tapRecognizer, let installedWindow {
                installedWindow.removeGestureRecognizer(tapRecognizer)
            }

            installedWindow = nil
            tapRecognizer = nil
        }

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            installedWindow?.endEditing(true)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let view = touch.view else { return true }
            return !view.isTextInputOrDescendant
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

private extension UIView {
    var isTextInputOrDescendant: Bool {
        if self is UITextField || self is UITextView {
            return true
        }

        return superview?.isTextInputOrDescendant ?? false
    }
}

#if targetEnvironment(macCatalyst)
private struct MacWindowChromeConfigurator: UIViewRepresentable {
    let minSize: CGSize?
    let title: String

    init(minSize: CGSize? = TrustMapLayout.macMinimumWindowSize, title: String) {
        self.minSize = minSize
        self.title = title
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        configureWhenAttached(view, coordinator: context.coordinator)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        configureWhenAttached(uiView, coordinator: context.coordinator)
    }

    private func configureWhenAttached(_ view: UIView, coordinator: Coordinator) {
        DispatchQueue.main.async {
            guard applyConfiguration(to: view.window?.windowScene, coordinator: coordinator) else {
                scheduleRetry(for: view, coordinator: coordinator)
                return
            }
        }
    }

    private func scheduleRetry(for view: UIView, coordinator: Coordinator) {
        guard !coordinator.isRetryScheduled, coordinator.retryCount < 4 else { return }

        coordinator.isRetryScheduled = true
        coordinator.retryCount += 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            coordinator.isRetryScheduled = false
            configureWhenAttached(view, coordinator: coordinator)
        }
    }

    @discardableResult
    private func applyConfiguration(to scene: UIWindowScene?, coordinator: Coordinator) -> Bool {
        guard let scene else { return false }

        if let minSize {
            scene.sizeRestrictions?.minimumSize = minSize
        }

        if scene.title != title {
            scene.title = title
        }

        if scene.titlebar?.titleVisibility != .hidden {
            scene.titlebar?.titleVisibility = .hidden
        }

        coordinator.retryCount = 0
        return true
    }

    final class Coordinator {
        var isRetryScheduled = false
        var retryCount = 0
    }
}
#else
private struct MacWindowChromeConfigurator: View {
    let minSize: CGSize?
    let title: String

    init(minSize: CGSize? = TrustMapLayout.macMinimumWindowSize, title: String) {
        self.minSize = minSize
        self.title = title
    }

    var body: some View {
        EmptyView()
    }
}
#endif
