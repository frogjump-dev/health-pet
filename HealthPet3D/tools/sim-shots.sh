#!/bin/bash
# Screenshots of Ovenpals (the HealthPet3D target) on the iPhone 18 Pro simulator, without opening Simulator.app.
# Usage: HealthPet3D/tools/sim-shots.sh <simulator udid> <output folder> [all|extra]
#   extra = only parts 4 to 7 (first-open steps, share cards, page ends, Toast's page, the tour,
#           the tap-to-explain notes, PRD v0.3, Dress up)
# Needs a Debug build in build/dd (see HealthPet3D/README.md). Shuts the simulator down at the end.
# Each launch writes its own console-<name>.log; lines starting with [pet] say how long the
# living pet took to load (ready / drawn) and show any page error.
set -u
UDID="$1"
OUT="$2"
ONLY="${3:-all}"
APP_PATH="build/dd/Build/Products/Debug-iphonesimulator/HealthPet3D.app"
BUNDLE="com.ovenpals.app"
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
# like a page for its first second, so only look after that. Fails when no page came at all.
first_frame() {
  local tries drawn=1
  sleep 1.5
  for tries in {1..60}; do
    xcrun simctl io "$UDID" screenshot --type=png "$OUT/.probe.png" >/dev/null 2>&1
    (( $(stat -f%z "$OUT/.probe.png" 2>/dev/null || echo 0) > 100000 )) && { drawn=0; break; }
    sleep 0.5
  done
  rm -f "$OUT/.probe.png"
  return $drawn
}

# pet_ready <log name>: wait for the living pet, up to 2 minutes (the first WebKit start after an
# install is the slowest: 76 s on a MacBook Air)
pet_ready() {
  local tries
  for tries in {1..240}; do
    grep -q "\[pet\] ready" "$OUT/console-$1.log" 2>/dev/null && return
    sleep 0.5
  done
  echo "pet not ready after 2 minutes: $1"
}

# The clock, to the hundredth of a second (bash 3 has no EPOCHREALTIME).
now() { perl -MTime::HiRes=time -e 'printf "%.2f", time'; }

# launch <log name> [app arguments...]   (the first open and the home tour are skipped unless
# -3d.onboarded NO / -3d.tourDone NO is passed: a later argument wins over an earlier one)
# Every launch starts from the same wardrobe (-hp3dDressUp ready: 7 points, 23 items, the Dress up
# design's outfits), written to iCloud too: the simulator keeps its iCloud values across installs,
# and a fresh wardrobe would put the welcome gift on every home shot. Part 7 passes others.
# Returns once the first frame is on screen, so the sleeps below count from there.
launch() {
  local name="$1"; shift
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1
  # --console-pty in the background, not --stdout/--stderr: those leave the log empty (pet_ready then
  # waits out its minute on every launch and the timed shots miss) and fail outright under ~/Desktop.
  # It ends by itself when the app does.
  xcrun simctl launch --console-pty --terminate-running-process "$UDID" "$BUNDLE" \
    -3d.onboarded YES -3d.tourDone YES -hp3dDressUp ready "$@" </dev/null >"$OUT/console-$name.log" 2>&1 &
  first_frame
}

xcrun simctl boot "$UDID" 2>/dev/null
xcrun simctl bootstatus "$UDID" -b >/dev/null
settle
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl uninstall "$UDID" "$BUNDLE" >/dev/null 2>&1   # fresh install: the pet wakes up, today is celebrated
xcrun simctl install "$UDID" "$APP_PATH"

if [[ "$ONLY" == all ]]; then
# 0. The first open (fresh install): hello (its other steps are in part 4)
xcrun simctl ui "$UDID" appearance light
# the first launch after an install sometimes never starts (11-12: blank after 30 s, the next one
# drew in 4 s): launch it again then
launch first-open -3d.onboarded NO || { echo "first launch stuck, launching again"; launch first-open -3d.onboarded NO; }
sleep 1;   shot 00-first-open

# 1. Home, light: wake-up, the morning reveal, then every food bubble eaten (-hp3dFeed starts
# 9 seconds after the pet is ready, one bubble every 2.2 s). A screenshot takes 2-3 s with the living
# pet on screen and the harvest is over in 2.7 s, so home is recorded (harvest.mp4) and the food just
# before the first bite and that harvest come from the video (crumbs bursting, crumbs on their way to
# the mouth, the tag + the dot, the cell filled). The video runs about 0.4 s behind the clock.
launch home -hp3dFeed all
shot 01-home-start
pet_ready home
xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$OUT/harvest.mp4" >"$OUT/.recording.log" 2>&1 &
recording=$!
for tries in {1..50}; do
  grep -q "Recording started" "$OUT/.recording.log" && break
  sleep 0.1
done
recording_at=$(now)
sleep 1;   shot 02-home-waking
sleep 17   # past the last bubble's harvest
kill -INT "$recording"
wait "$recording"
rm -f "$OUT/.recording.log"
feed_at=$(awk -v after="$recording_at" '/\[feed\]/ { sub(/\r$/, ""); if ($NF + 0 > after + 0) { print $NF; exit } }' "$OUT/console-home.log")
if [[ -n "$feed_at" ]]; then
  frame() { perl -e "printf '%s=%.2f', '$1', $feed_at - $recording_at + 0.4 + $2"; }
  xcrun swift "$(dirname "$0")/video-frames.swift" "$OUT/harvest.mp4" "$OUT" 2>/dev/null \
    "$(frame 03-home-food -0.6)" "$(frame 04a-feed-burst 0.3)" "$(frame 04b-feed-crumbs 0.55)" \
    "$(frame 04c-feed-tag 1.45)" "$(frame 04d-feed-landed 1.9)"
else
  echo "no harvest in the recording"
fi
shot 05-home-all-eaten
sleep 4;   shot 06-home-week-card   # the eaten food finished the week: cheer, then its card

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
fi

# 4. Screens the parts above don't reach: the first open's other steps, the today and pets
# share cards, the ends of the long pages (Settings, Memories), and Toast's page again
xcrun simctl ui "$UDID" appearance light
for step in health reading pets bedtime; do
  launch "first-open-$step" -3d.onboarded NO -hp3dFirstOpenStep "$step"
  sleep 2; shot "11-first-open-$step"
done
for mode in light dark; do
  xcrun simctl ui "$UDID" appearance "$mode"
  for card in today pets; do
    launch "share-$card-$mode" -hp3dRoute share -hp3dShareCard "$card" -3d.appearance "$mode"
    sleep 2; shot "page-$mode-share-$card"
  done
  for route in settings memories; do
    launch "$route-end-$mode" -hp3dRoute "$route" -hp3dScrollEnd YES -3d.appearance "$mode"
    sleep 1.5; shot "page-$mode-$route-end"
  done
  launch "toast-$mode" -hp3dRoute pet:toast -3d.appearance "$mode"
  sleep 4; shot "page-$mode-pet-toast"
  launch "today-booked-$mode" -hp3dRoute today -hp3dBookAll YES -3d.appearance "$mode"
  sleep 4; shot "page-$mode-today-booked"
done

# 5. Home v3.4 guidance, light: the tour as it starts by itself after the first open, each of its
# steps, and the notes a tap opens (Asleep, Rest, This week, one day of the calendar row)
xcrun simctl ui "$UDID" appearance light
launch tour-auto -3d.tourDone NO -3d.appearance light
pet_ready tour-auto
sleep 8;   shot 12-tour-auto
for step in 1 2 3 tryit; do
  launch "tour-$step" -hp3dTour "$step" -3d.appearance light
  pet_ready "tour-$step"
  sleep 7; shot "13-tour-$step"
done
for which in asleep rest week day; do
  launch "note-$which" -hp3dNote "$which" -3d.appearance light
  pet_ready "note-$which"
  sleep 7; shot "14-note-$which"
done
xcrun simctl ui "$UDID" appearance dark
launch tour-dark -hp3dTour 1 -3d.appearance dark
pet_ready tour-dark
sleep 7;   shot 15-tour-1-dark

# 6. PRD v0.3, light: the 12-hour clock (home and Today), the pet's bedtime question, 「Watch got it
# wrong?」, the 9:16 story on the Share page, and Settings → Look with the time format
xcrun simctl ui "$UDID" appearance light
launch clock12-home -3d.timeFormat 12 -3d.appearance light
pet_ready clock12-home
sleep 4;   shot 16-home-12h
launch clock12-today -hp3dRoute today -3d.timeFormat 12 -3d.appearance light
sleep 1.5; shot 17-today-12h
launch ask-bedtime -hp3dAskBedtime YES -3d.appearance light
pet_ready ask-bedtime
sleep 6;   shot 18-home-bedtime-question
launch fix-sheet -hp3dRoute today -hp3dFixSheet YES -3d.appearance light
sleep 3;   shot 19-today-fix-sheet
launch story -hp3dRoute share -3d.share.story YES -3d.appearance light
sleep 2;   shot 20-share-story

# 7. Dress up (PRD v0.3 §5.4, design v1 D03–D13): the page, a locked item's note, how points work,
# short of points, the gift card (box, open, the last item), all collected, then the dressed pets on
# Pets (with the Draw row), Toast's page and the share cards, and the welcome gift on home after the
# tour. Pets tiles and share cards take their dressed pictures from a hidden second web view the
# first time: the sleeps there are longer.
xcrun simctl ui "$UDID" appearance light
launch dress -hp3dRoute dress:toast -3d.appearance light
pet_ready dress
sleep 4;   shot 21-dressup
launch dress-locked -hp3dRoute dress:toast -hp3dDressSlot eyes -hp3dDressNote locked -3d.appearance light
pet_ready dress-locked
sleep 3;   shot 22-dressup-eyes-locked
launch dress-points -hp3dRoute dress:toast -hp3dDressNote points -3d.appearance light
pet_ready dress-points
sleep 3;   shot 23-dressup-points-note
launch dress-short -hp3dRoute dress:toast -hp3dDressUp short -3d.appearance light
pet_ready dress-short
sleep 3;   shot 24-dressup-short
launch gift-box -hp3dRoute dress:toast -hp3dDressGift YES -3d.appearance light
pet_ready gift-box
sleep 3;   shot 25-gift-box
launch gift-open -hp3dRoute dress:toast -hp3dDressGift YES -hp3dGiftOpen YES -3d.appearance light
pet_ready gift-open
sleep 5;   shot 26-gift-open
launch gift-last -hp3dRoute dress:toast -hp3dDressUp last -hp3dDressGift YES -hp3dGiftOpen YES -3d.appearance light
pet_ready gift-last
sleep 5;   shot 27-gift-last
launch dress-all -hp3dRoute dress:toast -hp3dDressUp all -hp3dDressSlot back -3d.appearance light
pet_ready dress-all
sleep 3;   shot 28-dressup-all
launch dressed-pets -hp3dRoute pets -3d.appearance light
sleep 12;  shot 29-pets-dressed
launch dressed-toast -hp3dRoute pet:toast -3d.appearance light
pet_ready dressed-toast
sleep 4;   shot 30-pet-toast-dressed
for card in week pets; do
  launch "dressed-share-$card" -hp3dRoute share -hp3dShareCard "$card" -3d.appearance light
  sleep 12; shot "31-share-$card-dressed"
done
launch home-gift -hp3dDressUp gift -3d.appearance light
pet_ready home-gift
sleep 8;   shot 32-home-welcome-gift
xcrun simctl ui "$UDID" appearance dark
launch dress-dark -hp3dRoute dress:toast -3d.appearance dark
pet_ready dress-dark
sleep 4;   shot 33-dressup-dark
launch gift-open-dark -hp3dRoute dress:toast -hp3dDressGift YES -hp3dGiftOpen YES -3d.appearance dark
pet_ready gift-open-dark
sleep 5;   shot 34-gift-open-dark

xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1
wait   # the last launch's console
xcrun simctl status_bar "$UDID" clear
xcrun simctl shutdown "$UDID"
for f in "$OUT"/console-*.log; do echo "== $(basename "$f")"; grep "\[pet\]" "$f"; done
echo "done; simulator shut down"
