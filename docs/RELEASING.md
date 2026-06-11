# Releasing

## Versioning

Semantic versioning: `MAJOR.MINOR.PATCH`.

- **MAJOR** — incompatible behavior change (e.g. save-data format)
- **MINOR** — new user-facing features
- **PATCH** — fixes only

`MARKETING_VERSION` in `project.yml` is the source of truth and must match
the release tag.

## Release checklist

1. Ensure `main` is green in [CI](https://github.com/MURD0X/PokerCoach/actions).
2. Update `CHANGELOG.md`: move items from *Unreleased* into a dated version
   section.
3. Bump `MARKETING_VERSION` (and `CURRENT_PROJECT_VERSION` for every upload)
   in `project.yml`, run `xcodegen generate`, commit via PR.
4. Tag and create the GitHub release:
   ```sh
   git tag -a v<version> -m "PokerCoach <version>"
   git push origin v<version>
   gh release create v<version> --title "PokerCoach <version>" --notes-file <notes>
   ```
   Release notes must include the test results summary from the release
   commit's CI run.

## TestFlight

1. Open `PokerCoach.xcodeproj` in Xcode with your Apple Developer account
   signed in (Settings → Accounts).
2. Target *PokerCoach* → Signing & Capabilities → select your team. Bundle
   ID: `com.mpcollins.pokercoach`.
3. An App Store Connect app record must exist for the bundle ID (one-time
   setup at appstoreconnect.apple.com).
4. Select *Any iOS Device (arm64)* → Product → Archive → Distribute App →
   TestFlight & App Store → Upload.
5. In App Store Connect → TestFlight, add internal testers (instant) or an
   external group (first build needs a brief Beta App Review).

Upload requirements are already in place: the app icon ships in the asset
catalog, and `ITSAppUsesNonExemptEncryption: NO` answers export compliance
automatically.

### CLI upload (after Xcode is signed in and the ASC record exists)

```sh
xcodebuild -project PokerCoach.xcodeproj -scheme PokerCoach \
  -destination 'generic/platform=iOS' \
  -archivePath build/PokerCoach.xcarchive \
  -allowProvisioningUpdates archive
xcodebuild -exportArchive \
  -archivePath build/PokerCoach.xcarchive \
  -exportOptionsPlist scripts/export-options.plist \
  -allowProvisioningUpdates \
  -exportPath build/export
```

`scripts/export-options.plist` uses `method: app-store-connect` with
`destination: upload`, so the export step uploads straight to TestFlight
using the Xcode account session.
