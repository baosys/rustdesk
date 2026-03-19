#!/bin/bash
set -euo pipefail

# Usage: ./res/generate_icons.sh <source_image.png>
# Generates all platform icons from a single source image.
# Requires: imagemagick, icoutils

if [ $# -lt 1 ]; then
    echo "Usage: $0 <source_image.png>"
    exit 1
fi

SOURCE="$1"
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo "==> Source: $SOURCE"
echo "==> Temp dir: $TMPDIR"

# Step 1: Remove background and prepare clean square icon
echo "[1/7] Cleaning background..."
convert "$SOURCE" -fuzz 15% -fill none -draw "color 0,0 floodfill" -trim +repage "$TMPDIR/clean.png"
CLEAN_SIZE=$(identify -format "%[fx:max(w,h)]" "$TMPDIR/clean.png")
convert "$TMPDIR/clean.png" -gravity center -background none -extent "${CLEAN_SIZE}x${CLEAN_SIZE}" "$TMPDIR/square.png"
# Add ~12% padding
PADDED_SIZE=$(( CLEAN_SIZE * 112 / 100 ))
convert "$TMPDIR/square.png" -gravity center -background none -extent "${PADDED_SIZE}x${PADDED_SIZE}" "$TMPDIR/padded.png"
# Final 1024x1024
convert "$TMPDIR/padded.png" -resize 1024x1024 "$TMPDIR/final.png"
SRC="$TMPDIR/final.png"
echo "    Clean icon: 1024x1024"

# Step 2: res/ directory
echo "[2/7] Generating res/ icons..."
convert "$SRC" -resize 32x32   res/32x32.png
convert "$SRC" -resize 64x64   res/64x64.png
convert "$SRC" -resize 128x128 res/128x128.png
convert "$SRC" -resize 256x256 res/128x128@2x.png
convert "$SRC" -resize 512x512 res/icon.png
convert "$SRC" -resize 512x512 res/mac-icon.png
# portable label
convert "$SRC" -resize 128x128 libs/portable/src/res/label.png

# Step 3: Windows .ico files
echo "[3/7] Generating Windows .ico files..."
for size in 16 32 48 64 128 256; do
    convert "$SRC" -resize ${size}x${size} "$TMPDIR/ico_${size}.png"
done
icotool -c -o res/icon.ico \
    "$TMPDIR/ico_16.png" "$TMPDIR/ico_32.png" "$TMPDIR/ico_48.png" \
    "$TMPDIR/ico_64.png" "$TMPDIR/ico_128.png" "$TMPDIR/ico_256.png"
icotool -c -o res/tray-icon.ico \
    "$TMPDIR/ico_16.png" "$TMPDIR/ico_32.png" "$TMPDIR/ico_48.png"
cp res/icon.ico flutter/windows/runner/resources/app_icon.ico
cp res/icon.ico xinghedesk.ico

# Step 4: Android mipmap icons
echo "[4/7] Generating Android icons..."
ANDROID_RES="flutter/android/app/src/main/res"
# launcher: mdpi=48 hdpi=72 xhdpi=96 xxhdpi=144 xxxhdpi=192
declare -A MIPMAP_SIZES=([mdpi]=48 [hdpi]=72 [xhdpi]=96 [xxhdpi]=144 [xxxhdpi]=192)
for dpi in "${!MIPMAP_SIZES[@]}"; do
    s=${MIPMAP_SIZES[$dpi]}
    convert "$SRC" -resize ${s}x${s} "$ANDROID_RES/mipmap-${dpi}/ic_launcher.png"
    convert "$SRC" -resize ${s}x${s} "$ANDROID_RES/mipmap-${dpi}/ic_launcher_round.png"
done
# foreground (adaptive icon): mdpi=108 hdpi=162 xhdpi=216 xxhdpi=324 xxxhdpi=432
declare -A FG_SIZES=([mdpi]=108 [hdpi]=162 [xhdpi]=216 [xxhdpi]=324 [xxxhdpi]=432)
for dpi in "${!FG_SIZES[@]}"; do
    s=${FG_SIZES[$dpi]}
    convert "$SRC" -resize ${s}x${s} "$ANDROID_RES/mipmap-${dpi}/ic_launcher_foreground.png"
done
# notification: mdpi=24 hdpi=36 xhdpi=48 xxhdpi=72 xxxhdpi=96
declare -A STAT_SIZES=([mdpi]=24 [hdpi]=36 [xhdpi]=48 [xxhdpi]=72 [xxxhdpi]=96)
for dpi in "${!STAT_SIZES[@]}"; do
    s=${STAT_SIZES[$dpi]}
    convert "$SRC" -resize ${s}x${s} "$ANDROID_RES/mipmap-${dpi}/ic_stat_logo.png"
done

# Step 5: iOS icons
echo "[5/7] Generating iOS icons..."
IOS_ICONS="flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset"
declare -A IOS_SIZES=(
    ["Icon-App-1024x1024@1x"]=1024
    ["Icon-App-20x20@1x"]=20   ["Icon-App-20x20@2x"]=40   ["Icon-App-20x20@3x"]=60
    ["Icon-App-29x29@1x"]=29   ["Icon-App-29x29@2x"]=58   ["Icon-App-29x29@3x"]=87
    ["Icon-App-40x40@1x"]=40   ["Icon-App-40x40@2x"]=80   ["Icon-App-40x40@3x"]=120
    ["Icon-App-60x60@2x"]=120  ["Icon-App-60x60@3x"]=180
    ["Icon-App-76x76@1x"]=76   ["Icon-App-76x76@2x"]=152
    ["Icon-App-83.5x83.5@2x"]=167
)
for name in "${!IOS_SIZES[@]}"; do
    s=${IOS_SIZES[$name]}
    convert "$SRC" -resize ${s}x${s} "$IOS_ICONS/${name}.png"
done

# Step 6: macOS .icns
echo "[6/7] Generating macOS .icns..."
for size in 16 32 64 128 256 512 1024; do
    convert "$SRC" -resize ${size}x${size} "$TMPDIR/mac_${size}.png"
done
convert "$TMPDIR/mac_16.png" "$TMPDIR/mac_32.png" "$TMPDIR/mac_64.png" \
    "$TMPDIR/mac_128.png" "$TMPDIR/mac_256.png" "$TMPDIR/mac_512.png" \
    "$TMPDIR/mac_1024.png" flutter/macos/Runner/AppIcon.icns

# Step 7: Scalable SVG placeholder (skip if no svg source)
echo "[7/7] Done!"
echo ""
echo "All icons generated from: $SOURCE"
echo "Remember to commit the changes."
