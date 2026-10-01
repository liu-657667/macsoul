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


## Network read-only observation (explicit external-request opt-in)

After the Network implementation is built, the following compiles the actual provider/monitor sources into an ignored observation runner. It never modifies proxy, VPN, Wi-Fi, DNS or routing. It performs an initial Live batch and a manual refresh, then cancels/stops. Output omits public IP values, proxy URLs/credentials and HTTP bodies. This is separate from deterministic unit tests and is not UI or performance acceptance.

```bash
swiftc MacSoul/Models/MacSoulModels.swift MacSoul/Models/SystemSensors.swift MacSoul/Models/SystemDetails.swift MacSoul/Models/ShellRunner.swift MacSoul/Models/DevEnvironment.swift MacSoul/Models/ListeningPorts.swift MacSoul/Models/NetworkSnapshot.swift MacSoul/Models/NetworkProviders.swift MacSoul/Models/NetworkMonitor.swift scripts/observe-network.swift -o .artifacts/observe-network
.artifacts/observe-network --allow-external-requests > .artifacts/network-observation.json
```
