#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/arm64-apple-macosx/release"
app_dir="$project_dir/dist/日进-0.1.15.app"

cd "$project_dir"
env CLANG_MODULE_CACHE_PATH=/private/tmp/daily-better-clang-cache \
    SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/daily-better-swift-cache \
    swift build -c release

mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$build_dir/DailyBetter" "$app_dir/Contents/MacOS/日进"
cp "$project_dir/Sources/DailyBetterApp/Resources/action-cards-600.json" "$app_dir/Contents/Resources/action-cards-600.json"
iconset_dir="$project_dir/.build/AppIcon-0.1.15.iconset"
mkdir -p "$iconset_dir"
# macOS 26 wraps transparent legacy icons in a light plate. Use the full-bleed
# opaque source so the system's rounded mask reaches the green background.
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$project_dir/assets/app-icon-planet-opaque.png" --out "$iconset_dir/icon_${size}x${size}.png" >/dev/null
    retina_size=$((size * 2))
    sips -z "$retina_size" "$retina_size" "$project_dir/assets/app-icon-planet-opaque.png" --out "$iconset_dir/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset_dir" -o "$app_dir/Contents/Resources/AppIcon.icns"

cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
    <key>CFBundleDisplayName</key><string>日进</string>
    <key>CFBundleExecutable</key><string>日进</string>
    <key>CFBundleIdentifier</key><string>com.wushan.dailybetter</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>日进</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.15</string>
    <key>CFBundleVersion</key><string>16</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$app_dir"
echo "$app_dir"
