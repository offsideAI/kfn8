# Kfn8Kit (iPhone/iPad copy)

Pure Swift libraries for the iPhone/iPad app: no UI, no RealityKit or ARKit, all tested on the macOS host.

- **Kfn8Domain:** identifiers, Spaces/Rooms/Designs/Placements, edits and undo, room frames, attachment and collision rules (including `OrientedBox.realWorldContactTest`), inventory, clearances, frame-time statistics.
- **Kfn8Persistence:** the SwiftData store behind a persistence actor, scan files and the deletion journal.
- **Kfn8Catalogue:** the generated catalogue API client, asset cache, revocation sync and the checksum-verified bundled catalogue reader.

## Origin

Copied on 2026-10-05 from the Vision Pro app's `_Kfn8-frontend-avp-src/Packages/Kfn8Kit` (decision D8). From then on this copy belongs to the iPhone/iPad app and may diverge. Changes are not synced between the two copies.

The one exception is the backend contract. `Sources/Kfn8Catalogue/Generated/CatalogueAPI.swift` is generated from `_Kfn8-backend-fastapi/contracts/v1/openapi.json`, and `tools/ci-ios.sh` fails if it drifts:

```sh
_Kfn8-backend-fastapi/venv/bin/python _Kfn8-backend-fastapi/tools/generate_swift_client.py \
  --out _Kfn8-frontend-ios-src/Packages/Kfn8Kit/Sources/Kfn8Catalogue/Generated/CatalogueAPI.swift [--check]
```

## Tests

```sh
cd _Kfn8-frontend-avp/_Kfn8-frontend-ios-src/Packages/Kfn8Kit && xcrun swift test
```
