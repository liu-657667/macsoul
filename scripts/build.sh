#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
mkdir -p .artifacts
xcodebuild -project MacSoul.xcodeproj -scheme MacSoul -configuration Debug -destination 'platform=macOS' -derivedDataPath .artifacts/DerivedData CODE_SIGNING_ALLOWED=NO build > .artifacts/build.log 2>&1
print 'Build log: .artifacts/build.log'
