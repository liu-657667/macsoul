# Verification commands

- `./scripts/doctor.sh`: local toolchain and project inventory.
- `./scripts/build.sh`: Debug macOS app build.
- `./scripts/run-mock.sh`: build and launch one Mock App from ignored `build-preview/`; quit any running MacSoul first. The visible preview path lets macOS show the bundled Dock icon.
- `./scripts/test.sh`: XCTest suite and local xcresult.
- `python3 scripts/verify-visual-assets.py`: bundled asset hashes, sizes and catalog references.
- `./scripts/verify.sh`: all fixed checks plus `.artifacts/verification.json`; regenerates local command evidence before checking the ledger, including on a fresh clone.
- `python3 scripts/verify_progress.py`: ledger invariants/current evidence.
- `python3 scripts/generate_status.py`: regenerate STATUS from `tasks.json`.

No script installs tools, contacts providers, or changes global configuration. Logs and DerivedData stay in ignored `.artifacts/`.
