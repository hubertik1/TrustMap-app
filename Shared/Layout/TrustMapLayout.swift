import SwiftUI
import UIKit

enum TrustMapLayout {
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
                .background(MacWindowSizeConfigurator(minSize: minSize))
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
}

#if targetEnvironment(macCatalyst)
private struct MacWindowSizeConfigurator: UIViewRepresentable {
    let minSize: CGSize

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        configureWhenAttached(view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        configureWhenAttached(uiView)
    }

    private func configureWhenAttached(_ view: UIView) {
        DispatchQueue.main.async {
            guard let scene = view.window?.windowScene else {
                return
            }

            scene.sizeRestrictions?.minimumSize = minSize
        }
    }
}
#else
private struct MacWindowSizeConfigurator: View {
    let minSize: CGSize

    var body: some View {
        EmptyView()
    }
}
#endif
