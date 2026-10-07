# MacSoul v0.1.0 release guide

Public distribution is pending Owner signing setup. The current local candidate is **UNSIGNED / UNNOTARIZED / NOT FOR PUBLIC DISTRIBUTION**. Build, test, package, sign, notarize and publish are separate checks.

## A. Archive-derived unsigned candidate

Requirements: macOS, full Xcode, Python 3. Version `0.1.0`, build `1`, bundle ID `local.macsoul.app`, `CODE_SIGNING_ALLOWED=NO`. The generator and checked-in project agree. No Developer Team, entitlements or signing are added.

App Release alone uses `ENABLE_TESTABILITY=NO`, `STRIP_INSTALLED_PRODUCT=YES`, `DEBUG_INFORMATION_FORMAT=dwarf-with-dsym`; optimization stays `-O`. App Debug and both Tests configurations retain their previous testability/development behavior. Effective Archive `COPY_PHASE_STRIP=YES`, `STRIP_STYLE=all`, `DEPLOYMENT_POSTPROCESSING=YES` are verified. The [Apple build-settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference) documents that enabling testability disables installed-product stripping.

Final package input must be the **stripped App from a Release Archive**, never a raw `BUILT_PRODUCTS_DIR` build product. Use a fresh archive/output path; do not overwrite failed or historical candidates:

```bash
./scripts/doctor.sh
./scripts/build.sh
./scripts/test.sh
python3 scripts/test_progress.py
python3 scripts/verify_progress.py
./scripts/verify.sh
git diff --check

xcodebuild -project MacSoul.xcodeproj -scheme MacSoul \
  -configuration Release -destination 'generic/platform=macOS' \
  -archivePath .artifacts/day7/final-archive/MacSoul.xcarchive \
  CODE_SIGNING_ALLOWED=NO archive
```

No temporary testability/strip/debug-info override is needed. Before zip creation, require an actual Strip step and zero owner-home prefix occurrences in **both** executable slices and all distributed App resources. Check universal architecture, version/build, absence of source/tests/logs/raw payloads/artifacts, source-identical PrivacyInfo with exactly the approved three reasons, and intact ThirdPartyNotices. Section classification must not substitute for the zero-prefix gate.

Private `MacSoul.app.dSYM` stays separately inside ignored `.artifacts/day7/.../MacSoul.xcarchive/dSYMs/`. Confirm its UUIDs match the executable. Source paths inside that private dSYM are outside the distributed App gate. Do not put dSYM, the whole xcarchive, logs or source in the App zip, README download or public release.

After App static checks pass, package only the archived App:

```bash
mkdir -p .artifacts/day7/final-archive/release
ditto -c -k --sequesterRsrc --keepParent \
  .artifacts/day7/final-archive/MacSoul.xcarchive/Products/Applications/MacSoul.app \
  .artifacts/day7/final-archive/release/MacSoul-v0.1.0-unsigned.zip
shasum -a 256 .artifacts/day7/final-archive/release/MacSoul-v0.1.0-unsigned.zip
stat -f '%z' .artifacts/day7/final-archive/release/MacSoul-v0.1.0-unsigned.zip
```

Independently extract to a fresh ignored directory, compare all App file hashes with the Archive App, and rescan extracted executable and all uncompressed zip members. Static packaging checks do not prove launch/UI/runtime behavior. After privacy PASS and process authorization, use a byte-identical visible `build-preview/` copy for the minimum Preview launch/main/Menu Bar/normal Quit/reopen smoke. Do not install into `/Applications` automatically. Declare combined final unsigned RC package privacy acceptance only after all automatic/Archive/privacy/extraction and smoke gates pass; Owner Live regression and performance remain separate.

### Current checkpoint

Current System-layout Archive/source verification365passed/0failed/0skipped, actual Strip1, both slices0owner-prefixes, exact privacy/resources, private matching dSYM and independent extraction PASS. Owner final Live regression and scoped launch/main/Menu Bar/normal Quit/reopen smoke PASS. Final native300sperformance completed: parentCPU PASS, RSS REVIEW (start/max100.48MB, average88.11MB, end79.48MB), stable one owned Codex child. No unconditional100MB target PASS or leak claim. Owner scoped final review completed for this local unsigned RC: RSS REVIEW ACCEPTED by Owner for this finite v0.1.0 RC observation. D7-01–D7-08 done after individual original-criterion review; Day7 GitHub CI NOT_RUN; current exact hashes and evidence are in the [Day7 report](../reports/day-7-release-closeout-2026-10-07.md) and [final report](../reports/FINAL.md). Prior accepted/failed checkpoints preserved.

Earlier build-product packages and their zero-path claims remain historical **SUPERSEDED** records: independent extraction reproduced178LC_SYMTAB debug-map references. The corrected scanner is current authority. Failed artifacts are preserved, not overwritten or manually stripped.

The candidate remains **UNSIGNED / UNNOTARIZED / NOT FOR PUBLIC DISTRIBUTION**. Signing, notarization, Gatekeeper, installed Login Item and publication are separate Owner-authorized checks.

## B. Owner-authorized Developer ID / notarization path

**Plan only; NOT_RUN.** Owner must choose a stable `<PRODUCTION_BUNDLE_ID>`, `<DEVELOPMENT_TEAM>` and available `<DEVELOPER_ID_APPLICATION>` certificate. Do not guess values or read existing credential stores. Review hardened runtime and minimal required entitlements against subprocess/network behavior before enabling signing. Recheck real Login Item registration/unregistration only in the installed/signed environment, with explicit Owner action.

After those decisions, an authorized release operator can build/archive with signing enabled, for example:

```bash
xcodebuild -project MacSoul.xcodeproj -scheme MacSoul \
  -configuration Release -destination 'generic/platform=macOS' \
  -archivePath .artifacts/release/MacSoul.xcarchive \
  PRODUCT_BUNDLE_IDENTIFIER='<PRODUCTION_BUNDLE_ID>' \
  DEVELOPMENT_TEAM='<DEVELOPMENT_TEAM>' \
  CODE_SIGN_IDENTITY='<DEVELOPER_ID_APPLICATION>' \
  CODE_SIGNING_ALLOWED=YES ENABLE_HARDENED_RUNTIME=YES archive
```

This is an owner-reviewed starting command, not a tested signing recipe. Entitlements/export policy and nested executable signatures require review; do not apply `codesign --deep` as a repair shortcut. Verify the final signed App and signing identity/entitlements before packaging:

```bash
codesign --verify --strict --verbose=2 '<SIGNED_APP_PATH>'
codesign -dv --verbose=4 '<SIGNED_APP_PATH>'
codesign -d --entitlements :- '<SIGNED_APP_PATH>'
```

Use an Owner-managed notarytool profile or App Store Connect API-key setup. **OWNER ACTION / modifies Keychain:** creating a profile with `xcrun notarytool store-credentials '<NOTARY_PROFILE>'` is not performed by this guide or Agent. Never paste a real token/password into repository examples, logs or shell history. No credential query has been executed.

Only after separately authorized signing and packaging:

```bash
xcrun notarytool submit '<SIGNED_ZIP_PATH>' --keychain-profile '<NOTARY_PROFILE>' --wait
xcrun notarytool info '<SUBMISSION_ID>' --keychain-profile '<NOTARY_PROFILE>'
xcrun stapler staple '<SIGNED_APP_PATH>'
xcrun stapler validate '<SIGNED_APP_PATH>'
spctl --assess --type execute --verbose=2 '<SIGNED_APP_PATH>'
```

Require an Accepted notarization result; investigate rejected logs privately and sanitize any retained evidence. Staple and assess the final App, then recreate the final zip/DMG and calculate its SHA-256. Independently verify the downloaded artifact and real launch/quit/reopen. Gatekeeper checks are NOT_RUN for the current unsigned candidate.

Tag/GitHub Release/upload are a final, separate Owner authorization after review and CI. No tag, release, DMG, signing, notarization submission or repository-setting change is performed in Day 7.

Official references: [Developer ID](https://developer.apple.com/developer-id/), [custom notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow). These describe signing/hardened runtime and notarytool/stapling; reading them does not constitute executing the signing plan.
