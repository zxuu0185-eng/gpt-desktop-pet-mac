#!/bin/zsh
set -eu
cd "${0:A:h:h}"
mkdir -p work/module-cache work/cache
export CLANG_MODULE_CACHE_PATH="$PWD/work/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/work/module-cache"
swift build -c release --product BailongMac --disable-sandbox --cache-path work/cache --scratch-path work/build --manifest-cache local
mkdir -p outputs
stage="$(mktemp -d /private/tmp/bailong-build.XXXXXX)"
app="$stage/白龙.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp work/build/release/BailongMac "$app/Contents/MacOS/BailongMac"
# Public assets are versioned; optional character artwork stays local.
for resource in Resources/Public/*; do
  [[ -f "$resource" && "${resource:t}" != "README.md" ]] || continue
  cp "$resource" "$app/Contents/Resources/"
done
if [[ "${BAILONG_INCLUDE_LOCAL_ASSETS:-0}" == "1" && -d Resources/Local ]]; then
  for resource in Resources/Local/*; do
    [[ -f "$resource" ]] || continue
    cp "$resource" "$app/Contents/Resources/"
  done
fi
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>BailongMac</string>
<key>CFBundleIdentifier</key><string>local.bailong.mac</string>
<key>CFBundleName</key><string>白龙</string>
<key>CFBundleDisplayName</key><string>白龙</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.10.4</string>
<key>CFBundleVersion</key><string>15</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# Finder adds display metadata after the first launch; it is not part of the bundle.
xattr -d com.apple.FinderInfo "$app" 2>/dev/null || true
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
ditto --norsrc --noextattr "$app" "$PWD/outputs/白龙.app"
ditto -c -k --keepParent --norsrc --noextattr "$app" "$PWD/outputs/白龙-Mac.zip"
print "Built and signature verified: $app"
print "Delivered: $PWD/outputs/白龙.app and 白龙-Mac.zip"
