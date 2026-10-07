# MacSoul v0.1.0 release guide

## Current release preparation

**v0.1.0 UNSIGNED / UNNOTARIZED Developer Preview — not publicly released.** Day 7 local RC acceptance and repository integration are complete: [PR #10](https://github.com/liu-657667/macsoul/pull/10) merged; [main CI 37614072470](https://github.com/liu-657667/macsoul/actions/runs/37614072470) SUCCESS. The current phase prepares a minimal native DMG, a byte-identical copy of the accepted ZIP, checksums, public documentation and an unpublished Release draft. Public tag and Publish Release require final Owner approval. Signing/notarization is outside this phase.

### Download and install / 下载与安装

After publication, use [GitHub Releases](https://github.com/liu-657667/macsoul/releases). Until then, candidate attachments are available only to authorized draft reviewers.

1. Download `MacSoul-v0.1.0-macos-universal-unsigned.dmg` (recommended) or `MacSoul-v0.1.0-unsigned.zip`, plus `SHA256SUMS.txt`.
2. In the download directory, run `shasum -a 256 -c SHA256SUMS.txt` if both packages are present, or compare the chosen file's `shasum -a 256` output with its checksum entry.
3. Open the DMG and drag `MacSoul.app` to `Applications`; alternatively extract the ZIP and copy the App. No Xcode or compilation is required. Quit an older MacSoul instance before opening the candidate.
4. Launch MacSoul. It defaults to Developer Preview / mock data; Live System is an explicit Settings choice.
5. This App has no Developer ID signature or Apple notarization. If first opening is blocked, only after trusting the source and checksum, follow [Apple's per-App opening instructions](https://support.apple.com/en-us/102445): try opening, then System Settings → Privacy & Security → Open Anyway, if offered. Do not disable global protection or remove quarantine. A damaged-app message or abnormal exit requires separate investigation.

公开发布后下载 DMG（推荐）或 ZIP（备用）及校验文件；核对 SHA-256，打开 DMG，将 App 拖入 Applications 后启动。无需 Xcode。默认模拟模式。未签名、未公证的首次打开可能被拦截；确认来源和校验值可信后，按上面的 Apple 官方逐 App 说明操作，不关闭全局保护。当前没有公开二进制 Release。

### Requirements and limits

- Minimum deployment target: macOS 13.0; Universal includes arm64 + x86_64. Existing Owner observations were on Apple Silicon; Intel hardware and all supported OS versions are not claimed tested.
- Codex exact verified CLI versions: **0.160.0 / 0.160.1 / 0.162.0-alpha.2**. Unknown versions fail closed. Claude without a verified real quota source remains honestly unavailable.
- Cleaner is read-only, with deletion NOT_IMPLEMENTED BY DESIGN. Region NOT_COLLECTED. Signed/installed Login Item validation remains deferred; App Store Connect privacy validation, signing/notarization, stress/specialized tests are NOT_RUN. Natural quota-update notifications and real critical / quota95% events remain NOT_OBSERVED.
- No App Store, Homebrew or automatic updates. No public distribution, signed installer or Gatekeeper PASS is claimed during preparation.
- Prior local validation for the accepted source: **365 tests / 0 failures / 0 skips**, not rerun for packaging. Successful repository CI reports unit PASS / exit 0 without exposing test counts; its manual_ui / performance / live_provider remain NOT_RUN.
- Owner Live PASS, CPU PASS and package privacy PASS remain accepted. Five-minute CPU avg / p95 / max: **0.012488% / 0.039502% / 0.063822%**. RSS start / end / avg / max: **100.483 / 79.479 / 88.107 / 100.483 decimal MB**; first / middle / final-third means: **93.502 / 89.300 / 81.833 MB**. Original result: **RSS REVIEW**. Owner decision: **RSS REVIEW ACCEPTED by Owner for this finite v0.1.0 RC observation.** The 100 MB target and 150 MB investigation threshold remain unchanged; no all-run <100 MB or no-memory-leak claim.

### Accepted App identity

- Source fingerprint: `1c60e81ec22795ba49bac7877309e57f534e2bc1d21911dcddef9adb171fb067`
- Executable SHA256: `7224f208d58b45612c3482b24ee7ec637c4f6c725fb0cde4a49fc4aabac60200`
- Original ZIP SHA256: `6b541098d2cddcab546fecad4d5a48b09e1c837892ea0af68a912ff634e3f177` — **6,062,427 bytes**

Reuse the accepted Archive App unchanged; copy the original ZIP bytes. A new DMG gets its own SHA256/size. Use a fresh ignored output directory and compare every mounted App file, PrivacyInfo and ThirdPartyNotices with the accepted inputs; corrected per-slice scanner must show zero owner-home prefixes and no N_SO/N_OSO/N_AST debug map. Distribute only App + Applications symlink in the DMG; no dSYM, Archive, source, logs or private evidence.

### Separate validation records

Record individually: DMG mount; mounted App identity/privacy; local Preview launch/main/Menu Bar/normal Quit/reopen; authenticated Draft attachment download/hash; actual browser download/quarantine/first opening; post-publication anonymous download. Local or authenticated command-line download is not browser/Gatekeeper evidence. Public anonymous download stays NOT_RUN before publication. Current run results belong in the PR body, ignored evidence and Release draft, not rewritten historical reports.

An unpublished draft uses proposed tag `v0.1.0`, exact CI-passed final main SHA, prerelease=true and not Latest. Confirm the tool does not create a public tag while saving a draft; verify remote tag refs before/after. Upload only DMG, original ZIP and SHA256SUMS.txt. Stop for Owner review before tag/publication.

Build, unit, package, UI, performance, signing, notarization and publication remain distinct checks.

## A. Historical Day 7 Archive procedure (already completed; do not rerun for this packaging phase)

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

### Accepted Day 7 checkpoint

Current System-layout Archive/source verification365passed/0failed/0skipped, actual Strip1, both slices0owner-prefixes, exact privacy/resources, private matching dSYM and independent extraction PASS. Owner final Live regression and scoped launch/main/Menu Bar/normal Quit/reopen smoke PASS. Final native300sperformance completed: parentCPU PASS, RSS REVIEW (start/max100.48MB, average88.11MB, end79.48MB), stable one owned Codex child. No unconditional100MB target PASS or leak claim. Owner scoped final review completed for this local unsigned RC: RSS REVIEW ACCEPTED by Owner for this finite v0.1.0 RC observation. D7-01–D7-08 done after individual original-criterion review; subsequent PR #10 integration and main CI 37614072470 SUCCESS; current exact hashes and evidence are in the [Day7 report](../reports/day-7-release-closeout-2026-10-07.md) and [final report](../reports/FINAL.md). Prior accepted/failed checkpoints preserved.

Earlier build-product packages and their zero-path claims remain historical **SUPERSEDED** records: independent extraction reproduced178LC_SYMTAB debug-map references. The corrected scanner is current authority. Failed artifacts are preserved, not overwritten or manually stripped.

The accepted candidate remains **UNSIGNED / UNNOTARIZED**. Public tag / publication await final Owner authorization; browser/Gatekeeper observation and installed/signed Login Item verification remain separate. The earlier NOT FOR PUBLIC DISTRIBUTION checkpoint predates this authorized unsigned Developer Preview preparation.

## B. Future Developer ID / notarization path (outside this phase)

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

Historical Day 7 did not create a tag, Release or DMG. This later preparation authorizes DMG and an unpublished draft only; public tag / publication remain separately gated. No signing, notarization submission or repository-rule change is authorized.

Official references: [Developer ID](https://developer.apple.com/developer-id/), [custom notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow). These describe signing/hardened runtime and notarytool/stapling; reading them does not constitute executing the signing plan.
