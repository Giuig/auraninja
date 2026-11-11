#!/usr/bin/env bash
# Runs the emulator tests. Called by android_e2e.yml while the emulator is up.
#
# Each file in E2E_FILES gets its own `flutter test` process: AudioService.init
# may run only once per process. Exit codes are captured without pipes, and the
# script finishes every file before it reports, so one failure does not hide
# the others. Output goes to e2e-out/ (uploaded by the workflow).
set -u

OUT=e2e-out
DEVICE=${E2E_DEVICE:-emulator-5554}
FILES=${E2E_FILES:-smoke_test.dart a1_assets_load_test.dart memory_frees_test.dart stress_test.dart radio_test.dart radio_mix_cold_start_test.dart}
# Run after FILES in their own calls; their result is reported, never gating.
THIRD_PARTY_FILES=${E2E_THIRD_PARTY_FILES:-radio_third_party_test.dart}
PKG=io.github.giuig.auraninja
APK=build/app/outputs/flutter-apk/app-debug.apk

mkdir -p "$OUT"
: > "$OUT/status.txt"
failed=0
stream_pid=""

adb -s "$DEVICE" wait-for-device
for _ in $(seq 1 90); do
  [ "$(adb -s "$DEVICE" shell getprop sys.boot_completed | tr -d '\r')" = "1" ] && break
  sleep 2
done

{
  echo "sdk=$(adb -s "$DEVICE" shell getprop ro.build.version.sdk | tr -d '\r')"
  echo "abi=$(adb -s "$DEVICE" shell getprop ro.product.cpu.abi | tr -d '\r')"
  echo "model=$(adb -s "$DEVICE" shell getprop ro.product.model | tr -d '\r')"
} > "$OUT/device.txt"
adb -s "$DEVICE" shell dumpsys media.audio_flinger > "$OUT/audio_flinger.txt" 2>&1 || true
adb -s "$DEVICE" shell dumpsys audio > "$OUT/dumpsys_audio.txt" 2>&1 || true

adb -s "$DEVICE" logcat -c
adb -s "$DEVICE" logcat -v threadtime > "$OUT/logcat.txt" 2>&1 &
logcat_pid=$!

# Install with every runtime permission granted (POST_NOTIFICATIONS on API 33+).
# The later `flutter test` installs replace the package and keep the grants.
s=0
adb -s "$DEVICE" install -g -r "$APK" > "$OUT/install.txt" 2>&1 || s=$?
echo "install -g exit=$s" >> "$OUT/status.txt"
adb -s "$DEVICE" shell dumpsys package "$PKG" > "$OUT/package_before.txt" 2>&1 || true

# `flutter test` reinstalls the app and removes it afterwards, so the grant is
# sampled while the tests run (a record, not a gate).
(
  while true; do
    echo "$(date +%T) $(adb -s "$DEVICE" shell dumpsys package "$PKG" | grep -m1 'POST_NOTIFICATIONS: granted' | tr -d '\r')"
    sleep 4
  done
) > "$OUT/post_notifications_samples.txt" 2>&1 &
sampler_pid=$!

# The radio files stream from a local stand-in station on the runner; the emulator
# reaches it as 10.0.2.2:8099. Its request log shows the emulator's `GET /stream`.
case " $FILES $THIRD_PARTY_FILES " in
  *radio*)
    python3 scripts/ci/loop_stream.py --log "$OUT/stream_server.log" > "$OUT/stream_server.out" 2>&1 &
    stream_pid=$!
    for _ in $(seq 1 20); do
      (exec 3<>/dev/tcp/127.0.0.1/8099) 2>/dev/null && break
      sleep 0.5
    done
    echo "stream server pid=$stream_pid" >> "$OUT/status.txt"
    ;;
esac

for f in $FILES; do
  s=0
  flutter test "integration_test/$f" -d "$DEVICE" --reporter expanded > "$OUT/$f.txt" 2>&1 || s=$?
  cat "$OUT/$f.txt"
  echo "$f exit=$s" >> "$OUT/status.txt"
  if [ "$s" -ne 0 ]; then
    failed=1
  elif ! grep -q 'All tests passed' "$OUT/$f.txt"; then
    # A file that ran no test must not count as green.
    echo "$f: exit 0 but no 'All tests passed' line" >> "$OUT/status.txt"
    failed=1
  fi
done

# Third-party files: the result goes to the summary and never fails the job.
: > "$OUT/third_party.txt"
for f in $THIRD_PARTY_FILES; do
  s=0
  flutter test "integration_test/$f" -d "$DEVICE" --reporter expanded > "$OUT/$f.txt" 2>&1 || s=$?
  cat "$OUT/$f.txt"
  if [ "$s" -eq 0 ] && grep -q 'All tests passed' "$OUT/$f.txt"; then
    echo "$f: passed (third party, not gating)" >> "$OUT/third_party.txt"
  else
    echo "$f: FAILED exit=$s (third party, not gating)" >> "$OUT/third_party.txt"
  fi
done

if [ -n "$stream_pid" ]; then
  kill "$stream_pid" 2>/dev/null || true
  wait "$stream_pid" 2>/dev/null || true
  echo '--- stream server log (requests from the emulator) ---'
  cat "$OUT/stream_server.log"
fi

kill "$sampler_pid" 2>/dev/null || true
sleep 3
kill "$logcat_pid" 2>/dev/null || true
wait "$logcat_pid" 2>/dev/null || true

adb -s "$DEVICE" shell dumpsys package "$PKG" > "$OUT/package_after.txt" 2>&1 || true
grep -h 'POST_NOTIFICATIONS' "$OUT/package_before.txt" "$OUT/package_after.txt" > "$OUT/post_notifications.txt" 2>&1 || true

# A crash or ANR of the app fails the run even when every test passed.
grep -E 'FATAL EXCEPTION|ANR in '"$PKG" "$OUT/logcat.txt" > "$OUT/crashes.txt" 2>&1
if [ -s "$OUT/crashes.txt" ]; then
  echo "logcat: crash or ANR found (e2e-out/crashes.txt)" >> "$OUT/status.txt"
  failed=1
fi

# Evidence for the emulator audio option: what the engine said about itself.
grep -iE 'soloud|miniaudio|aaudio|opensl|audiotrack' "$OUT/logcat.txt" | head -150 > "$OUT/audio_lines.txt" 2>&1 || true
grep -h 'E2E_METRIC' "$OUT"/*_test.dart.txt > "$OUT/metrics.txt" 2>&1 || true

{
  echo '```'
  cat "$OUT/device.txt"
  cat "$OUT/status.txt"
  cat "$OUT/third_party.txt"
  cat "$OUT/metrics.txt"
  echo '```'
  if [ -f "$OUT/stream_server.log" ]; then
    echo
    echo "stream server log: $(grep -c 'GET /stream' "$OUT/stream_server.log") GET /stream, $(grep -c 'GET /dead' "$OUT/stream_server.log") GET /dead"
  fi
  echo
  echo "audio_lines.txt: $(wc -l < "$OUT/audio_lines.txt") engine lines in logcat"
  head -20 "$OUT/audio_lines.txt"
} > "$OUT/summary.md"

exit "$failed"
