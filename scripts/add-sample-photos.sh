#!/usr/bin/env bash
# Copies the bundled sample meal photos into the booted simulator's Photos
# library so the Snap flow can pick real images during demos/tests.
set -euo pipefail
cd "$(dirname "$0")/.."
xcrun simctl addmedia booted Atlas/Resources/SampleMeals/*.jpg
echo "Added $(ls Atlas/Resources/SampleMeals/*.jpg | wc -l | tr -d ' ') photos to booted simulator."
