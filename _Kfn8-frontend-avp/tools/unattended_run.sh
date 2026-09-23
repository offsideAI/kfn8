#!/bin/zsh
# Unattended lighting + occlusion capture run. Founder keeps the headset on, mirrored to this Mac, head still.
# Each step drives the probe remotely, waits for the render to settle, and captures the mirrored Mac screen.
set -u
OUT="${1:?output dir}"; mkdir -p "$OUT"
R="python3 $(dirname $0)/probe_remote.py"
step() { # name json settle
  echo "$(date +%T) $1" >> "$OUT/log.txt"
  timeout 60 $=R run "$2" --wait "${3:-3}" > "$OUT/$1.status.json" 2>&1
  screencapture -x "$OUT/$1.png"
}
echo "$(date +%T) polling up to 5 min for the app to answer in the foreground" > "$OUT/log.txt"
ready=0
for n in {1..30}; do
  if timeout 60 $=R run '[{"op":"openSpace"}]' --wait 4 > "$OUT/ready.status.json" 2>&1 \
     && grep -q '"immersiveOpen": true' "$OUT/ready.status.json"; then ready=1; break; fi
  sleep 5
done
if (( ! ready )); then echo "$(date +%T) GAVE UP: app never acknowledged with the space open" >> "$OUT/log.txt"; exit 3; fi
echo "$(date +%T) app ready, space open; starting in 5s" >> "$OUT/log.txt"
sleep 5
step 00-baseline         '[{"op":"openSpace"},{"op":"lamp","on":false},{"op":"move","fixture":"floor","to":[0.0,0.0,-1.6]},{"op":"resetFrames"}]' 5
step 01-lamp-on-point    '[{"op":"lamp","on":true,"type":"point","intensity":60000,"radius":8,"surroundings":true}]' 4
step 02-lamp-off         '[{"op":"lamp","on":false}]' 4
step 03-lamp-on-again    '[{"op":"lamp","on":true}]' 4
step 04-lamp-no-surround '[{"op":"lamp","surroundings":false}]' 4
step 05-lamp-spot-surr   '[{"op":"lamp","type":"spot","surroundings":true,"intensity":80000}]' 4
step 06-lamp-off-final   '[{"op":"lamp","on":false,"type":"point"}]' 3
i=0
for pos in "-0.8,0.25,-2.4" "0.0,0.25,-2.8" "0.8,0.25,-2.4" "0.0,0.25,-3.5"; do
  i=$((i+1))
  step 1${i}a-cube-occluded "[{\"op\":\"occlusion\",\"mode\":\"occluded\"},{\"op\":\"move\",\"fixture\":\"cube\",\"to\":[$pos]}]" 4
  step 1${i}b-cube-default  '[{"op":"occlusion","mode":"default"}]' 3
done
step 20-restore '[{"op":"occlusion","mode":"occluded"},{"op":"note","text":"unattended lighting+occlusion capture run finished"}]' 2
timeout 60 $=R evidence "$OUT/M0-EVIDENCE.json" >> "$OUT/log.txt" 2>&1
echo "$(date +%T) DONE" >> "$OUT/log.txt"
