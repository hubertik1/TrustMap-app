// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TrustMapContractSupport",
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
            sources: [
                "Core/Networking/BackendAPI.swift",
                "Core/State/AppConfiguration.swift",
                "Core/State/AppError.swift",
                "Features/Feed/Models/FeedPlaceActivityItem.swift",
                "Features/Feed/Services/FeedRepository.swift",
                "Features/Friends/Models/FriendInvite.swift",
                "Features/Friends/Models/FriendInviteStatus.swift",
                "Features/Friends/Models/Friendship.swift",
                "Features/Friends/Services/FriendRepository.swift",
                "Features/Places/Models/Place.swift",
                "Features/Profile/Models/User.swift",
                "Features/Reviews/Models/PhotoAsset.swift",
                "Features/Reviews/Models/VisibilityStatus.swift"
            ]
        ),
        .testTarget(
            name: "TrustMapContractSupportTests",
            dependencies: ["TrustMapContractSupport"],
            path: "Tests/TrustMapContractSupportTests"
        )
    ]
)
