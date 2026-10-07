# Contributing to MacSoul

MacSoul is a native macOS developer companion. Keep changes scoped to the current task and preserve the shared Snapshot architecture.

## Development

Use macOS, full Xcode and Python 3. Deployment target: macOS 13. Local Day 7 uses Xcode 27; compatibility is established per CI run, not by the deployment target alone.

```bash
git clone https://github.com/liu-657667/macsoul.git
cd macsoul
./scripts/doctor.sh
./scripts/verify.sh
open MacSoul.xcodeproj
```

Read [development guide](docs/DEVELOPMENT.md), [AGENTS.md](AGENTS.md) and [current status](docs/STATUS.md). Do not reinitialize the project or task baseline.

## Changes and tests

- Use a feature branch and PR against main. Main requires the `macos` check, resolved review conversations and the latest main; use Merge commit, without bypass or force push.
- Run build, tests, verify and diff checks. Add meaningful tests for changed behavior and preserve unknown/error/Mock states. Use injected clocks for duration rules.
- Keep manual UI, live provider and performance evidence separate from automated fixtures. Record NOT_RUN honestly.
- Product UI must consume shared snapshots, not launch shell/network providers.
- v0.1 Cleaner is read-only. Do not add destructive operations to a refinement PR.

## Reports and privacy

Include OS/Xcode, branch or SHA, reproduction steps and expected/actual behavior in an Issue. Sanitize screenshots and logs. Prefer Developer Preview for screenshots.

Do not submit credentials, tokens, account payloads, quota/reset values, public IPs, private paths, raw environment/argv, browser data, build artifacts or personal configuration. Review content as well as `.gitignore`.

Contributions to the project's own code should be compatible with [MIT](LICENSE). Preserve third-party copyrights and licenses; see [resource sources](docs/ASSET-SOURCES.md) and [third-party notices](MacSoul/Resources/ThirdPartyNotices.txt).

Publishing/signing/account actions require separate Owner authorization; see [release guide](docs/RELEASE.md).
