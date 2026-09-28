# Phase A commands

- `./scripts/doctor.sh`: local toolchain and project inventory.
- `./scripts/build.sh`: Debug macOS app build.
- `./scripts/test.sh`: XCTest suite and local xcresult.
- `./scripts/verify.sh`: all fixed checks plus `.artifacts/verification.json`.
- `python3 scripts/verify_progress.py`: ledger invariants/current evidence.
- `python3 scripts/generate_status.py`: regenerate STATUS from `tasks.json`.

No script installs tools, contacts providers, or changes global configuration. Logs and DerivedData stay in ignored `.artifacts/`.
