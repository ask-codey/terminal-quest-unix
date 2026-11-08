# Mission Control's walkthrough: every treasure, the coin and the finish. The tests play it. Generated: don't edit.
QS_WALKTHROUGH=(
'cat briefing.txt'
'ps'
'kill "$(q_pid alarm)"'
'ls -a telemetry | head -3'
'for f in telemetry/*.tmp; do mv "$f" "${f%.tmp}.log"; done'
'mv telemetry/.secret.tmp telemetry/.secret.log'
'cat > check.sh << '\''EOF'\''
#!/usr/bin/env bash
for f in sensors/*.txt; do
  temp=$(cut -d= -f2 "$f")
  if [ "$temp" -gt 90 ]; then
    basename "$f" .txt
  fi
done
EOF'
'chmod +x check.sh'
'./check.sh'
'./check.sh | ./uplink'
'echo '\''echo "BEACON $1"'\'' > beacon.sh'
'chmod +x beacon.sh'
'./beacon.sh KESTREL | ./transmitter'
'find crates -name "patch-*"'
'find crates -name "patch-*" | xargs cat'
'grep CODE message.txt | sort'
'./safe 4417'
'ln -s photos/1968/december/earthrise.txt wallpaper'
'./viewer'
'./launch'
)
