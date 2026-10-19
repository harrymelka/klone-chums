#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"
python3 "$ROOT/klone/prepare.py"
mkdir -p "$ROOT/app/build/mac"
xcodegen generate --spec "$ROOT/klone/mac.yml" --project "$ROOT/app/build/mac" --quiet
xcodebuild -project "$ROOT/app/build/mac/KloneMac.xcodeproj" -scheme KloneMac \
 -configuration Release -destination 'platform=macOS' \
 SYMROOT="$ROOT/app/build/mac/products" build > "$ROOT/.local/build-mac.log" 2>&1
printf 'Built: %s\n' "$ROOT/app/build/mac/products/Release/Klone Chums Mac.app"
