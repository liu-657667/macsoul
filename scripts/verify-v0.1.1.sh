#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
exec python3 scripts/verify_v011.py run
