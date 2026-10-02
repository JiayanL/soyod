# Release — TestFlight

## One-time setup

1. **App ID**: in the Apple Developer portal, register `com.jiayanl.atlas`
   (explicit App ID, iOS) with the **HealthKit** capability enabled.
2. **Team**: set your team ID in `Config/Signing.local.xcconfig` (gitignored):

   ```
   DEVELOPMENT_TEAM = ABCDE12345
   ```

   or export it in CI via `DEVELOPMENT_TEAM`.
3. **App Store Connect**: create the **Atlas** app record (bundle ID
   `com.jiayanl.atlas`, SKU `atlas-ios`).
4. **API key**: App Store Connect → Users and Access → Integrations →
   create a key with App Manager role, then set:

   | Secret | Value |
   |---|---|
   | `ASC_KEY_ID` | Key ID |
   | `ASC_ISSUER_ID` | Issuer ID (UUID) |
   | `ASC_KEY_P8` | Contents of the downloaded `.p8` |
   | `DEVELOPMENT_TEAM` | 10-char team ID |

   `fastlane/Appfile` already carries `app_identifier com.jiayanl.atlas`.

5. **Export compliance**: `ITSAppUsesNonExemptEncryption = NO` is already set
   in `Info.plist` — no per-build encryption questions.

## Local release

```
bundle install
xcodegen generate
bundle exec fastlane beta   # bumps build number, archives, uploads
```

Sanity-check the archive first (no signing needed):

```
scripts/archive-check.sh
```

## CI release

Push a build by running the **TestFlight** workflow manually
(`workflow_dispatch`) in GitHub Actions with the four secrets above.
`ios-ci.yml` runs build + unit tests on every push/PR.

## Versioning

`MARKETING_VERSION 1.0.0` and `CURRENT_PROJECT_VERSION` live in `project.yml`.
The `beta` lane increments the build number to `latest_testflight_build_number + 1`.
