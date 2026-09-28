#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
mkdir -p .artifacts
rm -rf .artifacts/MacSoulTests.xcresult
xcodebuild -project MacSoul.xcodeproj -scheme MacSoul -configuration Debug -destination 'platform=macOS' -derivedDataPath .artifacts/DerivedData -resultBundlePath .artifacts/MacSoulTests.xcresult CODE_SIGNING_ALLOWED=NO test > .artifacts/test.log 2>&1
print 'Test log: .artifacts/test.log'
