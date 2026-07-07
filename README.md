# TrustMap App

TrustMap is an iOS and Mac Catalyst app for saving places you trust and discovering recommendations from friends. It combines a personal place list, social map, reviews, dish notes, photos, friend profiles and activity feeds around one backend-owned source of truth.

This repository contains the SwiftUI client. The companion backend lives in the separate `TrustMap-server` repository and must be running for the app to sign in, load data, upload photos and sync social features.

## Features

- Sign in with Apple.
- Map-based discovery of saved and friend-recommended places.
- Place search with custom place support.
- Place reviews with ratings, notes, photos and visibility controls.
- Dish reviews linked to places and optional place reviews.
- Friend search, friend requests and friend profile views.
- Feed of visible friend activity.
- Profile management, avatar upload and privacy settings.
- Push notification registration and in-app notification views.
- Account deletion flow.
- iPhone, iPad and Mac Catalyst support from one SwiftUI codebase.

## Technology Stack

- Swift 6
- SwiftUI
- MapKit
- AuthenticationServices for Sign in with Apple
- UserNotifications and APNs device-token registration
- URLSession-based API client
- Keychain storage for access and refresh tokens
- Xcode project plus a Swift Package target for contract-support tests

## Repository Layout

```text
.
|-- App/                         # App entry point and root navigation shells
|-- Config/                      # Shared, Local and Prod build configuration
|-- Core/                        # Networking, session, keychain and app state
|-- Features/                    # Product features grouped by domain
|-- Resources/                   # Assets, Info.plist files, entitlements
|-- Shared/                      # Reusable UI, layout and platform helpers
|-- Tests/                       # Swift package contract-support tests
|-- TrustMap.xcodeproj
|-- Package.swift
`-- scripts/generate_project.rb
```

## App Architecture

The app is organized by feature. Each feature owns its models, repositories, view models and views where practical. Shared infrastructure lives in `Core`, while reusable UI components live in `Shared`.

The networking layer resolves the base API URL from the active build configuration. Authenticated requests use the current access token and can refresh the session when the backend returns an authorization failure. Tokens are stored in Keychain.

The backend is the source of truth for users, places, reviews, photos, visibility and social graph state.

## Build Schemes

The Xcode project includes two shared schemes:

- `Local`
  - Uses `Config/Local.xcconfig`.
  - Reads `TrustMapAPIBaseURL` from `Resources/Info-Local.plist`.
  - Targets a backend reachable from a simulator or physical device on the same LAN.
  - Uses APNs development environment.

- `Prod`
  - Uses `Config/Prod.xcconfig`.
  - Reads `TrustMapAPIBaseURL` from `Resources/Info-Prod.plist`.
  - Targets the production backend URL configured in `Config/Prod.xcconfig`.
  - Uses APNs production environment.

## Requirements

- Xcode with Swift 6 support
- iOS 18 SDK or newer
- A TrustMap backend instance
- Apple Developer account for device builds that use Sign in with Apple, push notifications and automatic signing

The app's deployment target is configured in `Config/Base.xcconfig`.

## Local Development

### 1. Start The Backend

Start the TrustMap backend locally from the sibling `TrustMap-server` repository. The simplest path is:

```bash
cd ../TrustMap-server
docker compose up --build
```

The development API listens on:

```text
http://localhost:5104
```

For a physical iPhone, use a LAN-reachable hostname or IP address instead of `localhost`.

### 2. Configure The Local API Host

Create a local override file:

```bash
cp Config/Local.override.xcconfig.example Config/Local.override.xcconfig
```

Set the host to your Mac's Bonjour hostname or LAN IP:

```xcconfig
TRUSTMAP_LAN_HOST = your-mac-name.local
```

or:

```xcconfig
TRUSTMAP_LAN_HOST = 192.168.1.42
```

`Config/Local.override.xcconfig` is ignored by Git.

### 3. Run The App

Open the project:

```bash
open TrustMap.xcodeproj
```

Select the `Local` scheme and run on a simulator or device.

## Production Configuration

Production builds use:

```text
Config/Prod.xcconfig
Resources/Info-Prod.plist
```

The production API base URL is configured through `API_BASE_URL` in `Config/Prod.xcconfig`.

Before shipping a production build:

- Confirm the backend URL points to the intended environment.
- Confirm the bundle identifier matches the Apple Developer configuration.
- Confirm Sign in with Apple is enabled for the app identifier.
- Confirm push notification entitlements and APNs environment are correct.
- Confirm the backend allows the production bundle ID in `AppleAuth:AllowedAudiences`.

## Signing And Capabilities

The app uses automatic code signing and the entitlements in:

```text
Resources/TrustMap.entitlements
```

Current capabilities include:

- Sign in with Apple
- Push notifications

Mac Catalyst signing uses the same entitlements. A normal signed Catalyst build needs a matching Mac Catalyst development or distribution profile for the configured bundle identifier.

For source-only validation on a machine without signing profiles, build with signing disabled where appropriate:

```bash
xcodebuild \
  -project TrustMap.xcodeproj \
  -scheme Local \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Mac Catalyst

TrustMap builds as a Mac Catalyst app from the iOS target. The Catalyst UI uses a desktop-oriented SwiftUI shell with sidebar navigation, toolbar actions, keyboard shortcuts, constrained panels and a minimum resizable window size.

Relevant build settings live in `Config/Base.xcconfig`:

```text
SUPPORTED_PLATFORMS = iphoneos iphonesimulator macosx
SUPPORTS_MACCATALYST = YES
TARGETED_DEVICE_FAMILY = 1,2
```

## Testing

This repository includes a Swift Package target for contract-support tests around networking models and client-side API behavior.

Run tests from Xcode, or use Swift Package Manager:

```bash
swift test
```

Some full-app behavior depends on the Xcode project, Apple frameworks and a running backend, so Xcode is the primary environment for app validation.

## Backend Contract

The app expects the backend to provide:

- Apple sign-in exchange through `/auth/sign-in`.
- Refresh-token rotation through `/auth/refresh`.
- Authenticated endpoints for users, friends, categories, places, reviews, feed, map, photos, notifications and device tokens.
- Protected media endpoints that accept the current access token.
- String enum values in JSON payloads.

See the backend documentation for API and deployment details.

## Local Files Not Committed

The following local files and directories are intentionally ignored:

```text
.build/
Config/Local.override.xcconfig
xcuserdata/
*.ipa
*.dSYM
```

Do not commit signing assets, provisioning profiles, private keys or local environment overrides.
