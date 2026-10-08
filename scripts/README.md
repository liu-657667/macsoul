# Verification commands

- `./scripts/doctor.sh`: local toolchain and project inventory.
- `./scripts/build.sh`: Debug macOS app build.
- `./scripts/run-mock.sh`: build and launch one Mock App from ignored `build-preview/`; quit any running MacSoul first. The visible preview path lets macOS show the bundled Dock icon.
- `./scripts/test.sh`: XCTest suite and local xcresult.
- `python3 scripts/verify-visual-assets.py`: bundled asset hashes, sizes and catalog references.
- `./scripts/verify.sh`: all fixed checks plus `.artifacts/verification.json`; regenerates local command evidence before checking the ledger, including on a fresh clone.
- `python3 scripts/verify_progress.py`: ledger invariants/current evidence.
- `python3 scripts/generate_status.py`: regenerate STATUS from `tasks.json`.
- `python3 scripts/check_bundle.py`: historical starter-package check. It resolves moved files under `docs/archive/bootstrap/` but intentionally keeps the original manifest and reports changed source bytes or the missing original `.codex/config.toml`; it is not a current build gate.

Build/test/verification scripts do not install tools or change global configuration; unit tests use injected Network providers. The optional Network observer below contacts external providers only with explicit opt-in. Logs and DerivedData stay in ignored `.artifacts/`.


## Historical Network read-only observation — initial standalone source list

The following command is retained as a historical initial-Network example, **not a current runnable compile recipe**. Current `MacSoulModels.swift` now references `CleanerSnapshot` (and later App model dependencies), absent from this old source list. Do not run this example against the current sources or execute the observer for document maintenance. Any new executable recipe needs a separately checked dependency list and offline compilation; external observation additionally needs Owner opt-in. At the historical checkpoint this compiled provider/monitor sources into an ignored observation runner. It never modifies proxy, VPN, Wi-Fi, DNS or routing. It performs an initial Live batch and a manual refresh, then cancels/stops. Output omits public IP values, proxy URLs/credentials and HTTP bodies. This is separate from deterministic unit tests and is not UI or performance acceptance.

```bash
swiftc MacSoul/Models/MacSoulModels.swift MacSoul/Models/SystemSensors.swift MacSoul/Models/SystemDetails.swift MacSoul/Models/ShellRunner.swift MacSoul/Models/DevEnvironment.swift MacSoul/Models/ListeningPorts.swift MacSoul/Models/NetworkSnapshot.swift MacSoul/Models/NetworkProviders.swift MacSoul/Models/NetworkMonitor.swift scripts/observe-network.swift -o .artifacts/observe-network
.artifacts/observe-network --allow-external-requests > .artifacts/network-observation.json
```

## Fixed documentation-maintenance candidate

`python3 scripts/verify_doc_maintenance.py prepare` explicitly prepares the two
fixed public Git objects (historical baseline and PR #13 merge base). `check`
performs offline full-input, payload, immutable-ledger, historical-section,
link and generator/STATUS checks against the external declaration. See
[progress protocol](../docs/PROGRESS-PROTOCOL.md#fixed-v010-maintenance-contract).

`verify.sh` executes fresh automatic checks and creates a new local manifest,
then runs ledger and appends its actual result. Integrity/docs PASS does not
grant authorization; ledger refuses coverage when the separate exact Owner
decision is absent, PENDING or invalid. Fixtures in `test_progress.py` are
simulations, never new Owner decisions or actual build/Live/performance evidence.
The runner does not read an approval from the environment or create one.

The normal runner reads only `docs/evidence/v0.1.0-owner-decision.json` when
present, forwarding it to ledger automatically (including existing CI). Explicit
usage: `./scripts/verify.sh --owner-decision docs/evidence/v0.1.0-owner-decision.json`.
This candidate ships no decision record. The old PENDING template is historical.
Only later explicit Owner acceptance and recording authorization may create
an ACCEPTED record with a real review reference and the unchanged exact tuple. Manifest/log record the actual
argv, record digest/state and result. Arbitrary paths/fixture approvals are refused.
Full fixed Git objects, HEAD/index/worktree scope and ordinary file types are
checked without export filters; shallow tests do not require a local main branch.
