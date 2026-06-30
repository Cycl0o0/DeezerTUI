#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

# Step 1 (optional): rebind Go engine
# Uncomment to rebuild Odmobile.xcframework from source.
# Prereqs: go, gomobile installed; run once: gomobile init
#
# GOPATH="$(go env GOPATH)"
# export PATH="$GOPATH/bin:$PATH"
# gomobile bind -target=ios -o Odmobile.xcframework ../../mobile

# Step 2: generate Xcode project
/opt/homebrew/bin/xcodegen generate

echo ""
echo "Project generated: OpenDeezer.xcodeproj"
echo ""
echo "Build for simulator:"
echo "  cd gui/ios && xcodebuild -project OpenDeezer.xcodeproj -scheme OpenDeezer \\"
echo "    -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \\"
echo "    -derivedDataPath build CODE_SIGNING_ALLOWED=NO build"
echo ""
echo "Open in Xcode (requires signing for real device):"
echo "  open OpenDeezer.xcodeproj"
