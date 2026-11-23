#!/bin/sh
# Builds the web app, stamps it with the build time, and makes the browser
# fetch the new app code instead of a cached copy.
#
# Usage: sh tool/build_web.sh
set -e
cd "$(dirname "$0")/.."

stamp="$(date '+%b %d %H:%M')"
flutter build web --dart-define=BUILD="$stamp"

# The loader names the app code by a fixed path, so browsers may keep an old
# copy. Append the build time so each build is a new URL.
v="$(date +%s)"
sed -i '' "s#main\.dart\.js#main.dart.js?v=$v#g" build/web/flutter_bootstrap.js
grep -q "main.dart.js?v=$v" build/web/flutter_bootstrap.js

echo "Built: $stamp (code url main.dart.js?v=$v)"
