#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

if pgrep -x MacSoul >/dev/null; then
    print -u2 'MacSoul is already running. Quit it before launching a new Mock preview.'
    exit 2
fi

./scripts/build.sh
mkdir -p build-preview
preview_dir=$(mktemp -d "$PWD/build-preview/MacSoul.XXXXXX")
preview_app="$preview_dir/MacSoul.app"
ditto .artifacts/DerivedData/Build/Products/Debug/MacSoul.app "$preview_app"
open -a "$preview_app"
print "Mock App: $preview_app"
