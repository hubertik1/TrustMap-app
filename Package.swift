// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TrustMapContractSupport",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "TrustMapContractSupport",
            targets: ["TrustMapContractSupport"]
        )
    ],
    targets: [
        .target(
            name: "TrustMapContractSupport",
            path: ".",
            exclude: ["Resources/Assets.xcassets", "Resources/Preview Content", "Resources/Info-Local.plist", "Resources/Info-Prod.plist", "Resources/TrustMap.entitlements", "Resources/LaunchScreen.storyboard", "Resources/InfoPlist.xcstrings"],
            sources: [
                "Core/Networking/BackendAPI.swift",
                "Core/Localization/L10n.swift",
                "Core/State/AppConfiguration.swift",
                "Core/State/AppError.swift",
                "Features/Feed/Models/FeedPlaceActivityItem.swift",
                "Features/Feed/Services/FeedRepository.swift",
                "Features/Friends/Models/FriendInvite.swift",
                "Features/Friends/Models/FriendInviteStatus.swift",
                "Features/Friends/Models/Friendship.swift",
                "Features/Friends/Services/FriendRepository.swift",
                "Features/Notifications/Models/TrustMapNotification.swift",
                "Features/Notifications/Models/NotificationAuthorizationStatus+TrustMap.swift",
                "Features/Notifications/Services/NotificationRepository.swift",
                "Features/Notifications/Services/PushDeviceToken.swift",
                "Features/Notifications/Services/PushDeviceTokenRepository.swift",
                "Features/Map/Models/MapBounds.swift",
                "Features/Map/Models/MapFilterState.swift",
                "Features/Map/Models/MapPinAnnotationSnapshot.swift",
                "Features/Map/Models/MapPlaceAnnotation.swift",
                "Features/Map/Models/MapStatusOverlayVisibility.swift",
                "Features/Places/Models/CustomCategory.swift",
                "Features/Places/Models/DefaultCategoryCatalog.swift",
                "Features/Places/Models/Place.swift",
                "Features/Places/Models/PlaceCategoryOption.swift",
                "Features/Places/Models/PlaceListItem.swift",
                "Features/Places/Models/PlaceReviewerRating.swift",
                "Features/Places/Models/PlaceSourceType.swift",
                "Features/Profile/Models/User.swift",
                "Features/Profile/Models/UserStats.swift",
                "Features/Profile/Services/UserProfileRepository.swift",
                "Features/Reviews/Models/PhotoAsset.swift",
                "Features/Reviews/Models/VisibilityStatus.swift"
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "TrustMapContractSupportTests",
            dependencies: ["TrustMapContractSupport"],
            path: "Tests/TrustMapContractSupportTests"
        )
    ]
)
