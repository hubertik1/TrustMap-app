# TrustMap-app

## Schemes

- `Local`
  - uses `Config/Local.xcconfig`
  - reads `API_BASE_URL` from `Resources/Info-Local.plist`
  - intended for a backend reachable from a real iPhone on the same LAN
- `Prod`
  - uses `Config/Prod.xcconfig`
  - reads `API_BASE_URL` from `Resources/Info-Prod.plist`
  - targets the production Azure backend

## Local backend URL

`Local.xcconfig` defines the LAN-friendly base URL using `TRUSTMAP_LAN_HOST` and `TRUSTMAP_LAN_PORT`.

To point the app at your own Mac without changing tracked files:

1. Copy `Config/Local.override.xcconfig.example` to `Config/Local.override.xcconfig`.
2. Set `TRUSTMAP_LAN_HOST` to your Mac's `.local` hostname or LAN IP address.
3. Build and run the `Local` scheme.

## Mac Catalyst

TrustMap builds as a Mac Catalyst app from the iOS target. `Config/Base.xcconfig` and `scripts/generate_project.rb` enable Catalyst with `SUPPORTED_PLATFORMS = iphoneos iphonesimulator macosx`, `SUPPORTS_MACCATALYST = YES`, and `TARGETED_DEVICE_FAMILY = 1,2`.

The Catalyst UI is implemented in SwiftUI with a desktop sidebar shell, Mac toolbar actions, keyboard shortcuts, constrained panels, and a minimum resizable window size. Xcode's exact "Optimize for Mac" vs. "Scale Interface to Match iPad" setting is not encoded here because that build setting is not stable across Xcode project-generation APIs; keep the target set to the optimized Mac Catalyst interface in Xcode if the IDE surfaces that option.

Mac Catalyst signing uses the same app entitlements as iOS, including Sign in with Apple and push notifications. A normal signed Catalyst build therefore needs a Mac Catalyst development profile for `com.hubertik.TrustMap`; for source-only validation on a machine without that profile, build with `CODE_SIGNING_ALLOWED=NO`.
