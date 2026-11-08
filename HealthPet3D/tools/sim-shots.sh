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

# A simulator that has just booted keeps the Mac busy for minutes (load average above 100 on a
# MacBook Air), and launches then take far longer than the sleeps below. Wait it out, 4 minutes at most.
settle() {
  local tries
  for tries in {1..24}; do
    (( $(sysctl -n vm.loadavg | awk '{print int($2)}') < 12 )) && return
    sleep 10
  done
  echo "still busy after 4 minutes, going on"
}

# A Debug launch spends 2-3 seconds loading frameworks before its first frame. The launch screen is
# one flat colour, so its PNG stays far under any real page's size. The launch transition can look
# like a page for its first second, so only look after that.
first_frame() {
  local tries
  sleep 1.5
  for tries in {1..60}; do
    xcrun simctl io "$UDID" screenshot --type=png "$OUT/.probe.png" >/dev/null 2>&1
    (( $(stat -f%z "$OUT/.probe.png" 2>/dev/null || echo 0) > 100000 )) && break
    sleep 0.5
  done
  rm -f "$OUT/.probe.png"
}

# pet_ready <log name>: wait for the living pet, up to a minute (the first WebKit start is the slowest)
pet_ready() {
  local tries
  for tries in {1..120}; do
    grep -q "\[pet\] ready" "$OUT/console-$1.log" 2>/dev/null && return
    sleep 0.5
  done
  echo "pet not ready after a minute: $1"
}

# launch <log name> [app arguments...]   (the first open is skipped unless -3d.onboarded NO is passed)
# Returns once the first frame is on screen, so the sleeps below count from there.
launch() {
  local name="$1"; shift
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1
  : > "$OUT/console-$name.log"   # simctl appends, and pet_ready must not read an earlier run's lines
  xcrun simctl launch --terminate-running-process --stdout="$OUT/console-$name.log" --stderr="$OUT/console-$name.log" \
    "$UDID" "$BUNDLE" -3d.onboarded YES "$@" >/dev/null
  first_frame
}

xcrun simctl boot "$UDID" 2>/dev/null
xcrun simctl bootstatus "$UDID" -b >/dev/null
settle
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl uninstall "$UDID" "$BUNDLE" >/dev/null 2>&1   # fresh install: the pet wakes up, today is celebrated
xcrun simctl install "$UDID" "$APP_PATH"

# 0. The first open (fresh install): hello → the last 30 days (tapped through by hand only)
xcrun simctl ui "$UDID" appearance light
launch first-open -3d.onboarded NO
sleep 1;   shot 00-first-open

# 1. Home, light: wake-up, the morning reveal (proud), today's moments, then every food bubble eaten
# (-hp3dFeed starts eating 9 seconds after the pet is ready)
launch home -hp3dFeed all
shot 01-home-start
pet_ready home
sleep 2;   shot 02-home-waking
sleep 3;   shot 03-home-cheer
sleep 4.5; shot 04-home-feeding
sleep 1.6; shot 05-home-feeding-2
sleep 2.4; shot 06-home-all-eaten   # before the 自律周 card slides up (about 15 seconds after ready)

# 2. Home, dark, food grown back: right away (the still stands in) and once the pet is live
xcrun simctl ui "$UDID" appearance dark
launch home-dark -hp3dRegrow YES -3d.appearance dark
shot 07-home-dark-early
pet_ready home-dark
sleep 2;   shot 08-home-dark

# 2b. Home with a low week (没电: paler floor, sleepy idle) and the 自律周 share card sliding up,
# in light, where the floor's tint shows best
xcrun simctl ui "$UDID" appearance light
launch home-low -3d.energyOverride low -3d.appearance light
pet_ready home-low
sleep 5;   shot 09-home-low
launch home-weekcard -hp3dWeekCard YES -3d.appearance light
sleep 3;   shot 10-home-week-card

# 3. Every page, light and dark (pet pages twice: early and settled)
for mode in light dark; do
  xcrun simctl ui "$UDID" appearance "$mode"
  for route in today pets locked pet:toast pet:chili share memories settings; do
    name="page-$mode-${route/:/-}"
    launch "$name" -hp3dRoute "$route" -3d.appearance "$mode"
    if [[ "$route" == pet:* ]]; then
      shot "$name-early"
      sleep 4
    else
      sleep 1.5
    fi
    shot "$name"
  done
done

xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1
xcrun simctl status_bar "$UDID" clear
xcrun simctl shutdown "$UDID"
for f in "$OUT"/console-*.log; do echo "== $(basename "$f")"; grep "\[pet\]" "$f"; done
echo "done; simulator shut down"
