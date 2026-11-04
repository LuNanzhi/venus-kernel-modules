#!/system/bin/sh
# schedutil_balance v1.3: WebUI two-mode switch + guard loop (no game detection)
LOG=/data/local/tmp/schedutil_balance.log
MODE_FILE=/data/local/tmp/schedutil_mode
MODDIR=${0%/*}

log() { echo "[$(date +%H:%M:%S)] $*" >> "$LOG"; }
: > "$LOG"
log "=== v1.3 start ==="

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

last_eff=""
while true; do
  mode=$(cat "$MODE_FILE" 2>/dev/null)
  case "$mode" in balance|normal) ;; *) mode=balance ;; esac

  if [ "$mode" != "$last_eff" ]; then
    log "apply: $mode"
    sh "$MODDIR/apply.sh" "$mode"
    last_eff="$mode"
  fi

  # guard: restore caps if the vendor perf stack resets max_freq
  if [ "$mode" = "balance" ]; then
    _c0=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null)
    _c4=$(cat /sys/devices/system/cpu/cpu4/cpufreq/scaling_max_freq 2>/dev/null)
    _c7=$(cat /sys/devices/system/cpu/cpu7/cpufreq/scaling_max_freq 2>/dev/null)
    if [ "$_c0" -gt "$CAP_LITTLE" ] 2>/dev/null || [ "$_c4" -gt "$CAP_BIG" ] 2>/dev/null || [ "$_c7" -gt "$CAP_PRIME" ] 2>/dev/null; then
      log "guard: restored (cpu0=$_c0 cpu4=$_c4 cpu7=$_c7)"
      sh "$MODDIR/apply.sh" balance
    fi
  fi
  sleep 10
done
