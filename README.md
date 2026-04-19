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
