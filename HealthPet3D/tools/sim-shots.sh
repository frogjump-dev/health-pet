#!/bin/bash
# Screenshots of HealthPet 3D on the iPhone 18 Pro simulator, without opening Simulator.app.
# Usage: HealthPet3D/tools/sim-shots.sh <simulator udid> <output folder>
# Needs a Debug build in build/dd (see HealthPet3D/README.md). Shuts the simulator down at the end.
# Each launch writes its own console-<name>.log; lines starting with [pet] say how long the
# living pet took to load (ready / drawn) and show any page error.
set -u
UDID="$1"
OUT="$2"
APP_PATH="build/dd/Build/Products/Debug-iphonesimulator/HealthPet3D.app"
BUNDLE="com.healthpet.app3d"
mkdir -p "$OUT"

shot() { xcrun simctl io "$UDID" screenshot --type=png "$OUT/$1.png" >/dev/null 2>&1 && echo "shot $1"; }
# launch <log name> [app arguments...]   (the first open is skipped unless -3d.onboarded NO is passed)
launch() {
  local name="$1"; shift
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1
  xcrun simctl launch --terminate-running-process --stdout="$OUT/console-$name.log" --stderr="$OUT/console-$name.log" \
    "$UDID" "$BUNDLE" -3d.onboarded YES "$@" >/dev/null
}

xcrun simctl boot "$UDID" 2>/dev/null
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl uninstall "$UDID" "$BUNDLE" >/dev/null 2>&1   # fresh install: the pet wakes up, today is celebrated
xcrun simctl install "$UDID" "$APP_PATH"

# 0. The first open (fresh install): hello → the last 30 days (tapped through by hand only)
xcrun simctl ui "$UDID" appearance light
launch first-open -3d.onboarded NO
sleep 3;   shot 00-first-open

# 1. Home, light: wake-up, the morning reveal (proud), today's moments, then every food bubble eaten
launch home -hp3dFeed all
sleep 3;   shot 01-home-start
sleep 2;   shot 02-home-waking
sleep 3;   shot 03-home-cheer
sleep 3;   shot 04-home-feeding
sleep 1.6; shot 05-home-feeding-2
sleep 4;   shot 06-home-all-eaten

# 2. Home, dark, food grown back: right away (the still stands in) and once the pet is live
xcrun simctl ui "$UDID" appearance dark
launch home-dark -hp3dRegrow YES -3d.appearance dark
sleep 2;   shot 07-home-dark-early
sleep 4;   shot 08-home-dark

# 2b. Home with a low week (没电: paler floor, sleepy idle) and the 自律周 share card sliding up
launch home-low -3d.energyOverride low
sleep 8;   shot 09-home-low
launch home-weekcard -hp3dWeekCard YES
sleep 4;   shot 10-home-week-card

# 3. Every page, light and dark (pet pages twice: early and settled)
for mode in light dark; do
  xcrun simctl ui "$UDID" appearance "$mode"
  for route in today pets locked pet:toast pet:chili share memories settings; do
    name="page-$mode-${route/:/-}"
    launch "$name" -hp3dRoute "$route" -3d.appearance "$mode"
    if [[ "$route" == pet:* ]]; then
      sleep 1.5; shot "$name-early"
      sleep 4
    else
      sleep 3
    fi
    shot "$name"
  done
done

xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1
xcrun simctl status_bar "$UDID" clear
xcrun simctl shutdown "$UDID"
for f in "$OUT"/console-*.log; do echo "== $(basename "$f")"; grep "\[pet\]" "$f"; done
echo "done; simulator shut down"
