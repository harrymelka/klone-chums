#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"
python3 "$ROOT/klone/prepare.py"
export CHUMS_TEAM=ZH253G7YME CHUMS_BUNDLE=com.harry.klonechums
cd "$ROOT/app"
mkdir -p build
chmod 700 build
xcodegen generate --spec klone.generated.yml --quiet
xcodebuild -project Chums.xcodeproj -target Chums -configuration Release \
 DEVELOPMENT_TEAM="$CHUMS_TEAM" -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
 SYMROOT="$PWD/build/sym" build > "$ROOT/.local/build-iphone.log" 2>&1
printf 'Built: %s\n' "$ROOT/app/build/sym/Release-iphoneos/Chums.app"
