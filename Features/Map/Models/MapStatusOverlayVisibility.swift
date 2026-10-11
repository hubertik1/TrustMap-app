import Foundation

enum MapStatusOverlayVisibility {
    static func shouldShowLoadingIndicator(
        isLoading: Bool,
        hasLoadedMapPlaces: Bool,
        hasVisibleAnnotationsInCurrentViewport: Bool
    ) -> Bool {
        isLoading && !hasLoadedMapPlaces && !hasVisibleAnnotationsInCurrentViewport
    }

    static func shouldShowFullScreenError(
        errorMessage: String?,
        hasLoadedMapPlaces: Bool,
        hasVisibleAnnotationsInCurrentViewport: Bool
    ) -> Bool {
        errorMessage?.isEmpty == false && !hasLoadedMapPlaces && !hasVisibleAnnotationsInCurrentViewport
    }

    static func shouldShowRefreshErrorBanner(
        errorMessage: String?,
        hasLoadedMapPlaces: Bool,
        hasVisibleAnnotationsInCurrentViewport: Bool
    ) -> Bool {
        errorMessage?.isEmpty == false && (hasLoadedMapPlaces || hasVisibleAnnotationsInCurrentViewport)
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
            hasLoadedMapPlaces: hasLoadedMapPlaces,
            hasVisibleAnnotationsInCurrentViewport: hasVisibleAnnotationsInCurrentViewport
        ) {
            return true
        }

        return hasLoadedMapPlaces
            && !isLoading
            && !hasVisibleAnnotationsInCurrentViewport
    }
}
