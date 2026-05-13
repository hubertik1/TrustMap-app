import Foundation

enum MapStatusOverlayVisibility {
    static func shouldShowFullScreenLoading(
        isLoading: Bool,
        hasVisibleAnnotationsInCurrentViewport: Bool
    ) -> Bool {
        isLoading && !hasVisibleAnnotationsInCurrentViewport
    }

    static func shouldShowFullScreenError(
        errorMessage: String?,
        hasVisibleAnnotationsInCurrentViewport: Bool
    ) -> Bool {
        errorMessage?.isEmpty == false && !hasVisibleAnnotationsInCurrentViewport
    }

    static func shouldShowRefreshErrorBanner(
        errorMessage: String?,
        hasVisibleAnnotationsInCurrentViewport: Bool
    ) -> Bool {
        errorMessage?.isEmpty == false && hasVisibleAnnotationsInCurrentViewport
    }

    static func shouldShowStatusOverlay(
        isPromptPresented: Bool,
        isDroppedPinPresented: Bool,
        hasSearchResults: Bool,
        searchText: String,
        errorMessage: String?,
        hasLoadedMapPlaces: Bool,
        isLoading: Bool,
        hasVisibleAnnotationsInCurrentViewport: Bool
    ) -> Bool {
        if isPromptPresented || isDroppedPinPresented {
            return false
        }

        if hasSearchResults {
            return false
        }

        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }

        if shouldShowRefreshErrorBanner(
            errorMessage: errorMessage,
            hasVisibleAnnotationsInCurrentViewport: hasVisibleAnnotationsInCurrentViewport
        ) {
            return true
        }

        return hasLoadedMapPlaces
            && !isLoading
            && !hasVisibleAnnotationsInCurrentViewport
    }
}
