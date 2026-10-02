# Cleaner Lite — Read-only Developer Cache Scanner

Report path retains the owner's requested 2026-10-02 checkpoint name.
Actual session: **2026-10-03, Asia/Shanghai**.
Branch: `feature/cleaner-readonly`. Base/HEAD: `ed3e501f70c41bdaede0ac4fdb34dd20f1d2f0f5`.
Previous Maven-round fingerprint: `acf32cdc15494107dac4b4ed6afec19308886959cf030b47beba7e3b3673e7e6`.

**Current round:** see “Xcode 26.6 presentation compatibility — 2026-10-03” below. Final Owner acceptance and earlier Maven/discovery/Preview NOT_RUN checkpoints, paths and launch records remain historical evidence.
No commit, push or PR made.

**Owner-approved execution order adjustment:** Cleaner read-only work is intentionally executed before AI quota integration. Original plan/history remains intact. Task IDs, original days, points, acceptance criteria and D4 dependency history are unchanged.

## AUTOMATED

Final verification at `2026-10-02T17:15:49.022338+00:00`:

| Command/check | Exit | Result |
|---|---:|---|
| `./scripts/build.sh` | 0 | PASS |
| `./scripts/test.sh` | 0 | **170 tests, 0 failures** |
| `./scripts/verify.sh` | 0 | PASS |
| `git diff --check` | 0 | PASS |
| Progress/ledger verification | 0 | PASS |
| Visual assets validation | 0 | PASS |
| Source/config/manifest audit | 0 | PASS within the stated audit scope |

Original 124 tests remain unchanged. Added **46 tests**: Cleaner 27 + Maven 19. All real filesystem tests use private temporary directories/injected Home; no test scans real owner caches. Coverage includes allocated/logical size, empty/missing/permission/partial states, nested files, cancellation, root/ancestor/external/internal symlinks, repeated sessions, shared snapshot, Preview transitions, sleep cancellation, catalog boundaries, Maven discovery precedence/limits, marker filtering, small-size presentation and no double count.

Initial failures are not concealed: a fake sampler protocol mismatch, cancellation isolation, Foundation `/private/var` filesystem alias normalization, and `skipDescendants` on symlink entries were corrected. Maven URL comparisons now compare filesystem paths rather than trailing-slash URL identity. After the 167-test pass, a 170-test run hit the unchanged Network test `testRefreshStaleFailureAndManualCooldown` (observed 3 calls while 4 were expected); its IPv4 completion predicate can precede the independent IPv6 request. The subsequent full 170-test run and final verify passed without modifying Network implementation or tests. This existing asynchronous test timing sensitivity remains noted.

The first verify of the completed source passed doctor/build/unit/progress-tests/assets but failed the ledger's stale fingerprints. Current automated evidence was refreshed from actual passing results; old evidence stays in `evidence_history`. Historical owner UI confirmations were not rewritten or represented as new UI checks. Final ledger PASS follows that refresh.

Evidence: `.artifacts/verification.json`, `build.log`, `test.log`, `progress-tests.log`, `progress-verify.log`, `visual-assets-check.json`, `cleaner-verify-first.log`, `cleaner-verify-final.log`, `cleaner-audit.json`, `cleaner-preview.json` (all local/ignored).

## REAL SCAN

**owner authorized: NO — NOT_RUN.** No real cache traversal or real `.lastUpdated` traversal has been run. Only bounded Maven configuration discovery and root existence metadata were observed.

| Category | Candidate/root | Risk | Root metadata |
|---|---|---|---|
| Xcode DerivedData | `~/Library/Developer/Xcode/DerivedData` | Low | EXISTS |
| Gradle Cache | `~/.gradle/caches` | Caution | EXISTS |
| Maven Local Repository | discovered root below | Caution | EXISTS |
| Maven Failed Download Markers | same discovered root, filename suffix `.lastUpdated` | Low | EXISTS; marker count NOT_RUN |
| npm Cache | `~/.npm/_cacache` | Low | EXISTS |
| Homebrew Download Cache | `~/Library/Caches/Homebrew` | Low | EXISTS |

No whole-`.npm` fallback; user configuration is excluded. Installed runtimes, projects/source trees, Docker disks, whole Home/Library and system roots are not default categories.

### Maven discovery (no recursive scan)

Production `MavenRepositoryLocator` was compiled into an ignored local observer with the existing ExecutableResolver. It did not run Maven or any shell initialization, and did not enumerate repository contents.

| Field | Actual bounded observation |
|---|---|
| Maven executable | AVAILABLE in observer process PATH |
| Maven Home | `/Library/apache-maven-3.9.6` |
| User settings | NOT_FOUND |
| Global settings | FOUND |
| Resolved repository | `/Library/apache-maven-3.9.6/repository` |
| Source | Global Maven settings |
| State | resolved |
| GUI App PATH/executable | UNKNOWN / NOT_VERIFIED |
| Explicit JVM repository override | NOT_DISCOVERED |
| Project-specific repository override | NOT_DISCOVERED |

The global configuration selects the installation's `repository` directory; Maven Home itself was **not** used as the repository. The existence of `~/.m2/repository` does not override an explicit global setting. GUI and Terminal contexts can differ: this observer result does not prove the running App has the same PATH. App discovery occurs on the explicit Scan action, not on launch/appearance.

Resolution chain: user `.m2/settings.xml` → global settings under known `MAVEN_HOME`/`M2_HOME` or bounded executable-derived installation → default candidate `~/.m2/repository`. Explicit `maven.repo.local` has no reliable implemented source; it is NOT_DISCOVERED rather than guessed. An invalid higher-priority override remains Unresolved/Unavailable instead of silently selecting another directory.

XMLParser retains only top-level `settings/localRepository`, expands `${user.home}`, rejects unknown properties/relative paths, limits settings reads to 64 KiB and nesting/text size, and rejects DTD/entities. The bounded XML file is necessarily read for parsing; server credential elements are ignored by the delegate, never extracted, stored, logged or published. Settings/path symlink and permission failures are explicit. No `.mvn`/pom search, Maven invocation or network.

## MANUAL UI

**NOT_RUN / pending owner.** Starting the new build is not acceptance. No Scan button was activated.

Owner authorized only the normal restart of old PID 79373. SIGTERM completed; no SIGKILL or other process termination.

New App: `build-preview/MacSoul.Cleaner.bo40vox5/MacSoul.app`.
New PID: **99579**.
Executable SHA-256: `2f65cd8bfe44bcd778fbf897cab88eca41c12965a1df32f73c4f3b3d2429e4d3`.
The independent copy matches the verified binary and includes the existing Dock `.icns` and privacy manifest. Icon presence is a package check, not a new owner Dock approval.

Cleaner UI is bilingual: Scan/Rescan/Cancel, progress/state, category name/risk, full root path, usage estimate, counts, impact, sampled time; Maven adds source/resolution, independent markers and the included-in-parent warning. Unresolved Maven paths are not shown as resolved defaults and copy/reveal controls are disabled. Marker sizes use bytes/KiB/MiB/GiB so small files do not round to a misleading 0.00 GiB.

Reveal in Finder selects only the category root and is disabled when absent. Copy writes only the root path, with transient feedback. Overview reads the same CleanerSnapshot, shows no detailed paths and cannot start a scan. Menu Bar remains unchanged. Preview retains existing Mock fixtures; Live starts Not Run, with no Mock size substituted.

## SAFETY

One AppStore-owned CleanerSession launches one actor Scanner session. On-demand, off MainActor, sequential categories, streaming DirectoryEnumerator, counters only. Repeated Scan cannot create simultaneous collectors. Cancellation is checked each iteration; progress is throttled to 200ms with yields every 64 entries. Navigation away does not cancel an explicit scan; Preview/sleep/app termination cancel and generations reject old-cycle results. Tests prove repeated start/cancel and Preview/sleep behavior; actual sleep/quit UI remains untested this round.

Root and ancestor symlinks are rejected; internal symlinks skipped and counted. Lexical normalization uses URL.standardized; resolved paths are compared against the resolved root separately, avoiding Foundation's `/private/var` alias false rejection. DirectoryEnumerator does not descend symlinks; calling skipDescendants on a link was removed because it skipped unrelated siblings. Missing/inaccessible/partial/cancelled states are not available zero. Filesystems can change concurrently; Foundation metadata checks do not create an atomic filesystem snapshot or a hardened race-free traversal guarantee.

`CleanerScanTarget.matchingFiles(suffix:)` filters regular filenames during the metadata-only pass. Maven markers use the same discovered root as the repository and retain their own counts/size/state/date. Root exists with no markers = available/0 files/0 bytes; missing root = notFound. Marker contents are never read. The marker descriptor has `contributesToTotalEstimate = false`, so parent plus markers are not summed twice. This costs a second sequential streaming pass; no concurrent traversal or huge saved file list.

Size precedence: nonnegative totalFileAllocatedSize → fileAllocatedSize → logical fileSize fallback. Directory bytes are not added. Primary display GiB = 2^30 bytes. No global hard-link deduplication/APFS clone/shared-block accounting; estimate is not reclaimable space. Risk is usual recovery cost if a user later removes data, not a guarantee. Maven and Gradle remain Caution; markers are Low, not a cleanup promise.

Audit found no deleteItem/trashItem/removeItem, cleanup shell, sudo, user process termination, arbitrary UI path input, background scanner timer, auto-scan onAppear or network client in Cleaner product sources. Test teardown only removes test-owned temporary directories. System/Soul/Dev/Network model sources and Menu Bar contents match HEAD; only AppStore/Cleaner snapshot/UI wiring extends them. Project resource/build settings unchanged; existing generator was used only to include new Swift files, no Harness regenerated.

## PRIVACY

Results remain local. Report paths are home-relative or non-personal Maven installation paths. No filenames, projects, dependency URLs, marker contents, credentials or raw XML/errors are retained in this report/snapshot.

New traversal directly requests only isDirectory/isRegularFile/isSymbolicLink/fileAllocatedSize/totalFileAllocatedSize/fileSize resource keys. It does not request creation/modification timestamps, volume capacities, or directly call stat/lstat/getattrlist families. Comparing this exact direct API set with [Apple's Required Reason API list](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype) identified no new listed category to declare. This is a source/package audit; App Store Connect validation was NOT_RUN.

Existing manifest unchanged and verified in the packaged App:
- DiskSpace / 85F4.1
- UserDefaults / CA92.1
- SystemBootTime / 35F9.1

Allocated size semantics follow [Apple fileAllocatedSize](https://developer.apple.com/documentation/foundation/urlresourcevalues/fileallocatedsize) and [totalFileAllocatedSize](https://developer.apple.com/documentation/foundation/urlresourcevalues/totalfileallocatedsize). Maven configuration/source semantics follow [Maven settings](https://maven.apache.org/settings.html); marker diagnostic semantics follow [Maven Resolver local repository](https://maven.apache.org/resolver-archives/resolver-2.0.11/local-repository.html).

## PERFORMANCE

**Formal measurement: NOT_RUN.** No Instruments or resource stress tests. Streaming/cancellation/throttling are implementation properties, not measured performance claims. Large real repositories and the marker's second pass still need owner-authorized observation.

## NOT_RUN

- Real Cleaner/cache/marker scan: NOT_RUN, awaiting explicit authorization.
- Owner Cleaner UI/real results acceptance: NOT_RUN.
- GUI Maven executable context: UNKNOWN / NOT_VERIFIED.
- Formal Performance: NOT_RUN.
- Live AI Provider: NOT_RUN.
- Resource stress tests: NOT_RUN.
- App Store Connect privacy validation: NOT_RUN.
- Delete/Trash/Cleanup: NOT_IMPLEMENTED.
- Explicit JVM/project Maven repository overrides: NOT_DISCOVERED.
- Global inode/hard-link deduplication / APFS shared-block accounting: NOT_IMPLEMENTED.

D5-01/02 remain **verifying**. D4-01–07 and D5-03–06 remain **todo**. D2/D3 done statuses and historical human evidence remain unchanged. Generated docs/STATUS.md comes from tasks.json.

Worktree: 10 modified tracked files + 7 untracked new files, all Cleaner/models/UI/project registration/tests/architecture/status/ledger/report scope; index empty. No commit/push/PR. Stop for owner UI acceptance and real read-only scan authorization.


## Cleaner Discovery / Docker refinement — 2026-10-03

Owner request: keep D5-01/02 READ ONLY; replace static roots with bounded tool-specific discovery, expose source/fallback, and add Docker logical usage without VM traversal. D5-01/02 remain **verifying**. Original task IDs/days/points/acceptance/dependencies and historical human evidence remain intact. D4 and D5-03–06 are unchanged; no AI/Performance implementation.

### Implementation and source semantics

`CleanerLocator` resolves the catalog into URL/source/state before the existing streaming Scanner starts. Gradle uses `GRADLE_USER_HOME` then the labelled default, selecting `caches`; npm uses explicit cache environment then bounded direct `npm config get cache`, otherwise a labelled default, selecting only `_cacache`; Homebrew uses bounded `brew --cache` or a labelled default. Xcode uses its labelled default, without guessing preference keys. Maven retains bounded user/global settings discovery, and repository/markers share exactly one resolved root.

Known executable discovery reuses Dev's ExecutableResolver (bounded PATH + fixed bin prefixes), not a HOME/project search. Explicit invalid roots or failed/malformed configuration queries stay Unresolved/Unavailable, never disguised as an empty cache or successfully discovered default. The UI exposes source and “Default / fallback”; before discovery it labels roots as default candidates, not detected configuration. The production App invokes discovery only within the explicit Scan session.

### Actual bounded discovery — no recursive scan

An ignored observer compiled the production locator with the existing executable resolver and ShellRunner. It queried only root metadata/configuration and allowed Homebrew's read-only cache-location command. It did not invoke Scanner, Maven/Gradle builds or Docker. Its environment is this agent's process environment, **not verified as identical to the running GUI App**.

| Category | Resolved path | Source | Default/fallback | State |
|---|---|---|---|---|
| Xcode DerivedData | `~/Library/Developer/Xcode/DerivedData` | Xcode default location | YES | resolved |
| Gradle cache | `/Library/gradle-5.6.4/repository/caches` | `GRADLE_USER_HOME` | NO | resolved |
| Maven repository | `/Library/apache-maven-3.9.6/repository` | Global Maven settings | NO | resolved |
| Maven failed-download markers | same Maven root, suffix `.lastUpdated` | same global settings | NO | resolved; traversal NOT_RUN |
| npm download cache | `~/.npm/_cacache` | npm default location; npm executable unavailable in observer context | YES | resolved |
| Homebrew cache | `~/Library/Caches/Homebrew` | `brew --cache` | NO | resolved |

Docker CLI metadata: `/Applications/Docker.app/Contents/Resources/bin/docker` exists. Docker context **NOT_QUERIED / UNKNOWN**, daemon **NOT_QUERIED / UNKNOWN**, real usage **NOT_RUN**. No Docker CLI call was made because the owner requires all such calls to follow the explicit Cleaner Scan action. “CLI exists” is not proof that an Engine is running. Raw context configuration, credential files and endpoint credentials were not read or logged by the observer.

### Docker adapter / totals

Docker is an independent logical category in the single CleanerSnapshot/session. The direct command allowlist is context show, context inspect with an endpoint-only JSON format, and context/host-selected `system df --format '{{json .}}'`. No shell interpreter, cleanup, mutation, VM directory scan, Docker.raw/qcow2 accounting or network-provider implementation was added. Commands have 5s timeouts and bounded stdout/stderr; raw stderr/context payloads are not retained in the snapshot/report.

DOCKER_CONTEXT takes precedence over DOCKER_HOST; context selection is frozen for the subsequent usage query. Only a parsed Unix endpoint is counted as local. TCP/SSH/HTTP(S), including loopback tunnels, are conservatively remote: labelled Remote Docker Context, **not queried for usage** and not counted in this Mac's total. Invalid endpoints remain unavailable rather than falsely local/remote. CLI missing, context failure, daemon failure, malformed/truncated/unsupported output and cancellation stay distinct from valid zero.

Four JSON aggregate rows map to Images / Containers / Local Volumes / Build Cache. Docker formatted decimal SI sizes become approximate bytes and are displayed using binary units; they are logical Engine estimates, not physical sparse-VM allocation. The four rows contribute through one parent total only, with duplicate/missing kinds and overflow rejected. Marker bytes also remain excluded from a second contribution. Reclaimable is explicitly Docker-reported, not proof of safe deletion. Summary explains that file-allocation estimates and local Docker logical usage are mixed estimates.

### Tests, safety and pending acceptance

32 locator/Docker tests added in this refinement; final complete suite **202 tests, 0 failures** (original 124 + Cleaner 27 + Maven 19 + discovery/Docker 32). Tests cover environment/config/default sources, nonexistent/unsafe/malformed roots, Maven shared roots, local/remote context precedence, four JSON kinds/SI values/truncation/errors, once-only totals, single shared Session updates, and cancellation propagation through the existing ShellRunner managing only its launched child. Docker CLI/daemon/context tests use fixtures/mocked runners; no real Docker process or daemon was invoked. Cancellation uses a MacSoul-owned test child, never a user's process.

Final grep and code review found no destructive APIs/arguments in product Cleaner code. Existing System/Dev/Network/Soul/ShellRunner source files, Menu Bar, project resource phase/build settings and privacy manifest are unchanged from HEAD. Packaged manifest retains exactly DiskSpace/85F4.1, UserDefaults/CA92.1 and SystemBootTime/35F9.1. Baseline ledger fields and historical owner confirmations were checked against HEAD. No Harness regeneration or image generation.

Initial verify runs passed doctor/build/unit/progress-tests/assets but failed stale ledger fingerprints. Automated evidence was refreshed from actual passing results with prior records appended to evidence_history; human UI confirmations were retained unchanged. This refresh does not represent updated Cleaner UI acceptance.

Evidence: `.artifacts/cleaner-discovery/refinement.json`, `.artifacts/cleaner-discovery-audit.json`, `.artifacts/cleaner-discovery-verify-first.log`, `.artifacts/cleaner-discovery-verify-source.log`, `.artifacts/cleaner-discovery-verify-final.log`, `.artifacts/verification.json`, `.artifacts/test.log` (local ignored files).

Protocol references: [Docker system df / format](https://docs.docker.com/reference/cli/docker/system/df/), [Docker context/environment precedence](https://docs.docker.com/reference/cli/docker/), [npm config](https://docs.npmjs.com/cli/v11/commands/npm-config/), [Homebrew --cache](https://docs.brew.sh/Manpage). These support command/format choices; installed Docker response compatibility still needs real owner-authorized Scan acceptance.

**REAL SCAN: NOT_RUN.** Updated Cleaner UI: pending owner. Docker installed-CLI context/daemon/usage: NOT_RUN. Formal Performance and Live AI Provider: NOT_RUN. No real cleanup or stress test. No commit, push or PR. No process termination or automatic App restart in this refinement; previous launch records above are historical.

### Final verification and prepared App

Final manifest timestamp: `2026-10-02T17:44:40.105834+00:00`. HEAD: `ed3e501f70c41bdaede0ac4fdb34dd20f1d2f0f5`; uncommitted source fingerprint: `7bae20e18a4a0604b0a0ff6702672e2bf69eedcb0bbc0627ebfc5d0303c779a0`.

| Command/check | Exit | Result |
|---|---:|---|
| `./scripts/build.sh` | 0 | PASS |
| `./scripts/test.sh` | 0 | PASS |
| `python3 scripts/test_progress.py` | 0 | PASS |
| `python3 scripts/verify-visual-assets.py` | 0 | PASS |
| `python3 scripts/verify_progress.py` | 0 | PASS |
| `./scripts/verify.sh` | 0 | PASS |
| `git diff --check` | 0 | PASS |

202 tests / 0 failures; original 124-test regression retained. No additional product-source changes after this verification.

Prepared independent App: `build-preview/MacSoul.CleanerDiscovery.izar1ihd/MacSoul.app`, launch-stub SHA-256 `2f65cd8bfe44bcd778fbf897cab88eca41c12965a1df32f73c4f3b3d2429e4d3`, compiled Debug code (`MacSoul.debug.dylib`) SHA-256 `c24293deb5ae4b17943c1ce3e1f0829f67733b3c4769616a04019774aacbaba9`. **NOT_LAUNCHED**, no new PID. Both launch stub and compiled Debug library match the verified build; the copy retains icon/privacy resources. Xcode Debug uses a stable launch stub, so its hash alone is not a code-revision fingerprint. The first package-check assertion omitted the `.icns` extension from CFBundleIconFile; correcting this validation confirmed the existing icon file without modifying resources. `.artifacts/cleaner-discovery-preview.json` records package evidence; package checks are not manual UI acceptance.

Worktree: 10 modified tracked files + 10 untracked files (Cleaner source/presentation/test/report); index empty. No commit/push/PR, no task-scope expansion. Stop for owner discovery confirmation.


## Cleaner Content Preview — 2026-10-03

Owner-approved v0.1.0 boundary is **Discovery + Scan + Explain + Content Preview**, strictly READ ONLY. Existing CleanerLocator/resolution, Summary Scanner, size/risk semantics, source/fallback labels, Maven/Gradle cache groundwork, Docker adapter and earlier tests are retained. v0.2.0 cleanup / Maven-Gradle Build Tools / Docker storage-cleanup extensions are roadmap only, recorded in docs/SCOPE.md; original task points/days/acceptance/dependencies/history are unchanged.

### Preview architecture / models

- AppStore owns one CleanerPreviewSession and publishes its destination/snapshot. Only an explicit View contents action starts a Preview traversal, using an already resolved category from the shared Cleaner snapshot. Before resolution or during Summary Scan the action is unavailable. View bodies do not launch discovery, recursive enumeration, shell or Docker queries.
- CleanerPreviewScanner is an actor with one active traversal; Summary remains aggregate-only. Preview streams direct children into a bounded list of at most 2,000 records, then sequentially calculates directory child aggregates using the existing CleanerScanner with discovery/Docker disabled. No full tree or persistent result URL list is built. The limit is explicitly labelled Partial, with sorting limited to displayed entries rather than a claim about all children.
- CleanerPreviewItem contains stable root-relative ID, name, relativePath, URL, file/directory/symlink/other kind, optional estimatedAllocatedBytes and childCount, explicit state and isSymlink. Missing/inaccessible/not-estimated are distinct from valid zero. File sizes use the existing total allocated → allocated → logical fallback; directory metadata is not added. Directory counts, where present in the model, count included file/directory descendants. UI does not add a separate count column.
- A native SwiftUI Table displays Name / Type / Disk usage, defaults to largest known estimate first, and supports name ordering without new I/O. Directory items show Calculating while pending. Direct listings and terminal states publish immediately; intermediate updates are throttled to 200ms. This is an implementation property, not measured performance evidence.

### Navigation and safety

Only a resolved category can establish the boundary. Pure root/source availability checks are used by UI; actual root/ancestor/link/containment checks execute in the Scanner actor. Preview verifies direct-child membership and lexical/resolved containment. Ancestors are checked before missing leaves, so links are rejected explicitly. Root changes to a symlink, symlink ancestors, `../`, siblings and outside URLs are rejected; there is no arbitrary path input, HOME browser or general filesystem browser.

Links appear as “Symbolic link · not followed”, with no target size or drill-down. Directory child aggregation inherits the existing Scanner's streaming containment/cancellation behavior. Files changing concurrently, hard links and shared APFS blocks remain estimate limitations; Preview is not an atomic filesystem snapshot or reclaimable-space promise. Maven-marker Preview uses the existing matching-files target and labels the exclusion of other file sizes; it does not inspect marker contents.

Directory entry buttons / double-click navigate lazily. Back and known breadcrumb ancestors request only the next selected level. Session cancels the previous task and awaits it before starting the replacement; stale generation updates are discarded. Repeated opening does not add a second active scanner. Closing Detail/section, switching categories or Developer Preview, sleep and App termination cancel Preview. Summary and Preview recursive sessions are mutually exclusive at AppStore, including cancellation completion. Wake and appearance never restart them.

### UI / Docker

Category primary action is View contents; Finder remains secondary and Copy path moves to an ellipsis menu with copied feedback. The in-app Sheet shows category name, resolved root/source/fallback, earlier category estimate, risk/explanation/impact, breadcrumbs, sorting, cancellation and the native table. Item context menus only Reveal in Finder / Copy path. No selection checkboxes, cleanup, Trash or destructive commands.

Docker View contents displays the existing logical Images / Containers / Local Volumes / Build Cache rows, optional reported reclaimable estimates and current state/context from the shared snapshot. It does not call Docker again, enumerate image/container IDs or scan VM files. Unavailable/not-queried states remain explicit. Real installed Docker format/context/daemon validation remains NOT_RUN until an explicit owner Scan action.

### Tests and actual corrections

35 Preview tests added to the prior 202-test suite. All filesystem fixtures are private temporary directories. Coverage includes direct children, allocated regular files, child directory aggregate, largest-first/name sorting, valid zero/empty directories, drill-down/back/breadcrumbs, nonexistent/inaccessible entries, visible unfollowed external links, nested links, ancestor/root links and root replacement, outside/`../`/forged paths, source/custom-root preservation, cancellation, repeated and active category switches, close/mode/sleep cancellation, Summary/Preview exclusion, content/tree unchanged, 2,000-entry cap, Docker logical-row reuse and bilingual copy.

Initial test compilation failed because new test samplers used outdated protocol signatures and a nonexistent SystemReading timestamp field; the test doubles were corrected to existing interfaces, without changing those interfaces. The first executable 232-test run found ancestor-link-under-missing-child state incorrectly reported Not Found; ancestor-first checking was implemented and subsequent 235/237-test runs passed. No tests were removed or relaxed to hide this issue. Active close/category-switch tests verify traversal cancellation after listing begins, beyond merely cancelling a not-yet-started task.

Final safety grep/code review found no destructive Cleaner API/arguments and no Process/ShellRunner/Docker invocation in Preview. Existing System/Soul/Dev/Network/ShellRunner sources and Menu Bar are unchanged. Xcode source/test registration only; resource phase/build settings unchanged. No Harness/image regeneration. Packaged privacy manifest retains DiskSpace/85F4.1, UserDefaults/CA92.1 and SystemBootTime/35F9.1, with no new resource metadata keys or unsupported privacy declarations. App Store Connect validation remains NOT_RUN.

First final-source verify passed doctor/build/unit/progress/assets and failed only stale ledger fingerprints. Actual automated evidence was refreshed with old entries preserved in evidence_history, then verify rerun; human approvals were retained unchanged. Build/unit results do not represent Preview UI approval.

Evidence (local ignored): `.artifacts/cleaner-preview-build-final.log`, `.artifacts/cleaner-preview-test-first.log`, `test-second.log`, `test-third.log`, `test-fourth.log`, `test-final.log` with cleaner-preview prefix; `.artifacts/cleaner-preview-verify-first.log`, `.artifacts/cleaner-preview-verify-final.log`, `.artifacts/cleaner-preview-audit.json`, `.artifacts/verification.json` and standard build/test/progress logs.

### Remaining acceptance / task state

D5-01/02 remain **verifying**. D5-03–06 and AI tasks are unchanged. Original plan and historical owner acceptance are preserved. **REAL SCAN: NOT_RUN**, real Preview: NOT_RUN, Owner Preview UI: pending. Docker CLI/daemon/usage real query: NOT_RUN. Formal Performance and Live AI Provider: NOT_RUN. Resource stress tests NOT_RUN. **Cleanup: NOT_IMPLEMENTED BY DESIGN**. No commit/push/PR.

### Content Preview final verification / package

Final verification: **2026-10-03 02:35:58 +08:00 (Asia/Shanghai)**. HEAD/base `ed3e501f70c41bdaede0ac4fdb34dd20f1d2f0f5`, uncommitted source fingerprint `3f36109c06bbcce39145cfea9a4184d2e1dc29f837c0c49a000c5ce3924d72e0`.

| Command/check | Exit | Result |
|---|---:|---|
| `./scripts/doctor.sh` | 0 | PASS |
| `./scripts/build.sh` | 0 | PASS |
| `./scripts/test.sh` | 0 | PASS |
| `python3 scripts/test_progress.py` | 0 | PASS |
| `python3 scripts/verify-visual-assets.py` | 0 | PASS |
| `python3 scripts/verify_progress.py` | 0 | PASS |
| `./scripts/verify.sh` | 0 | PASS |
| `git diff --check` | 0 | PASS |

**237 tests / 0 failures**, including 35 new Preview tests and all prior 202 tests. No product-source edits after final verification.

Prepared App: `build-preview/MacSoul.CleanerPreview.5cldiyze/MacSoul.app`. **NOT_LAUNCHED; new PID = none.** No running App terminated in this round. Both launch stub and compiled Debug library match the verified build; icon and original privacy resources are present. Compiled `MacSoul.debug.dylib` SHA-256 `53a37ceaf64d4608c7db1699ad235e85325de2a4f399286f49bf2bcd7f8d8bce`. Package evidence `.artifacts/cleaner-content-preview-package.json`. Packaging does not prove manual UI acceptance.

Worktree: 11 modified tracked files + 13 untracked Cleaner source/presentation/test/report files; index empty. This includes retained earlier Cleaner work. No commit/push/PR; no real cache, Docker or Preview enumeration outside temporary tests. Stop for Owner acceptance.


## Final Owner acceptance — 2026-10-03

The following real Scan/Preview/Docker results are **explicit Owner-reported acceptance in this session**, superseding the earlier NOT_RUN checkpoints above without deleting them. The agent did not repeat a full real Cleaner Scan or any real Docker query during closeout.

### Real Cleaner Scan / Content Preview

**REAL CLEANER SCAN = PASS.** Owner ran the real Scan: seven categories, approximately **17.66 GiB** estimated total. Category size/source/risk/explanation were accepted; Maven failed-download markers do not contribute a second time to the Summary total.

**CONTENT PREVIEW UI = PASS; OWNER UI ACCEPTANCE = PASS.** Owner accepted in-app Preview as the primary View contents action, direct children, directory drill-down, root Back disabled, descending size sort, file/directory kinds and read-only explanation. Finder / Copy Path remain auxiliary. Gradle, Maven Repository, Maven Failed Download Markers, npm and Homebrew Previews passed. Xcode Preview passed with the zero-byte note checked independently below.

### Xcode zero-byte read-only sanity check

At **2026-10-03 02:46:13 +08:00**, an independent metadata-only traversal of the resolved Xcode DerivedData root used `os.scandir` and `lstat`, counted regular files, and summed their POSIX allocated bytes (`st_blocks * 512`) independently of the production Preview/Scanner. Root and ancestors were checked against symbolic links; entries were not followed through links. No target content was read or written.

Result: **7 direct child directories, 49 directories recursively, 0 regular files, 0 symlinks, 0 other entries, 0 access errors; 0 allocated bytes and 0 logical bytes for regular files**. This agrees with the Owner's 0 files / 49 directories / 0 bytes observation. There are no regular-file bytes for Preview to aggregate at this checkpoint. Directory metadata allocation is deliberately excluded by the existing size definition. **Sanity check PASS; no aggregate omission found, no size algorithm change made.** This is a point-in-time read-only observation, not a guarantee that DerivedData remains empty after subsequent builds.

Local ignored evidence: `.artifacts/cleaner-xcode-sanity.json`. This specific traversal was explicitly authorized by the Owner; no other real cache was traversed in closeout.

### Real Docker read-only queries

| Owner-observed operation | Final acceptance |
|---|---|
| REAL DOCKER CONTEXT QUERY | PASS; CLI discovered, context `desktop-linux` |
| REAL DOCKER DAEMON QUERY | PASS; daemon reachable |
| REAL DOCKER USAGE QUERY | PASS |

Owner observed Images approximately **1.69 GiB**, Containers / Local Volumes / Build Cache **0**, logical total approximately **1.69 GiB**, Docker-reported reclaimable approximately **1.69 GiB**. The Engine estimate is labelled explicitly, does not promise safe reclaimable physical bytes, and contributes once. No Docker.raw or Desktop VM filesystem scan, cleanup or prune was offered/performed.

### Presentation / release boundary

Preview's third column changes from “占用空间” / “Disk usage” to **“估算占用” / “Estimated Usage”**. The existing bilingual presentation test now asserts both exact labels. Only the column label/presentation dictionary changed; allocated/logical fallback, APFS clone/sparse/shared-block/hard-link limitations and aggregation semantics remain unchanged. The new label is automatically tested; no additional full UI session is claimed after this label edit.

v0.1.0 remains Discovery + Read-only Scan + Explain + Content Preview + Drill-down + Docker read-only logical usage. **Cleanup = NOT_IMPLEMENTED BY DESIGN.** Cleanup, Trash, selection, cleanup confirmation, Maven/Gradle Build Tools and Docker cleanup/storage extensions are deferred to separately authorized v0.2.0 work.

Formal Performance measurement and Live AI Provider remain **NOT_RUN**. No artificial resource stress test was performed. Historical Memory Pressure Critical real event remains NOT_OBSERVED. App Store Connect validation remains NOT_RUN. Real Scan and UI acceptance do not imply formal performance, cleanup safety, AI integration or all interactions are verified.


### Final closeout verification / ledger

Verified at **2026-10-03T02:49:12.045754+08:00 (Asia/Shanghai)**. HEAD/base `ed3e501f70c41bdaede0ac4fdb34dd20f1d2f0f5`; verified uncommitted source fingerprint `8de83f956851a6dd5ce13a189d73a38dd898b47b3e002d9f5a3d54a51dfcf242`.

| Command/check | Exit | Result |
|---|---:|---|
| `./scripts/build.sh` | 0 | PASS |
| `./scripts/test.sh` | 0 | **237 tests / 0 failures** |
| `./scripts/verify.sh` (final rerun) | 0 | PASS |
| `python3 scripts/test_progress.py` | 0 | PASS |
| `python3 scripts/verify_progress.py` | 0 | PASS; ledger |
| `python3 scripts/verify-visual-assets.py` | 0 | PASS |
| `git diff --check` | 0 | PASS |
| Untracked source/report whitespace check | 0 | PASS |
| Packaged privacy manifest / unchanged reason audit | 0 | PASS |

All prior System/Soul/Dev/Network tests and all Cleaner/Preview/Docker tests remain passing. The bilingual Estimated Usage assertions extend the existing Preview test; test count remains 237 (35 Preview tests). First verify exited 1 solely for stale ledger fingerprints after the presentation/generator changes; doctor/build/unit/progress-tests/assets passed. The 43 affected automated evidence records were refreshed from those actual passing results with previous entries retained in evidence_history; subsequent verify passed, without altering historical manual approvals. Original points/days/acceptance/dependencies remain intact.

**D5-01 = done; D5-02 = done.** D4-01–07 and D5-03–06 remain todo. Day 2/3 states and historical acceptance are unchanged. STATUS was regenerated using `python3 scripts/generate_status.py`; it now includes the Owner's final Cleaner acceptance. The generic verification manifest's `manual_ui` / `live_provider` NOT_RUN fields describe checks not performed by that automated script; actual Owner Cleaner acceptance is independently recorded here and in tasks.json, and does not imply Live AI Provider acceptance.

Source audit confirms Cleaner Scanner/Discovery/Preview models, Docker/Maven adapters and size semantics unchanged from the previously validated Preview checkpoint. Only Preview label/presentation, two assertions in the existing test and acceptance-aware status generation changed during closeout, plus ledger/report/generated status. Existing System/Soul/Dev/Network/ShellRunner/Menu Bar and PrivacyInfo source remain identical to HEAD. The built PrivacyInfo matches source and contains exactly DiskSpace/85F4.1, UserDefaults/CA92.1 and SystemBootTime/35F9.1.

Evidence (ignored local): `.artifacts/cleaner-closeout-build.log`, `.artifacts/cleaner-closeout-test.log`, `.artifacts/cleaner-closeout-verify-first.log`, `.artifacts/cleaner-closeout-verify-final.log`, `.artifacts/cleaner-closeout-audit.json`, `.artifacts/cleaner-xcode-sanity.json`, `.artifacts/verification.json` and standard build/test/progress logs. The earlier NOT_RUN checkpoint evidence files remain unchanged.

Worktree: `feature/cleaner-readonly`, **11 modified tracked + 13 untracked files**, all within retained Cleaner implementation/tests/wiring/project registration and documentation/ledger. Index empty; no commit, push or PR. No App restart, real process termination, resource stress test, additional Docker query or v0.2.0 work in closeout. Stop for code review.


## Xcode 26.6 presentation compatibility — 2026-10-03

### Confirmed CI error / narrow repair

The original PR #6 CI (`553a19d`) and diagnostic-only follow-up (`4ad353e`) failed build/test with exit 65 on **macOS 26.6.2 / Xcode 26.6, build 17F113**. The retained failure-only workflow step exposed the real error in `CleanerView.swift:92:21`: “the compiler is unable to type-check this expression in reasonable time; try breaking up the expression into distinct sub-expressions”. Ledger failure followed failed build/unit and was not bypassed. Diagnostic CI: https://github.com/liu-657667/macsoul/actions/runs/37054247733 .

Minimal presentation-only refactor adds `cleanerResolutionDescription(_:) -> String` and `cleanerMavenLocationDescription(_:) -> String` in CleanerPresentation. Resolution copy uses typed String components joined by the same ` · ` delimiter and includes fallback only for the same existing sources. Maven state mapping uses an exhaustive switch. CleanerView now passes each helper result into Text; fonts, colors, layout and exact localized strings are preserved. No changes to model/scanner/locator/discovery/Preview/Docker behavior, sampling, project/deployment target or version boundaries. The diagnostic workflow is retained unchanged; CI was not upgraded to Xcode 27.

Five new exact-output tests cover fallback resolution in English/Chinese, non-fallback resolution in both languages/all states, Maven resolved, and Maven notFound/unresolved/unavailable in both languages. Existing tests were not edited or relaxed. **242 tests, 0 failures** (237 retained + 5 presentation tests).

### Actual local clean verification

Local: **macOS 27.0.1 / 26A434; Xcode 27.0 / 27A266a**. Developer directory `/Applications/Xcode.app/Contents/Developer`. Before build, only the explicitly authorized `.artifacts/DerivedData` and `.artifacts/MacSoulTests.xcresult` were removed. Build therefore did not reuse previous DerivedData; test started without the previous result bundle. No owner cache traversal or Docker query occurred.

Verified at **2026-10-03T03:35:13.741078+08:00 (Asia/Shanghai)** against HEAD/base `4ad353e6438c8a0efb4d6ebaa7a1f5bf6d402a72` plus the unchanged-source content identified by fingerprint **`acc09a96fe842b6ee38c180ffb5be025ad5d29915772c5a26d11023f845eb594`**.

| Command/check | Exit | Result |
|---|---:|---|
| `./scripts/build.sh` after DerivedData removal | 0 | PASS, local Xcode 27 |
| `./scripts/test.sh` | 0 | 242 tests / 0 failures |
| `./scripts/verify.sh` (final rerun) | 0 | PASS |
| Progress tests / ledger / visual assets | 0 | PASS |
| Packaged privacy manifest | 0 | PASS; existing three reasons unchanged |
| `git diff --check` | 0 | PASS |

First verify exited 1 only for stale ledger fingerprints after the authorized presentation/test edits; doctor/build/unit/progress-tests/assets passed. Forty-three automated evidence records were refreshed from actual passing checks, appending previous records to evidence_history. Every task field outside automated evidence/history remains unchanged, including Owner manual acceptance. A change-log entry records the compatibility checkpoint. D5-01/02 remain **done**, D4-01–07 and D5-03–06 remain **todo**, and STATUS was regenerated with no content change.

**Local Xcode 27 PASS; Xcode 26.6 compatibility awaiting CI at this pre-push checkpoint.** Local success does not prove older-toolchain compatibility. Push and pull_request macos checks on the resulting commit are the required final evidence. If either still fails, inspect the diagnostic log before any further repair; no speculative changes are authorized here.

Evidence: `.artifacts/cleaner-xcode-compat-verify-first.log`, `.artifacts/cleaner-xcode-compat-verify-final.log`, `.artifacts/cleaner-xcode-compat-audit.json`, `.artifacts/verification.json`, `.artifacts/build.log`, `.artifacts/test.log`. These remain ignored local outputs. Historical real Scan/Preview/Docker acceptance is retained, not repeated. **Cleanup NOT_IMPLEMENTED BY DESIGN; formal Performance / Live AI Provider / App Store Connect privacy validation NOT_RUN.** No PR merge, deployment-target change or scope expansion.
