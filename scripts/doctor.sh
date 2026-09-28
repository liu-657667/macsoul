#!/bin/zsh
set -uo pipefail
cd "${0:A:h}/.."
print "project=$PWD"
sw_vers
uname -m
xcodebuild -version || exit $?
swift --version || exit $?
print "codex=$(command -v codex || print UNKNOWN)"
if command -v codex >/dev/null; then codex --version; fi
print "claude=$(command -v claude || print UNKNOWN)"
if command -v claude >/dev/null; then claude --version; fi
if [[ -d .git ]]; then git status --short --branch; else print 'git=ABSENT'; fi
if [[ -f .codex/config.toml ]]; then print 'project_codex_config=PRESENT_LOAD_UNVERIFIED'; else print 'project_codex_config=ABSENT'; fi
xcodebuild -list -project MacSoul.xcodeproj
