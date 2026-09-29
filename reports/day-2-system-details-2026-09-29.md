# Day 2 System Details — 2026-09-29

## Scope and revision

- Branch: `feature/system-details`; base HEAD and `origin/main`: `6cbc4c8e28a624773dfd7980b7a6046c39824d40`.
- Source and verification-input fingerprint: `19fca726e360d6eb858d7b6400347deaa67119211d48639f57b95aad4ac155fa`.
- This is uncommitted work. D2-01 through D2-07 are `done` following owner UI acceptance of the remaining Disk, Battery, Memory Pressure and process-CPU cases. Earlier CPU, memory numeric, window and menu-bar acceptance remains recorded in `reports/day-2-system-soul-2026-09-29.md`.
- No Network, Dev Environment, AI Provider, Cleaner, process termination, Disk/Battery Soul state, Notch or README feature claim was added.

## Implementation and data definitions

| Metric | Native source and formula | Availability and cadence |
|---|---|---|
| Disk | Root `/` volume `volumeTotalCapacityKey` and `volumeAvailableCapacityKey`; used bytes = total − available, used % = used bytes / total bytes × 100. Capacity display uses GiB (2³⁰ bytes). | Immediate on Live entry; cached and refreshed about every 60 seconds. Invalid/failed read is unavailable, never the Mock 67%. APFS purgeable and shared-container behavior may differ from Storage Settings. |
| Battery | IOKit Power Sources description and internal-battery presence, capacity, charging and power-source keys. | Initial read plus IOKit power-source change notification; 60-second fallback only if notification registration fails. No internal battery is distinct from API failure; neither becomes 0% or Mock 78%. |
| Developer processes | `proc_listpids`, `proc_name`, `proc_pidinfo(PROC_PIDTASKINFO)`; resident size is RSS. CPU % = Δ(user + system CPU nanoseconds) / Δwall-clock nanoseconds × 100. A busy logical CPU is 100%; multithreaded processes can exceed 100%. | About every 3 seconds while System is visible and 15 seconds otherwise. First/invalid CPU delta is unknown. Inaccessible or exited PIDs are skipped; failed enumeration marks the list unavailable. Top five sort by CPU descending, then RSS. |

The developer classifier accepts an exact, conservative set of IDE/build, runtime, package and service names, plus `com.docker.*`. High CPU alone does not imply a developer process. Overview, System and Menu Bar read one `AppStore` snapshot; the additional samplers run through the existing `SensorHub` and do not block its CPU/memory loop. CPU/memory remain about 1 second on System and about 5 seconds otherwise. Disk, battery and process readings do not drive Soul. AI quota, Network and Dev Environment remain Mock in Live System mode.

The root-volume capacity keys are covered by the App's `PrivacyInfo.xcprivacy` Disk Space reason `85F4.1`, for showing disk space to the user. The existing app preference use is declared with UserDefaults reason `CA92.1`. The manifest is in the built App's `Contents/Resources`.

## Automated verification

| Check | Result | Evidence |
|---|---|---|
| `./scripts/build.sh` | PASS, exit 0 | `.artifacts/build.log` |
| `./scripts/test.sh` | PASS, exit 0; **44 tests, 0 failures** (35 baseline + 9 added) | `.artifacts/test.log` |
| `./scripts/verify.sh` | PASS, exit 0; doctor, build, unit, progress tests, visual assets and ledger each PASS | `.artifacts/verification.json`, `.artifacts/verify-run.log` |
| `git diff --check` and `git diff origin/main...HEAD --check` | PASS, exit 0 | Command output; the latter checks committed range only, so the former covers this uncommitted change set |
| Privacy manifest | `plutil -lint` PASS; found in built App bundle | `MacSoul/Resources/PrivacyInfo.xcprivacy`, `.artifacts/DerivedData/Build/Products/Debug/MacSoul.app/Contents/Resources/PrivacyInfo.xcprivacy` |

Unit coverage includes byte-based Disk calculation and failures; battery charging/discharging, absence, malformed and failed descriptions; process first sample, CPU delta, >100%, PID disappearance/counter reset, inaccessible PID, enumeration failure, classification and sorting; independent cadence; shared snapshot Live/Mock separation and detail failure clearing. Existing Soul and quota tests remain passing. The ledger's previous current evidence entries were preserved in `evidence_history` and refreshed against the passing current fingerprint; historical hashes and original task points were not changed.

## Real read-only observation

Executed a two-sample native API probe with about 3.1 seconds between process samples; evidence: `.artifacts/system-details-observation.log`.

- Root volume: total **994,662,584,320 bytes** (926.4 GiB); available **567,797,030,912 bytes**; used **426,865,553,408 bytes** (397.5 GiB), **42.9%** by raw bytes.
- This Mac reports an internal battery at **100%**, charge state **full**, external power **connected**. An actual no-battery Mac was not available for manual observation; that branch is unit tested.
- Five developer-process rows were returned on both samples, including Java, Xcode and Node. The first CPU values were unknown; the second sample produced CPU values (these processes happened to be idle at about 0.0%). No synthetic load was created.
- No Activity Monitor or Storage Settings side-by-side timing comparison was performed for this round.

## Acceptance boundary

- With owner permission, only the previous preview PID `84680` received SIGTERM and was confirmed exited. `./scripts/run-mock.sh` then launched this branch's build at `build-preview/MacSoul.t7Qrjy/MacSoul.app` as PID `77065`. The preview executable SHA-256 matched the current Debug build (`2f65cd8bfe44bcd778fbf897cab88eca41c12965a1df32f73c4f3b3d2429e4d3`). This proves build identity, not UI behavior.
- **MANUAL UI: PASS for the requested Day 2 System Details scope.** Owner-confirmed results and earlier checkpoints are recorded below. Preview fixtures and empty/error states are covered by unit tests, not by the owner's actual UI acceptance.
- **Memory Pressure natural Warning: PASS.** Critical was not observed and is not a blocker for this acceptance; no deliberate memory exhaustion test.
- **Formal Performance: NOT_RUN.** No Release/no-debugger sustained CPU or memory measurement, no helper-process budget claim.
- **Live AI Provider: NOT_RUN.** AI quota, Network and Dev Environment remain Mock.
- **Real sleep/wake and physical no-battery device UI: NOT_RUN.** No artificial pressure, battery discharge, large disk write or process termination test.

## Owner's continuing manual acceptance

The owner compared the running Live System build with macOS and reported the following. These observations extend the read-only probe above; they do not change its original sample or the Disk formula.

### Disk — PASS

macOS Storage details showed **426.8 GB used / 994.66 GB total**. MacSoul showed about **397.7 GiB used / 926.4 GiB total / 43% used**. In decimal GB, 397.7 GiB is about 427.0 GB and 926.4 GiB is about 994.7 GB. The owner accepted Disk total, used, used percent and the GB/GiB display convention as **PASS**. The human comparison uses Storage's used/total values; no formula adjustment to match a separate available-space field is requested.

### Battery — earlier checkpoint, before reinsertion

The owner confirmed the initial **100%** read, then physically unplugged external power and observed MacSoul change to **discharging** and **external power disconnected**. The charge fell naturally from **100% to 99%**, and macOS and MacSoul both showed **99%** at the same time. This confirmed automatic updates for the unplug and observed charge change without deliberately draining the battery. At this checkpoint, reinsertion was still pending and D2-04 remained `verifying`; the later result is recorded below.

### Top Developer Processes — partial PASS, CPU dynamics pending

The System page displayed real **Xcode**, **java** and **node** entries. The owner accepted process enumeration, conservative developer classification, PID display and RSS display as **PASS**. Process CPU was mostly **0.0%** in the observed screenshot. The remaining manual check is to run one normal development task (for example `./scripts/test.sh` or an Xcode Build) and observe for 5–10 seconds that at least one developer process shows nonzero CPU which changes as that task starts and finishes. No deliberate full load, >100% result or process termination is required. **D2-05 remains `verifying`.**

At this earlier checkpoint D2-03 remained `verifying` because a natural Memory Pressure warning/critical event had not yet been observed. The later result is recorded below. No code, commit, push or PR was made for that acceptance update.

## Owner's follow-up acceptance

- **Battery reconnect: PASS.** After external power was reinserted, MacSoul showed **96%**, **Charging**, and **External power: Connected**. Together with the earlier 100% initial read, unplug/discharge transition and natural 99% update matching macOS, this confirms the initial read, unplug event, discharge state, percentage update, reconnect event and charging state in the running App. Disk had already passed its total, used, percent and unit comparison. **D2-04 is now `done`.**
- **Process lifecycle: PASS for disappearance.** After the owner normally quit DataGrip, its corresponding Java helper disappeared automatically from Top Developer Processes. This confirms repeated enumeration, disappeared-PID removal and shared snapshot/UI refresh. The classifier was not changed. Enumeration, classification, PID and RSS were already accepted. The remaining check is a nonzero per-process CPU delta during a normal development task, observed changing as the task begins and ends. **D2-05 remains `verifying`.** No process was terminated by MacSoul or this agent.
- **Natural Memory Pressure Warning: PASS.** During ordinary use, the System page displayed **Warning · Live** from the native pressure source without an artificial memory-exhaustion test. Memory Used numeric value, separate unknown/normal states and native event-mapping unit tests had already passed. **D2-03 is now `done`.** A real critical event was **NOT_OBSERVED** and is not required to complete this acceptance.

At that checkpoint, formal Performance and Live AI Provider remained **NOT_RUN**, and the MacSoul App was kept running for the final process-CPU check. That follow-up changed acceptance records and status generation only; it did not change App implementation, commit, push or create a PR.

## Final owner process-CPU acceptance

During a normal Maven Java project build (`mvn -DskipTests compile`), the System page showed a newly active **java** process at **10.3% CPU**, **1.3 GiB RSS**, PID **10707**. The owner accepted process enumeration, developer classification, PID/RSS, disappeared-PID removal, newly active process appearance, CPU delta and ranking/update as **PASS**. Earlier DataGrip exit had already demonstrated removal of its Java helper. No synthetic CPU saturation or >100% load was created; >100% multicore semantics remain covered by the implementation and unit tests. **D2-05 is now `done`.**

With the previously accepted Disk/Battery chain (D2-04) and naturally observed **Warning · Live** memory-pressure event (D2-03), all D2-01 through D2-07 implementation tasks are `done`. A real critical memory-pressure event remains **NOT_OBSERVED** and is not an acceptance blocker. Formal Performance measurement and Live AI Provider remain **NOT_RUN**. There was no artificial CPU/memory pressure test. This final acceptance update changed records and status generation only; no App implementation changed and no commit, push or PR was made.

### Final verification after acceptance update

- `./scripts/build.sh`: PASS, exit 0; `.artifacts/build.log`.
- `./scripts/test.sh`: PASS, exit 0; **44 tests, 0 failures**, including the existing CPU/Memory/Soul cases and the new Disk/Battery/process cases; `.artifacts/test.log`.
- `./scripts/verify.sh`: final PASS, exit 0. Doctor, build, unit, progress tests, visual assets and ledger all PASS; `.artifacts/verification.json` and `.artifacts/verify-final-system-details.log`. The first run after the status generator changed had passing build/unit and a ledger failure solely from stale current-evidence fingerprints. Old entries were preserved in `evidence_history`; current entries were refreshed from passing checks against fingerprint `19fca726e360d6eb858d7b6400347deaa67119211d48639f57b95aad4ac155fa`, then verification passed. Historical package hashes and original points were not changed.
- `git diff origin/main...HEAD --check` and `git diff --check`: PASS, exit 0. HEAD is still the base commit, so the first command has no committed range to examine; the second checks the tracked, uncommitted changes.

Sources for platform API semantics: [Apple URL volume resource values](https://developer.apple.com/documentation/foundation/urlresourcevalues), [IOKit power-source change notifications](https://developer.apple.com/documentation/iokit/1523868-iopsnotificationcreaterunloopsou), [Apple required-reason API privacy manifest](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest).
