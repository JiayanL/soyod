#!/usr/bin/env bash
# Downloads public App Store screenshots of best-in-class fitness apps into design-references/ (gitignored)
# for side-by-side taste reviews. Not shipped, not committed.
set -euo pipefail
OUT="$(cd "$(dirname "$0")/.." && pwd)/design-references"
mkdir -p "$OUT"
APPS="whoop:933944389 oura:1043837948 bevel:6456176249 calai:6480417616 macrofactor:1553503471 hevy:1458862350 strava:426826309 runna:1594204443 ladder:1502936453 athlytic:1543571755 gentler:1576857102"
for pair in $APPS; do
  name=${pair%%:*}; id=${pair##*:}
  curl -s "https://itunes.apple.com/lookup?id=$id&country=us" \
    | python3 -c 'import json,sys; [print(u) for u in json.load(sys.stdin)["results"][0]["screenshotUrls"][:8]]' \
    | nl -v0 | while read -r i url; do
        curl -s -o "$OUT/${name}_${i}.jpg" "$(echo "$url" | sed -E 's#/[0-9]+x[0-9]+bb\.(jpg|png)#/600x1300bb.jpg#')"
      done
done
echo "Saved $(ls "$OUT" | wc -l) reference screenshots to $OUT"
