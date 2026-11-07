#!/bin/bash
# Screenshots of HealthPet 3D on the iPhone 18 Pro simulator, without opening Simulator.app.
# Usage: HealthPet3D/tools/sim-shots.sh <simulator udid> <output folder>
# Needs a Debug build in build/dd (see HealthPet3D/README.md). Shuts the simulator down at the end.
set -u
UDID="$1"
OUT="$2"
APP_PATH="build/dd/Build/Products/Debug-iphonesimulator/HealthPet3D.app"
BUNDLE="com.healthpet.app3d"
mkdir -p "$OUT"

shot() { xcrun simctl io "$UDID" screenshot --type=png "$OUT/$1.png" >/dev/null 2>&1 && echo "shot $1"; }
launch() { xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1; xcrun simctl launch --stdout="$OUT/console.log" --stderr="$OUT/console.log" "$UDID" "$BUNDLE" "$@" >/dev/null; }

xcrun simctl boot "$UDID" 2>/dev/null
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl uninstall "$UDID" "$BUNDLE" >/dev/null 2>&1   # fresh install: the pet wakes up, today is celebrated
xcrun simctl install "$UDID" "$APP_PATH"

# 1. Home, light: wake-up, the cheer for today's check-ins, then every food bubble eaten
xcrun simctl ui "$UDID" appearance light
launch -hp3dFeed all
sleep 2;   shot 01-home-asleep
sleep 2.5; shot 02-home-waking
sleep 3;   shot 03-home-cheer
sleep 3;   shot 04-home-feeding
sleep 1.6; shot 05-home-feeding-2
sleep 4;   shot 06-home-all-eaten

# 2. Home, dark, food grown back
xcrun simctl ui "$UDID" appearance dark
launch -hp3dRegrow YES -3d.appearance dark
sleep 4;   shot 07-home-dark

# 3. Every page, light and dark
for mode in light dark; do
  xcrun simctl ui "$UDID" appearance "$mode"
  for route in today pets pet:chili pet:marshmallow share memories settings; do
    launch -hp3dRoute "$route" -3d.appearance "$mode"
    sleep 3
    shot "page-$mode-${route/:/-}"
  done
done

xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1
xcrun simctl status_bar "$UDID" clear
xcrun simctl shutdown "$UDID"
echo "done; simulator shut down"
