#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
python3 klone/start.py
APP="$PWD/app/build/mac/products/Release/Klone Chums Mac.app"
if [[ ! -d "$APP" ]]; then klone/build-mac.sh; fi
open "$APP"
