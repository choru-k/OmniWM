#!/bin/zsh
# ponytail: poll-compare WM focus vs macOS key app; log only on divergence.
# Catches "screen shows X but keys go to Y". Read ~/omniwm-focus-debug.log after repro.
LOG=~/omniwm-focus-debug.log
CTL=/opt/homebrew/bin/omniwmctl
prev=""
while true; do
  wm=$("$CTL" query focused-window 2>/dev/null | grep -m1 '"bundleId"' | sed -E 's/.*: "([^"]*)".*/\1/')
  front=$(lsappinfo info -only bundleid "$(lsappinfo front 2>/dev/null)" 2>/dev/null | sed -E 's/.*=("?)([^"]*)\1$/\2/')
  if [ -n "$wm" ] && [ -n "$front" ] && [ "$wm" != "$front" ]; then
    line="$(date '+%H:%M:%S')  DESYNC  wm-focus=$wm  macos-key=$front"
    if [ "$line ${line#*DESYNC}" != "$prev" ]; then
      echo "$line" >> "$LOG"
      prev="$line ${line#*DESYNC}"
    fi
  fi
  sleep 0.4
done
