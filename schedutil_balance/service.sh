#!/system/bin/sh
# schedutil_balance v1.4: WebUI two modes + msm_performance driver lock + guard
LOG=/data/local/tmp/schedutil_balance.log
MODE_FILE=/data/local/tmp/schedutil_mode
MODDIR=${0%/*}

log() { echo "[$(date +%H:%M:%S)] $*" >> "$LOG"; }
: > "$LOG"
log "=== v1.4 start ==="

i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $i -lt 150 ]; do
  sleep 2
  i=$((i+1))
done
log "boot completed (waited ${i}x2s)"

[ -f "$MODE_FILE" ] || echo balance > "$MODE_FILE"

CAP_LITTLE=1600000
CAP_BIG=1900000
CAP_PRIME=2000000
MP_BALANCE="0:$CAP_LITTLE 1:$CAP_LITTLE 2:$CAP_LITTLE 3:$CAP_LITTLE 4:$CAP_BIG 5:$CAP_BIG 6:$CAP_BIG 7:$CAP_PRIME"
MP_NORMAL="0:0 1:0 2:0 3:0 4:0 5:0 6:0 7:0"

last_eff=""
while true; do
  mode=$(cat "$MODE_FILE" 2>/dev/null)
  case "$mode" in balance|normal) ;; *) mode=balance ;; esac

  if [ "$mode" != "$last_eff" ]; then
    log "apply: $mode"
    sh "$MODDIR/apply.sh" "$mode"
    last_eff="$mode"
  fi

  # guard: verify driver param and cpufreq caps, restore if vendor reset them
  if [ "$mode" = "balance" ]; then
    mp=$(cat /sys/module/msm_performance/parameters/cpu_max_freq 2>/dev/null | tr -d ' \n')
    want=$(echo "$MP_BALANCE" | tr -d ' \n')
    c0=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null)
    c4=$(cat /sys/devices/system/cpu/cpu4/cpufreq/scaling_max_freq 2>/dev/null)
    c7=$(cat /sys/devices/system/cpu/cpu7/cpufreq/scaling_max_freq 2>/dev/null)
    if [ "$mp" != "$want" ] || [ "$c0" -gt "$CAP_LITTLE" ] 2>/dev/null || [ "$c4" -gt "$CAP_BIG" ] 2>/dev/null || [ "$c7" -gt "$CAP_PRIME" ] 2>/dev/null; then
      log "guard: restore (mp=${mp:0:24} cpu0=$c0 cpu4=$c4 cpu7=$c7)"
      sh "$MODDIR/apply.sh" balance
    fi
  fi
  sleep 10
done
