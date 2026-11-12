#!/usr/bin/env bash
# Takes the store screenshots. Called by store_screenshots.yml while the emulator is up.
#
# 1. SystemUI demo mode: fixed clock (the platform default, 14:00 on Android 14), full battery, full signal, no
#    notification icons. The state it replaces is recorded first and put back at
#    the end.
# 2. `flutter drive` runs integration_test/store_screenshots_test.dart in the
#    profile APK built by the workflow. At each screen the test prints
#    `E2E_METRIC store_shot=<name>` and holds still; the capture loop below sees
#    the line in logcat and runs `adb exec-out screencap -p`, which includes the
#    system bars (a Flutter-side screenshot would not).
# 3. Fail closed: fewer than 6 PNGs, or one that is not 1080x2340, fails the job.
#
# Exit codes are captured without pipes. Output goes to $OUT (uploaded by the
# workflow): PNGs, manifest.json, logs/.
set -u

OUT=${SHOTS_OUT:-store-screenshots}
LOGS="$OUT/logs"
DEVICE=${E2E_DEVICE:-emulator-5554}
PKG=io.github.giuig.auraninja
APK=${SHOTS_APK:-build/app/outputs/flutter-apk/app-profile.apk}
TARGET=integration_test/store_screenshots_test.dart
DRIVER=test_driver/integration_test.dart
EXPECTED_SHOTS=6
WIDTH=1080
HEIGHT=2340

mkdir -p "$OUT" "$LOGS"
failed=0
stream_pid=""
capture_pid=""
logcat_pid=""

adb_() { adb -s "$DEVICE" "$@"; }
demo() { adb_ shell am broadcast -a com.android.systemui.demo -e command "$@" >> "$LOGS/demo.txt" 2>&1; }

adb_ wait-for-device
for _ in $(seq 1 90); do
  [ "$(adb_ shell getprop sys.boot_completed | tr -d '\r')" = "1" ] && break
  sleep 2
done

{
  echo "sdk=$(adb_ shell getprop ro.build.version.sdk | tr -d '\r')"
  echo "abi=$(adb_ shell getprop ro.product.cpu.abi | tr -d '\r')"
  echo "model=$(adb_ shell getprop ro.product.model | tr -d '\r')"
  echo "device=$(adb_ shell getprop ro.product.device | tr -d '\r')"
  adb_ shell wm size | tr -d '\r'
  adb_ shell wm density | tr -d '\r'
  echo "locale=$(adb_ shell getprop persist.sys.locale | tr -d '\r') $(adb_ shell getprop ro.product.locale | tr -d '\r')"
  echo "navigation_mode=$(adb_ shell settings get secure navigation_mode | tr -d '\r') (0 buttons, 2 gestures)"
} > "$LOGS/device.txt"
cat "$LOGS/device.txt"

# Wake and unlock; a dark system theme so the system UI matches the app's.
adb_ shell input keyevent KEYCODE_WAKEUP
adb_ shell wm dismiss-keyguard
adb_ shell cmd uimode night yes

# Record what demo mode and the install touch, to restore it at the end.
prev_demo=$(adb_ shell settings get global sysui_demo_allowed | tr -d '\r')
echo "sysui_demo_allowed before: $prev_demo" >> "$LOGS/demo.txt"

# The commands are re-sent until the status bar's own clock shows the demo time: right
# after boot SystemUI may not be ready for them, and a first attempt that came
# too early left the real clock frozen on screen (run 43189625331: the real "9:20").
# The clock is Android's own System UI demo-mode default: AOSP's DemoModeFragment
# uses the platform major version as the hour ("%02d00"), "1010" when it cannot
# tell, so Android 14 shows 14:00. It is derived from the device, not hard-coded.
release=$(adb_ shell getprop ro.build.version.release | tr -d '[:space:]')
major=${release%%.*}
case "$major" in
  ''|*[!0-9]*) DEMO_HHMM=1010 ;;
  *) DEMO_HHMM=$(printf '%02d00' $((major % 24))) ;;
esac
DEMO_TEXT="${DEMO_HHMM:0:2}:${DEMO_HHMM:2:2}"
echo "demo clock: release=$release hhmm=$DEMO_HHMM (expects '$DEMO_TEXT')" >> "$LOGS/status.txt"
prev_24h=$(adb_ shell settings get system time_12_24 | tr -d '[:space:]')
# 24-hour display, so the status bar says 14:00 and not 2:00.
adb_ shell settings put system time_12_24 24

demo_on() {
  adb_ shell settings put global sysui_demo_allowed 1
  demo enter
  demo clock -e hhmm "$DEMO_HHMM"
  demo battery -e level 100 -e plugged false
  demo network -e wifi show -e level 4 -e fully true
  demo network -e mobile show -e datatype none -e level 4 -e fully true
  demo notifications -e visible false
}
status_bar_clock() {
  adb_ shell uiautomator dump /sdcard/ui_status.xml > /dev/null 2>&1
  adb_ shell cat /sdcard/ui_status.xml 2> /dev/null | grep -o 'resource-id="com.android.systemui:id/clock"[^>]*' | head -1
}
demo_ok=0
for attempt in $(seq 1 10); do
  demo_on
  sleep 2
  clock_node=$(status_bar_clock)
  echo "demo attempt $attempt: ${clock_node:-no clock node found}" >> "$LOGS/demo_check.txt"
  case "$clock_node" in
    *"text=\"$DEMO_TEXT\""*) demo_ok=1; break ;;
  esac
done
echo "demo_clock_verified=$demo_ok" >> "$LOGS/status.txt"

# Install with every runtime permission granted (POST_NOTIFICATIONS on API 33+);
# `flutter drive` reinstalls over it and keeps the grants.
s=0
adb_ install -g -r "$APK" > "$LOGS/install.txt" 2>&1 || s=$?
echo "install -g exit=$s" >> "$LOGS/status.txt"
[ "$s" -ne 0 ] && failed=1

# The stand-in station for the radio screen (also the fallback when the
# third-party station is unreachable).
python3 scripts/ci/loop_stream.py --log "$LOGS/stream_server.log" > "$LOGS/stream_server.out" 2>&1 &
stream_pid=$!
for _ in $(seq 1 20); do
  (exec 3<>/dev/tcp/127.0.0.1/8099) 2>/dev/null && break
  sleep 0.5
done

adb_ logcat -c
adb_ logcat -v threadtime > "$LOGS/logcat.txt" 2>&1 &
logcat_pid=$!
# The test's markers, from the app's own output (print() reaches logcat as `flutter`).
adb_ logcat -v brief flutter:I '*:S' > "$LOGS/flutter_log.txt" 2>&1 &
flutter_log_pid=$!

# Capture loop: one picture per new marker, named after the marker.
capture_loop() {
  local done_count=0 total name tick=0
  while [ ! -f "$OUT/.stop" ]; do
    # Re-send the clock every few seconds: cheap, and it puts it back if SystemUI
    # ever dropped it.
    tick=$((tick + 1))
    if [ $((tick % 25)) -eq 0 ]; then demo clock -e hhmm "$DEMO_HHMM"; fi
    total=$(grep -c 'E2E_METRIC store_shot=' "$LOGS/flutter_log.txt" 2>/dev/null)
    while [ "${total:-0}" -gt "$done_count" ]; do
      done_count=$((done_count + 1))
      name=$(grep 'E2E_METRIC store_shot=' "$LOGS/flutter_log.txt" | sed -n "${done_count}p" | sed 's/.*store_shot=//' | tr -d '\r ')
      adb_ exec-out screencap -p > "$OUT/$name.png" 2> "$LOGS/screencap_$name.err"
      echo "$(date +%T) captured $name ($(wc -c < "$OUT/$name.png") bytes)" >> "$LOGS/capture.txt"
    done
    sleep 0.2
  done
}
rm -f "$OUT/.stop"
capture_loop &
capture_pid=$!

s=0
flutter drive --profile -d "$DEVICE" \
  --use-application-binary="$APK" \
  --target="$TARGET" --driver="$DRIVER" > "$LOGS/drive.txt" 2>&1 || s=$?
cat "$LOGS/drive.txt"
echo "flutter drive exit=$s" >> "$LOGS/status.txt"
if [ "$s" -ne 0 ]; then
  failed=1
elif ! grep -q 'All tests passed' "$LOGS/drive.txt"; then
  echo "flutter drive: exit 0 but no 'All tests passed' line" >> "$LOGS/status.txt"
  failed=1
fi
# The driver prints "All tests passed." and exits 0 even when the on-device test
# timed out (run 43187239628: "Some tests failed." just above it), so the
# on-device result is read from the device's own output as well.
if grep -qE 'Some tests failed|\[E\]' "$LOGS/drive.txt"; then
  echo "flutter drive: the on-device test reported a failure" >> "$LOGS/status.txt"
  failed=1
fi

# Let the loop take any marker printed at the very end, then stop it.
sleep 3
touch "$OUT/.stop"
wait "$capture_pid" 2>/dev/null || true
rm -f "$OUT/.stop"

# Put the system back.
demo exit
if [ "$prev_24h" = "null" ] || [ -z "$prev_24h" ]; then
  adb_ shell settings delete system time_12_24 >> "$LOGS/demo.txt" 2>&1
else
  adb_ shell settings put system time_12_24 "$prev_24h" >> "$LOGS/demo.txt" 2>&1
fi
if [ "$prev_demo" = "null" ] || [ -z "$prev_demo" ]; then
  adb_ shell settings delete global sysui_demo_allowed >> "$LOGS/demo.txt" 2>&1
else
  adb_ shell settings put global sysui_demo_allowed "$prev_demo" >> "$LOGS/demo.txt" 2>&1
fi

kill "$stream_pid" 2>/dev/null || true
wait "$stream_pid" 2>/dev/null || true
sleep 2
kill "$flutter_log_pid" "$logcat_pid" 2>/dev/null || true
wait "$flutter_log_pid" "$logcat_pid" 2>/dev/null || true

# A crash or ANR of the app fails the run even when every picture was taken.
grep -E 'FATAL EXCEPTION|ANR in '"$PKG" "$LOGS/logcat.txt" > "$LOGS/crashes.txt" 2>&1
if [ -s "$LOGS/crashes.txt" ]; then
  echo "logcat: crash or ANR found (logs/crashes.txt)" >> "$LOGS/status.txt"
  failed=1
fi

# Fail closed on the pictures, and write the manifest (name, size, sha256).
python3 - "$OUT" "$EXPECTED_SHOTS" "$WIDTH" "$HEIGHT" <<'PY' || failed=1
import hashlib, json, os, struct, sys

out, expected, width, height = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
shots, problems = [], []
for name in sorted(os.listdir(out)):
    if not name.endswith(".png"):
        continue
    data = open(os.path.join(out, name), "rb").read()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or len(data) < 33:
        problems.append(f"{name}: not a PNG ({len(data)} bytes)")
        continue
    w, h = struct.unpack(">II", data[16:24])
    shots.append({"screen": name[:-4], "file": name, "width": w, "height": h,
                  "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()})
    if (w, h) != (width, height):
        problems.append(f"{name}: {w}x{h}, expected {width}x{height}")
if len(shots) < expected:
    problems.append(f"{len(shots)} valid PNGs, expected {expected}")
with open(os.path.join(out, "manifest.json"), "w") as f:
    json.dump({"expected": expected, "size": f"{width}x{height}", "shots": shots,
               "problems": problems}, f, indent=2)
for p in problems:
    print("STORE_SHOTS_PROBLEM", p)
print(f"store shots: {len(shots)} PNG(s), {len(problems)} problem(s)")
sys.exit(1 if problems else 0)
PY

grep -h 'E2E_METRIC' "$LOGS/flutter_log.txt" > "$LOGS/metrics.txt" 2>&1 || true

{
  echo '```'
  cat "$LOGS/device.txt"
  cat "$LOGS/status.txt"
  cat "$LOGS/capture.txt" 2>/dev/null
  cat "$LOGS/metrics.txt"
  echo '```'
} > "$OUT/summary.md"
cat "$OUT/summary.md"

exit "$failed"
