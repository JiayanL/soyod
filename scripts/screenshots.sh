#!/usr/bin/env bash
# Screenshot tour: boots each device, installs the built app once, then for
# every appearance (dark/light) × route relaunches with -AtlasScreen and
# captures docs/screenshots/<device-slug>/<dark|light>/<NN>-<route>.png.
#
# Usage: scripts/screenshots.sh
#   SHOT_DEVICES="udid-or-name,udid-or-name"  (default: Atlas Shots 17 Pro + iPhone SE)
#   SHOT_WAIT=4  per-route settle seconds (chatAction 8, snapReview 6)
set -euo pipefail
cd "$(dirname "$0")/.."

DERIVED="${SHOT_DERIVED:-$HOME/atlas-dd/shots}"
SCHEME=Atlas
APP="$DERIVED/Build/Products/Debug-iphonesimulator/Atlas.app"
NOW="2026-10-01T15:30:00"

ROUTES=(onbWelcome onbGoal onbBaseline onbAbout onbFuel onbConnect onbPlan
        coach chatAction memory fuel logMeal snapReview train logger
        workoutSummary cardioLog sleep manualSleep progress measurement
        settings integrations)

DEVICES_RAW="${SHOT_DEVICES:-Atlas Shots 17 Pro,205B5D26-5C58-4AA7-97AC-7B451ABE04A6}"
IFS=',' read -ra DEVICES <<< "$DEVICES_RAW"

wait_for() { # route → settle seconds
    case "$1" in
        chatAction) echo 8 ;;
        snapReview) echo 6 ;;
        *)          echo "${SHOT_WAIT:-4}" ;;
    esac
}

resolve_udid() {
    local token="$1"
    if xcrun simctl list devices -j | python3 -c "
import json,sys
for devs in json.load(sys.stdin)['devices'].values():
    for d in devs:
        if d['udid'] == '$token' or d['name'] == '$token':
            print(d['udid']); sys.exit(0)
sys.exit(1)" 2>/dev/null | grep -q .; then
        xcrun simctl list devices -j | python3 -c "
import json,sys
for devs in json.load(sys.stdin)['devices'].values():
    for d in devs:
        if d['udid'] == '$token' or d['name'] == '$token':
            print(d['udid']); sys.exit(0)"
    else
        echo "Unknown device: $token" >&2; return 1
    fi
}

device_slug() {
    local name
    name=$(xcrun simctl list devices -j | python3 -c "
import json,sys
for devs in json.load(sys.stdin)['devices'].values():
    for d in devs:
        if d['udid'] == '$1': print(d['name']); sys.exit(0)")
    echo "${name:-$1}" | tr 'A-Z ' 'a-z-' | tr -cd 'a-z0-9-'
}

if [ ! -d "$APP" ]; then
    echo "Building $SCHEME → $DERIVED …" >&2
    xcodebuild -project Atlas.xcodeproj -scheme "$SCHEME" \
        -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation),OS=26.5' \
        -derivedDataPath "$DERIVED" build | grep -E "error|BUILD" | tail -3
fi

for dev in "${DEVICES[@]}"; do
    dev=$(echo "$dev" | xargs)
    UDID=$(resolve_udid "$dev") || continue
    SLUG=$(device_slug "$UDID")
    echo "== $dev ($UDID) → docs/screenshots/$SLUG"
    xcrun simctl boot "$UDID" 2>/dev/null || true
    xcrun simctl bootstatus "$UDID" -b >/dev/null
    xcrun simctl install "$UDID" "$APP"
    xcrun simctl status_bar "$UDID" override \
        --time 9:41 --batteryState charged --batteryLevel 100 \
        --cellularBars 4 --wifiBars 3 --dataNetwork wifi 2>/dev/null || true
    scripts/add-sample-photos.sh "$UDID" >/dev/null 2>&1 || \
        xcrun simctl addmedia "$UDID" Atlas/Resources/SampleMeals/*.jpg >/dev/null 2>&1 || true

    for appearance in dark light; do
        xcrun simctl ui "$UDID" appearance "$appearance"
        n=0
        for route in "${ROUTES[@]}"; do
            n=$((n + 1))
            out="docs/screenshots/$SLUG/$appearance/$(printf '%02d' $n)-$route.png"
            mkdir -p "$(dirname "$out")"
            args=(-AtlasSampleData YES -AtlasUITest YES -AtlasNow "$NOW" -AtlasScreen "$route")
            case "$route" in
                onb*) args+=(-AtlasResetOnboarding YES) ;;
            esac
            xcrun simctl terminate "$UDID" com.jiayanl.atlas 2>/dev/null || true
            xcrun simctl launch "$UDID" com.jiayanl.atlas "${args[@]}" >/dev/null
            sleep "$(wait_for "$route")"
            xcrun simctl io "$UDID" screenshot "$out" >/dev/null
            sips -Z 1320 "$out" >/dev/null 2>&1 || true
        done
    done
    xcrun simctl status_bar "$UDID" clear 2>/dev/null || true
done
echo "Done. $(find docs/screenshots -name '*.png' | wc -l | tr -d ' ') screenshots."
